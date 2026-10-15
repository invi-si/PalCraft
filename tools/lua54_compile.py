# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Use actual Lua 5.4 parsing, including its 200-active-local limit."""
import os
import sys, json, hashlib, os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
TOOL = Path(os.environ.get('MC_LUA54_DIR', str(ROOT / 'local/taskL/lua54-tool')))
if not TOOL.is_dir():
    raise RuntimeError('Lua5.4 compiler missing; provision lupa with lua54 under MC_LUA54_DIR. Do not substitute Lua5.3.')
sys.path.insert(0, str(TOOL))
from lupa.lua54 import LuaRuntime

def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    assert lua.eval('_VERSION') == 'Lua 5.4'
    bad = 'local ' + ','.join(('v' + str(i) for i in range(201))) + ';return true'
    result = lua.eval('load')(bad, '@local-limit-negative', 't')
    assert isinstance(result, tuple) and result[0] is None and ('too many local variables' in result[1])
    return lua

def evaluate(source):
    return runtime().execute(source)

def compile_tree(root):
    lua = runtime()
    compile = lua.eval('function(s,n) local f,e=load(s,n,"t");assert(f,e);return true end')
    rows = {}
    for p in sorted(Path(root).rglob('*.lua')):
        raw = p.read_bytes()
        compile(raw.decode('utf-8-sig'), '@' + str(p))
        rows[str(p.relative_to(root))] = hashlib.sha256(raw).hexdigest()
    return dict(version=lua.eval('_VERSION'), files=len(rows), sha256=rows, negativeLocalLimitRejected=True)
if __name__ == '__main__':
    report = compile_tree(Path(sys.argv[1]))
    print(json.dumps(report, indent=2))
