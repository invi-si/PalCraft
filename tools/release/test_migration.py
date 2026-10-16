# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Exercise copy-only PowerShell migration and Lua legacy-family fallback offline."""
import os
import subprocess
import sys
from common import *
sys.path.insert(0, str(ROOT / 'tools'))
from lua54_compile import runtime

def run():
    root = evidence_root() / ('migration-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
    old = root / 'MinecraftBlocks'
    new = root / 'PalCraft'
    old.mkdir(parents=True)
    new.mkdir()
    world = 'A' * 32
    rows = {'blocks-' + world + '.json': '{"sequence":4}', 'blocks-' + world + '.json.bak': '{"sequence":3}', 'blocks-' + world + '.json.tmp': '{"sequence":5}', 'inventory-pending-' + world + '.json': '{"pending":true}', 'plains-trades-x8-' + world + '.json': '{"pending":true}', 'bed-spawn-' + world + '.json': '{"bed":1}', 'ui-settings.json': '{"hud":true}', 'skin-selection.json': '{}'}
    for name, value in rows.items():
        (old / name).write_text(value)
    (old / 'task99-enabled.txt').write_text('developer token')
    conflict = new / ('bed-spawn-' + world + '.json')
    conflict.write_text('{"bed":2}')
    (new / 'ui-settings.json').write_bytes(b'')
    script = ROOT / 'release/installer/migrate-legacy.ps1'

    def call(dry=False):
        args = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', '& {param($s,$a,$b,$dry) @(& $s -LegacyDir $a -TargetDir $b -WhatIf:([bool]$dry)) | ConvertTo-Json -Depth 5} ' + ' '.join(("'" + str(p).replace("'", "''") + "'" for p in (script, old, new))) + (' 1' if dry else ' 0')]
        p = subprocess.run(args, capture_output=True, text=True, encoding='utf-8')
        if p.returncode:
            raise AssertionError(p.stderr)
        return json.loads(p.stdout)
    before = {p.name: sha(p) for p in old.iterdir()}
    dry = call(True)
    assert len(list(new.iterdir())) == 2
    actual = call()
    assert not any((r['Status'] == 'failed' for r in actual)), actual
    assert sum((r['Status'] == 'conflict' for r in actual)) == 1
    assert conflict.read_text() == '{"bed":2}'
    assert not (new / 'task99-enabled.txt').exists()
    assert before == {p.name: sha(p) for p in old.iterdir()}
    again = call()
    assert all((r['Status'] in ('identical', 'conflict') for r in again))
    lua = runtime()
    base = ROOT / 'runtime/PalCraft'
    if not base.exists():
        base = ROOT / 'runtime/MinecraftBlocks'
    fallback = lua.execute((base / 'legacy_paths.lua').read_text())
    check = lua.eval("function(P)\n     local content={['/mods/MinecraftBlocks/blocks-A.json']='old',['/mods/MinecraftBlocks/blocks-A.json.tmp']='newer-old'}\n     local function open(p) local s=content[p];if not s then return nil end;return{seek=function()return#s end,close=function()end}end\n     assert(P.readPath('/mods/PalCraft/blocks-A.json',open)=='/mods/MinecraftBlocks/blocks-A.json')\n     content['/mods/PalCraft/blocks-A.json']='new'\n     assert(P.readPath('/mods/PalCraft/blocks-A.json.tmp',open)=='/mods/PalCraft/blocks-A.json.tmp')\n     content['/mods/PalCraft/blocks-A.json']=''\n     assert(P.readPath('/mods/PalCraft/blocks-A.json',open)=='/mods/MinecraftBlocks/blocks-A.json')\n     content['/mods/PalCraft/blocks-A.json.bak']='recovery'\n     assert(P.readPath('/mods/PalCraft/blocks-A.json',open)=='/mods/PalCraft/blocks-A.json')\n     return true\n    end")
    assert check(fallback)
    aliases = lua.execute((base / 'npc_legacy.lua').read_text())
    alias_check = lua.eval("function(M)\n     local s={version=1,limits={sunny_pick={used=2,resetAt=10},bram_pick={used=1,resetAt=20},zuri_arrow={used=3,resetAt=30}},\n      pending={key='sunny_pick'},receipts={{key='zuri_arrow'}}}\n     M.journal(s)\n     assert(s.limits.sunny_pick==nil and s.limits.bram_pick.used==2 and s.limits.bram_pick.resetAt==20)\n     assert(s.limits.rina_arrow.used==3 and s.pending.key=='bram_pick'and s.receipts[1].key=='rina_arrow')\n     return true\n    end")
    assert alias_check(aliases)
    report = dict(status='PASS', copy_only=True, repeat_idempotent=True, recovery_generations=True, conflicts_preserved=True, dry_run_zero_writes=True, lua_family_fallback=True, npc_journal_aliases=True, results=actual)
    write_json(root / 'report.json', report)
    display = root.relative_to(ROOT) if root.is_relative_to(ROOT) else root.name
    print('PASS migration: dry run, copy/hash, temp/bak, conflict, repeat, Lua family fallback; ' + str(display))
if __name__ == '__main__':
    try:
        run()
    except Exception as error:
        check_interrupt()
        progress('RS3_TEST', 'FAIL', str(error))
        raise
