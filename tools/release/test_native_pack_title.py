# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Run the real reduced-pack constructors/master tick against tripwire UObjects.

No game process or installation is accessed. Python objects are Lua userdata;
unexpected native methods raise and are recorded even if Lua contains the error.
"""
import os
from pathlib import Path
import argparse
import sys
from common import *
from test_module_graph import SETUP
sys.path.insert(0, str(ROOT / 'tools'))
from lua54_compile import runtime

class Object:
    serial = 0

    def __init__(self, calls, name, live=True, **members):
        Object.serial += 1
        self.address = Object.serial
        self.calls, self.name, self.live, self.members = (calls, name, live, members)

    def IsValid(self):
        if self.live == 'throws':
            raise RuntimeError('invalid UObject wrapper')
        return self.live

    def GetAddress(self):
        return self.address

    def __getattr__(self, name):
        if name.startswith('__'):
            raise AttributeError(name)
        if name in self.members:
            member = self.members[name]
            if callable(member):
                return lambda *args: member(*(args[1:] if args and args[0] is self else args))
            return member
        self.calls.append(self.name + '.' + name)
        raise AssertionError('FORBIDDEN native access ' + self.name + '.' + name)
HARNESS = SETUP.split('local ok,result=xpcall', 1)[0].replace('print=function()end', 'local logs={};print=function(s)logs[#logs+1]=tostring(s)end;io.flush=function()end') + "\nos.clock=function()return NOW end\nreturn {boot=function()return dofile('/virtual/PalCraft/Scripts/main.lua')end,\n callbacks=callbacks,hooks=hooks,keys=keys,loaded=loaded,logs=logs}\n"

def run(payload=None, generated_data=None):
    manifest = read_json(ROOT / 'release/modules.json')
    tests = [r['module'] for r in manifest['lua'] if r['pack'] == 'test']
    names = {r['module'] for r in manifest['lua'] if r['pack'] in ('core', 'islands_animals', 'map_art')}
    if payload:
        texts = {p.stem: p.read_text(encoding='utf-8-sig') for pack in ('core', 'islands_animals', 'map_art') for p in (Path(payload) / pack / MOD).rglob('*.lua')}
    else:
        texts = {r['module']: release_lua(r['path'], (ROOT / r['path']).read_text(encoding='utf-8-sig'), tests) for r in manifest['lua'] if r['module'] in names}
    generated = {p.stem: p.read_text(encoding='utf-8') for p in Path(generated_data).glob('*.json') if p.name != 'fixture-receipt.json'} if generated_data else {}
    rows = []
    for map_art in (0, 1):
        for case in ('engine-title', 'pal-title-selected-save', 'nil-controller', 'invalid-controller', 'throwing-controller', 'nil-controller-class', 'invalid-controller-class', 'nil-world', 'invalid-world', 'nil-level', 'invalid-level', 'nil-instance', 'invalid-instance', 'nil-save', 'invalid-save', 'invalid-save-wrapper', 'nil-player-state', 'invalid-player-state', 'throwing-player-state', 'dead-player-state', 'nil-pawn', 'lifecycle', 'new-world-identity'):
            lua = runtime()
            harness = lua.execute(HARNESS, lua.table_from(texts), f'packs=islands_animals\nmap_art={map_art}\n', lua.table_from(generated))
            globals_ = lua.globals()
            calls, probes, starts, lookups = ([], [], [], [])
            make = lambda name, **kwargs: Object(calls, name, **kwargs)
            cls = make('PalPlayerControllerClass')
            if case == 'nil-controller-class':
                cls = None
            if case == 'invalid-controller-class':
                cls.live = False
            level = make('level')
            world = make('world', PersistentLevel=level, GetFullName=lambda: 'World /Game/Pal/Maps/MainWorld_5/MainWorld.MainWorld')
            state = make('state', IsPlayerDead=lambda: case == 'dead-player-state')
            parameter = make('parameter', IsDead=lambda: False)
            component = make('parameter-component', GetIndividualParameter=lambda: parameter)
            mesh = make('mesh', GetAnimInstance=lambda: make('animation'))
            player = make('player', CharacterParameterComponent=component, CapsuleComponent=make('capsule'), Mesh=mesh, ShooterComponent=make('shooter'), LoadoutSelectorComponent=make('loadout'), HasAuthority=lambda: True)
            controller = make('controller', IsA=lambda c: case != 'engine-title', IsLocalPlayerController=lambda: True, GetWorld=lambda: world)
            player.members['GetPalPlayerController'] = lambda: controller
            controller.members['GetDefaultPlayerCharacter'] = lambda: None if case == 'nil-pawn' else player

            def player_state():
                probes.append('GetPalPlayerState')
                if case in ('engine-title', 'pal-title-selected-save'):
                    raise RuntimeError('GetPalPlayerState on a TrivialObject at title')
                return state
            controller.members['GetPalPlayerState'] = player_state
            instance = make('instance', GetSelectedWorldSaveDirectoryName=lambda: 'A' * 32)
            if case in ('engine-title', 'pal-title-selected-save'):
                world.members['GetFullName'] = lambda: 'World /Game/Pal/Maps/Title/Title.Title'
            if case == 'nil-controller':
                controller = None
            if case in ('invalid-controller', 'throwing-controller'):
                controller.live = False if case == 'invalid-controller' else 'throws'
            if case == 'nil-world':
                world = None
            if case == 'invalid-world':
                world.live = False
            if case in ('nil-level', 'invalid-level'):
                world.members['PersistentLevel'] = None if case == 'nil-level' else make('invalid-level', live=False)
            if case == 'nil-instance':
                instance = None
            if case == 'invalid-instance':
                instance.live = False
            if case in ('nil-save', 'invalid-save', 'invalid-save-wrapper', 'new-world-identity'):
                instance.members['GetSelectedWorldSaveDirectoryName'] = lambda: None if case != 'invalid-save-wrapper' else make('save-wrapper', ToString=lambda: None)
                instance.members['GetSelectedWorldName'] = lambda: 'New World'
                world.members['GameState'] = None
            if case == 'invalid-save':
                instance.members['GetSelectedWorldSaveDirectoryName'] = lambda: 'invalid'
            if case == 'new-world-identity':
                world.members['GameState'] = make('game-state', GetWorldSaveDirectoryName=lambda: 'B' * 32, GetWorldName=lambda: 'New World', GetWorld=lambda: world)
            if case == 'nil-player-state':
                state = None
            if case in ('invalid-player-state', 'throwing-player-state'):
                state = make('TrivialObject-state', live=False if case == 'invalid-player-state' else 'throws')
            globals_.NOW = 0

            def find_object(path):
                lookups.append('object:' + path)
                assert path == '/Script/Pal.PalPlayerController', path
                return cls

            def find_first(name):
                lookups.append('first:' + name)
                assert name == 'GameInstance', name
                return instance

            def find_all(name):
                lookups.append('all:' + name)
                assert name == 'PlayerController', name
                return lua.table_from([controller] if controller is not None else [])
            globals_.StaticFindObject = find_object
            globals_.FindFirstOf = find_first
            globals_.FindAllOf = find_all
            ue = harness['boot']()
            timers = lua.eval("package.loaded['PalCraft.timers']")
            master = harness['callbacks'][1][2]
            if case in ('lifecycle', 'new-world-identity'):
                ue['island']['start'] = lambda *args: starts.append('island')
                ue['alex']['start'] = lambda *args: starts.append('alex')
                probe = timers['frames']['startup-probe']
                for now in (0, 0.25, 0.5, 0.75, 1):
                    globals_.NOW = now
                    probe()
                assert starts == ['island', 'alex'], (case, starts)
                assert timers['admission']('zombie77')
                if case == 'new-world-identity':
                    assert ue['worldScope65']['id'] == 'B' * 32
                else:
                    initial_epoch = timers['epoch']
                    restart = harness['hooks']['/Script/Engine.PlayerController:ClientRestart'][2]
                    restart()
                    assert not timers['admission']('zombie77')
                    globals_.NOW = 1.1
                    probe()
                    assert not timers['admission']('zombie77')
                    globals_.NOW = 2
                    probe()
                    assert timers['admission']('zombie77') and starts == ['island', 'alex']
                    state.members['IsPlayerDead'] = lambda: True
                    probe()
                    assert not timers['admission']('zombie77')
                    state.members['IsPlayerDead'] = lambda: False
                    globals_.NOW = 2.1
                    probe()
                    globals_.NOW = 3
                    probe()
                    assert timers['epoch'] > initial_epoch and starts == ['island', 'alex'] * 2
                    before = timers['epoch']
                    world.members['GetFullName'] = lambda: 'World /Game/Pal/Maps/Title/Title.Title'
                    probe_count = len(probes)
                    for now in (3.25, 3.5, 3.75, 4):
                        globals_.NOW = now
                        master()
                    assert len(probes) == probe_count
                    assert timers['epoch'] == before + 1
                    assert not timers['admission']('zombie77')
            else:
                for tick in range(40):
                    globals_.NOW = tick * 0.1
                    master()
                    if tick == 10:
                        for callback in harness['keys'].values():
                            callback()
                        for path, callbacks in harness['hooks'].items():
                            if path != '/Script/Engine.PlayerController:ClientRestart':
                                for callback in callbacks.values():
                                    callback(make('title-hook-object'))
                assert not timers['admission']('zombie77')
                if case not in ('nil-player-state', 'invalid-player-state', 'throwing-player-state', 'dead-player-state', 'nil-pawn'):
                    assert probes == [], (case, probes)
            logs = list(harness['logs'].values())
            assert not any(('ERROR' in line or 'FORBIDDEN' in line for line in logs)), (case, logs)
            assert calls == [], (case, calls)
            if case in ('engine-title', 'pal-title-selected-save'):
                assert not any((s.startswith('first:') for s in lookups)), lookups
            rows.append(dict(case=case, map_art=map_art, status='PASS', pawn_probes=len(probes), service_starts=starts, native_tripwires=0, allowed_metadata_queries=len(lookups)))
    report = dict(status='PASS', cases=rows, packaged_payload=bool(payload), scope='Real Lua 5.4 reduced-pack constructors and master callbacks, tripwire userdata; positive controls stub only island/Alex starts. No game/native acceptance.')
    path = evidence_root() / ('native-pack-title-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.json')
    write_json(path, report)
    display = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path.name
    print(f'RS PASS {len(rows)} native-pack title/readiness/lifecycle cases; {display}')
    return report
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--payload', type=Path)
    parser.add_argument('--generated-data', type=Path)
    args = parser.parse_args()
    run(args.payload, args.generated_data)
