# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Lua 5.4 compile, real constructor graph, and stubbed pack-service starts.

No game/UE process is contacted. Native callbacks are recorded, never executed.
Each choice sees ONLY files that its installer payload would provide.
"""
import os
from pathlib import Path
import argparse
import json
import sys
from common import *
sys.path.insert(0, str(ROOT / 'tools'))
from lua54_compile import runtime
SETUP = "\nlocal sources, config, generated = ...\nlocal files={};local loaded={};local hooks={};local keys={};local callbacks={};local factoryObjects={}\nlocal flags\nprint=function()end\nKey=setmetatable({}, {__index=function(_,k)return k end})\nModifierKey={CONTROL=1,SHIFT=2,ALT=3};EFindName={FNAME_Find=0,FNAME_Add=1};NAME_None='None'\nFName=function(s)return s end;FText=function(s)return s end\nStaticFindObject=function()return nil end\nFindFirstOf=function()return nil end;FindAllOf=function()return{}end\nRegisterHook=function(path,pre,post)hooks[path]={pre,post};return 1,2 end\nRegisterKeyBindAsync=function(key,mods,fn)keys[key]=fn end\nIsKeyBindRegistered=function()return false end\nRegisterKeyBind=RegisterKeyBindAsync\nNotifyOnNewObject=function(path,fn)hooks[path]={fn}end\nLoopInGameThreadWithDelay=function(ms,fn)callbacks[#callbacks+1]={ms,fn};return#callbacks end\nIsInGameThread=function()return true end\nio.open=function(path,mode)\n if path:match('/config.ini$')then return {read=function()return config end,close=function()end}end\n local dataName=path:match('/_palcraft/data/([%w_]+)%.json$')\n if dataName and generated and generated[dataName]then return {read=function()return generated[dataName]end,close=function()end}end\n if mode=='rb'or mode=='r'or mode==nil then return nil end\n return {write=function()end,flush=function()end,close=function()end}\nend\nlocal function compileFile(path)\n local name=path:match('([^/]+)%.lua$')\n assert(name and sources[name], 'Module unavailable for selected pack: '..tostring(path))\n loaded[name]=true\n local f,err=load(sources[name],'@'..path,'t',_ENV);assert(f,err)\n return f\nend\nloadfile=compileFile\ndofile=function(path)return compileFile(path)()end\nrequire=function(name)\n if package.loaded[name]then return package.loaded[name]end\n local r=dofile('/virtual/PalCraft/'..name:gsub('^PalCraft%.','')..'.lua')\n package.loaded[name]=r;return r\nend\nlocal ok,result=xpcall(function()return dofile('/virtual/PalCraft/Scripts/main.lua')end,debug.traceback)\nassert(ok,result)\nflags=dofile('/virtual/PalCraft/feature_flags.lua').parse(config)\nlocal P=dofile('/virtual/PalCraft/pack_services.lua')\nlocal starts={}\nfor _,service in ipairs({{'core','settings'},{'hud_skins','hud'},{'hud_skins','skins'},\n {'hud_skins','building'},{'hud_skins','controls'},{'islands_animals','islands'},\n {'islands_animals','mobs'},{'islands_animals','bosses'},{'islands_animals','village'},\n {'map_art','artwork'}})do\n local object={start=function()starts[#starts+1]=service[2]end}\n assert(P.start(flags,service[1],service[2],object,{})==flags:has(service[1]))\nend\nreturn {loaded=loaded,hooks=hooks,keys=keys,callbacks=#callbacks,starts=starts}\n"

def table_keys(value):
    return sorted((str(k) for k in value.keys()))

def run(payload=None, generated_data=None):
    manifest = read_json(ROOT / 'release/modules.json')
    tests = [r['module'] for r in manifest['lua'] if r['pack'] == 'test']
    texts = {r['module']: release_lua(r['path'], (ROOT / r['path']).read_text(encoding='utf-8-sig'), tests) for r in manifest['lua'] if r['pack'] != 'test'}
    if payload:
        texts = {}
        available_by_pack = {}
        for pack in PACKS:
            available_by_pack[pack] = set()
            base = Path(payload) / pack / MOD
            for p in base.rglob('*.lua'):
                texts[p.stem] = p.read_text(encoding='utf-8-sig')
                available_by_pack[pack].add(p.stem)
    compiler = runtime()
    compile_one = compiler.eval('function(s,n)local f,e=load(s,n,"t");assert(f,e);return true end')
    for name, source in texts.items():
        compile_one(source, '@' + name + '.lua')
    rows = []
    for choice in ('hud_skins,islands_animals', 'hud_skins', 'islands_animals'):
        for map_art in (0, 1):
            lua = runtime()
            selected = {'core', *choice.split(',')}
            if map_art and 'islands_animals' in selected:
                selected.add('map_art')
            names = {r['module'] for r in manifest['lua'] if r['pack'] in selected} if not payload else set().union(*(available_by_pack[p] for p in selected))
            sources = lua.table_from({n: s for n, s in texts.items() if n in names})
            config = f'packs = {choice}\nmap_art = {map_art}\n'
            generated = lua.table_from({p.stem: p.read_text(encoding='utf-8') for p in Path(generated_data).glob('*.json') if p.name != 'fixture-receipt.json'}) if generated_data else None
            try:
                result = lua.execute(SETUP, sources, config, generated)
            except Exception as error:
                if not payload:
                    raise
                rows.append(dict(choice=choice, map_art=map_art, status='BLOCKED', error=str(error)))
                continue
            loaded = table_keys(result['loaded'])
            if choice == 'hud_skins':
                assert not {'islands88', 'island', 'mobs', 'zombie77', 'alex', 'custom_palsA'} & set(loaded), loaded
            if choice == 'islands_animals':
                assert not {'phase_a', 'phase_b', 'phase_d', 'ui_entry', 'controls68', 'steve'} & set(loaded), loaded
            starts = list(result['starts'].values())
            assert ('artwork' in starts) == (bool(map_art) and 'islands_animals' in selected)
            rows.append(dict(choice=choice, map_art=map_art, loaded=loaded, constructor_count=len(loaded), callbacks=result['callbacks'], simulated_starts=starts, status='PASS'))
    lua = runtime()
    flags = lua.execute(texts['feature_flags'])
    assert not flags['parse']('packs=hud_skins\nmap_art=1')['map_art']
    for bad in ('packs=unknown', 'map_art=yes'):
        try:
            flags['parse'](bad)
        except Exception:
            pass
        else:
            raise AssertionError('Invalid config accepted: ' + bad)
    passed = all((r['status'] == 'PASS' for r in rows))
    data_receipt = read_json(Path(generated_data) / 'fixture-receipt.json') if generated_data and (Path(generated_data) / 'fixture-receipt.json').exists() else {}
    report = dict(status='PASS' if passed else 'BLOCKED', lua='5.4', compiled=len(texts), choices=rows, packaged_payload=bool(payload), private_local_data_fixture=bool(generated_data) and (not data_receipt.get('generated_from_user_resources', False)), generated_from_user_resources=data_receipt.get('generated_from_user_resources', False), scope='Real release entry/factory dependency graph. Native API callbacks recorded, not run. Service start gates simulated with stubs; visual/native behavior requires RA acceptance.')
    out = evidence_root()
    out.mkdir(parents=True, exist_ok=True)
    path = out / (('packaged-' if payload else '') + 'module-graph-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.json')
    write_json(path, report)
    display = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path.name
    print(f"{report['status']} {len(texts)} compiled modules; six isolated pack/map choices; {display}")
    return report
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--payload', type=Path)
    parser.add_argument('--generated-data', type=Path, help='Private local JSON fixtures or installer-generated data; never shipped')
    args = parser.parse_args()
    try:
        result = run(args.payload, args.generated_data)
        if result['status'] != 'PASS':
            sys.exit(1)
    except Exception as error:
        check_interrupt()
        progress('RS2_GRAPH', 'FAIL', str(error).splitlines()[0])
        raise
