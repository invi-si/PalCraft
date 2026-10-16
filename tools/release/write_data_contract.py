# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Write data-loader schemas and the installer handoff without copying data."""
import os
from common import *

def main():
    audit = Audit()
    modules = read_json(ROOT / 'release/modules.json')
    rows = [dict(module=r['module'], pack=r['pack'], output='assets/minecraft/_palcraft/data/' + r['module'] + '.json') for r in modules['lua'] if r['pack'] != 'test' and (audit.reasons(r['path']) == ['mojang'] or r.get('local_data_adapter'))]
    contract = dict(format_version=1, encoding='palcraft-lua-table-v1', envelope={'format': 'palcraft-lua-table-v1', 'value': {'entries': [{'key': 'string-or-number', 'value': 'scalar-or-recursive-table'}]}}, purpose='Generate from the installing user jar/index; no precomputed Mojang table is distributed.', validation={'registry': 'Array starts with name=dirt; unique names and mesh strings; preserve saved block/variant bindings.', 'item_registry': 'items map and order list; preserve original mod item identifiers.', 'strings57': 'items, ui and fragments maps.', 'font53_metrics': 'Numeric codepoint keys; can be unused when native font fallback is selected.'}, modules=rows)
    write_json(ROOT / 'release/data_contract.json', contract)
    header = ['RS data generator handoff (no data payloads in this file).', 'Release/public export now contain original local_data.lua adapters, replacing flagged Lua tables.', 'Installer must generate the JSON module values below from the user jar/index before enabling PalCraft.', 'Schema: release/data_contract.json. Numeric/mixed Lua keys are preserved by the entries encoding.', 'Private validation fixtures exist under local/release/rs/data-fixtures-*; NEVER COPY THEM INTO RELEASE.', 'Write local/release/data-generator.json with complete:true, modules:[...], and hash-bound installer scripts when implemented.', 'Then RS can mark the archive READY after packaged graph checks. No current build is installable until this exists.', 'Modules: ' + ', '.join((r['module'] for r in rows))]
    if (ROOT / 'coordination').exists():
        (ROOT / 'coordination/RS_DATA_HANDOFF.txt').write_text('\n'.join(header) + '\n', encoding='utf-8')
    print('Data contract:', len(rows), 'modules; values excluded')
if __name__ == '__main__':
    main()
