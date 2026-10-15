# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Copy an already validated local runtime cache into private graph-test input."""
import os
import argparse, sys
from common import *
sys.path.insert(0, str(ROOT / 'tools'))
from lua54_compile import runtime

def main(evidence):
    evidence = Path(evidence)
    evidence = evidence if evidence.is_absolute() else ROOT / evidence
    assert read_json(evidence / 'report.json')['status'] == 'PASS'
    base = evidence / 'PalCraft'
    L = runtime()
    G = L.eval('dofile')((base / 'jar_data.lua').as_posix())
    J = L.eval('dofile')((base / 'json.lua').as_posix())
    wrap = L.eval("function(v)local function w(x)if type(x)~='table'then return x end;local entries={};for k,y in pairs(x)do entries[#entries+1]={key=k,value=w(y)}end;return{entries=entries}end;return{format='palcraft-lua-table-v1',value=w(v)}end")
    out = evidence / 'generated-modules'
    out.mkdir(exist_ok=True)
    rows = []
    for row in read_json(ROOT / 'release/data_contract.json')['modules']:
        value, mode = G['load'](base.as_posix(), row['module'])
        assert mode == 'disk-cache'
        p = out / (row['module'] + '.json')
        p.write_text(J['encode'](wrap(value)), encoding='utf-8')
        rows.append(dict(module=row['module'], sha256=sha(p)))
    write_json(out / 'fixture-receipt.json', dict(private_test_fixture=False, generated_from_user_resources=True, reference_tables_copied=False, validation_receipt_sha256=sha(evidence / 'report.json'), source=read_json(base / 'assets/minecraft/_palcraft/source.json'), files=rows))
    print('RS generated graph input:', out.relative_to(ROOT))
if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('evidence', type=Path)
    main(p.parse_args().evidence)
