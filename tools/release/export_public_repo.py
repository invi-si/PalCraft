# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Export a fresh public PalCraft tree with no private history or asset payloads."""
from __future__ import annotations
import os
import pathlib
import argparse
import ast
import os
import shutil
import uuid
from common import *

def portable_python(source):
    tree = ast.parse(source)
    _scrub = pathlib.Path(__file__).resolve().parents[2] / 'local' / 'release' / 'scrub_private.txt'
    _frag = [l.strip() for l in _scrub.read_text(encoding='utf-8').splitlines() if l.strip()] if _scrub.exists() else []
    private = '(?:' + '|'.join(map(re.escape, _frag)) + ')' if _frag else '(?!x)x'
    roots = [('UE_5.1', 'PALCRAFT_UE_ROOT'), ('PalworldModdingKit', 'PALCRAFT_KIT_ROOT'), ('MinecraftModEvidence', 'PALCRAFT_EVIDENCE_ROOT'), ('PalworldSteveDev', 'PALCRAFT_PROJECT_ROOT')]

    class Paths(ast.NodeTransformer):

        def visit_JoinedStr(self, node):
            for part in node.values:
                if isinstance(part, ast.Constant) and isinstance(part.value, str):
                    part.value = re.sub('[A-Za-z]:[/\\\\][^\\s\\n\\r\\\'"<>]*', '${PALCRAFT_ASSET_ROOT}', part.value)
                    part.value = re.sub(private, 'Invi', part.value, flags=re.I)
            return node

        def visit_Constant(self, node):
            if not isinstance(node.value, str):
                return node
            value = node.value
            if re.match('^[A-Za-z]:[/\\\\]', value):
                normalized = value.replace('\\', '/')
                env = 'PALCRAFT_ASSET_ROOT'
                tail = ''
                for name, key in roots:
                    if name.lower() in normalized.lower():
                        at = normalized.lower().index(name.lower()) + len(name)
                        env, tail = (key, normalized[at:])
                        break
                expression = f"os.environ.get({env!r}, '.') + {tail!r}"
                return ast.copy_location(ast.parse(expression, mode='eval').body, node)
            node.value = re.sub('[A-Za-z]:[/\\\\][^\\s\\n\\r\\\'"<>]*', '${PALCRAFT_ASSET_ROOT}', value)
            node.value = re.sub(private, 'Invi', node.value, flags=re.I)
            return node
    tree = Paths().visit(tree)
    at = 1 if tree.body and isinstance(tree.body[0], ast.Expr) and isinstance(tree.body[0].value, ast.Constant) and isinstance(tree.body[0].value.value, str) else 0
    while at < len(tree.body) and isinstance(tree.body[at], ast.ImportFrom) and (tree.body[at].module == '__future__'):
        at += 1
    tree.body.insert(at, ast.Import(names=[ast.alias(name='os')]))
    ast.fix_missing_locations(tree)
    text = ast.unparse(tree) + '\n'
    compile(text, '<public-tool>', 'exec')
    return '# SPDX-License-Identifier: GPL-3.0-or-later\n# Copyright Invi\n' + text

def export(content_root=None, source_manifest=None, candidate=False):
    check_interrupt()
    progress('RS5_EXPORT', 'START', 'fresh public source tree')
    manifest = read_json(ROOT / 'release/modules.json')
    audit = Audit()
    tests = [r['module'] for r in manifest['lua'] if r['pack'] == 'test']
    stage = ROOT / 'release' / ('.public-staging-' + uuid.uuid4().hex)
    stage.mkdir()
    files = []
    omitted = []
    issues = []
    approved_binaries = {}
    excluded_runtime = []

    def emit(value, relative, binary=False, license_id=None):
        p = stage / relative
        assert p.resolve().is_relative_to(stage.resolve())
        p.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(value, bytes):
            p.write_bytes(value)
        else:
            p.write_text(value, encoding='utf-8', newline='\n')
        files.append(dict(path=relative, sha256=sha(p), bytes=p.stat().st_size))
        if p.suffix == '.json' or binary:
            label = license_id or ('CC-BY-4.0' if binary else 'GPL-3.0-or-later')
            p.with_name(p.name + '.license').write_text(f'SPDX-FileCopyrightText: Invi\nSPDX-License-Identifier: {label}\n', encoding='utf-8')
    emit('local/\nrelease/dist/\nrelease/evidence/\n__pycache__/\n*.pyc\nproject/Saved/\nproject/Intermediate/\nproject/DerivedDataCache/\nproject/Binaries/\nruntime/PalCraft/assets/\nruntime/PalCraft/skins/*.png\nruntime/PalCraft/skins/_cache/\n', '.gitignore')
    emit('*.lua text eol=lf\n*.py text eol=lf\n*.json text eol=lf\n*.uasset binary\n*.uexp binary\n*.ubulk binary\n*.png binary\n', '.gitattributes')
    public_manifest = json.loads(json.dumps(manifest))
    old_root = Path(manifest['runtime_source_root'])
    public_manifest['runtime_source_root'] = 'runtime/PalCraft'
    for row in public_manifest['lua']:
        original = row['path']
        row['path'] = 'runtime/PalCraft/' + Path(original).relative_to(old_root).as_posix()
        if row['pack'] == 'test' or audit.reasons(original):
            omitted.append(dict(path=row['path'], reason='Excluded development/private/audited file'))
            if row['pack'] != 'test' and audit.reasons(original) == ['mojang']:
                emit(data_adapter(row['module']), row['path'])
                row['local_data_adapter'] = True
                excluded_runtime.append(row['module'])
            elif row['pack'] != 'test':
                excluded_runtime.append(row['module'])
            continue
        emit(release_lua(original, (ROOT / original).read_text(encoding='utf-8-sig'), tests), row['path'])
    emit((ROOT / old_root / 'config.ini').read_text(), 'runtime/PalCraft/config.ini')
    emit('', 'runtime/PalCraft/enabled.txt')
    emit('Place your own skins here. Vanilla assets are generated locally by the installer.\n', 'runtime/PalCraft/skins/README.txt')
    for row in public_manifest['schema']:
        original = row['path']
        row['path'] = 'schema/' + row['destination']
        for p in sorted((ROOT / original).rglob('*.json')):
            rel = p.relative_to(ROOT).as_posix()
            if audit.reasons(rel):
                omitted.append(dict(path=rel, reason='Audit exclusion'))
                continue
            emit(p.read_bytes(), row['path'] + '/' + p.relative_to(ROOT / original).as_posix())
    public_manifest['paks'] = []
    emit(json.dumps(public_manifest, indent=2) + '\n', 'release/modules.json')
    for name in ('README.md', 'INSTALL.md', 'RELEASE_NOTES.md', 'BUILD.md', 'CONTRIBUTING.md', 'ARCHITECTURE.md', 'LICENSE', 'LICENSE-ART.md', 'ART_PROMPTS.md'):
        p = ROOT / 'release' / name
        if p.exists():
            emit(p.read_bytes(), name)
    for p in sorted((ROOT / 'release/installer').rglob('*')):
        if p.is_file() and p.suffix.lower() in ('.ps1', '.bat', '.json', '.md'):
            if 'tests' in p.relative_to(ROOT / 'release/installer').parts:
                continue
            if p.name == 'migrate-legacy.ps1' or not stripped(p):
                raw = p.read_text(encoding='utf-8-sig')
                prefix = '# SPDX-License-Identifier: GPL-3.0-or-later\n# Copyright Invi\n'
                if p.suffix == '.ps1' and 'SPDX-License-Identifier:' not in raw:
                    raw = prefix + raw
                if p.suffix == '.bat' and 'SPDX-License-Identifier:' not in raw:
                    raw = '@REM SPDX-License-Identifier: GPL-3.0-or-later\n@REM Copyright Invi\n' + raw
                emit(raw, 'release/installer/' + p.relative_to(ROOT / 'release/installer').as_posix())
    tools = list((ROOT / 'tools/release').glob('*.py')) + [ROOT / 'tools/lua54_compile.py']
    tools += list((ROOT / 'tools/assets').glob('*.py'))
    tools += [p for p in (ROOT / 'tools').glob('ue_*.py') if p.name in ('ue_authoring.py', 'ue_blocks.py', 'ue_mc_shared_materials.py')]
    for p in sorted(set(tools)):
        if p.name in ('prepare_runtime.py', 'prepare_local_data_fixtures.py', 'prepare_local_data_plans.py', 'rename_npcs.py'):
            continue
        emit(portable_python(p.read_text(encoding='utf-8-sig')), p.relative_to(ROOT).as_posix())
    for p in sorted((ROOT / 'tools/release').glob('*.ps1')):
        emit(p.read_text(encoding='utf-8-sig'), p.relative_to(ROOT).as_posix())
    art_path = ROOT / 'release/art.json'
    if art_path.exists():
        public_art = read_json(art_path)
        for row in public_art['assets']:
            source = ROOT / row['source']
            if row.get('clean') is not True or row.get('provenance') != 'ours' or sha(source) != row['sha256']:
                raise ValueError('Original art changed since registration')
            relative = row['public_path']
            emit(source.read_bytes(), relative, binary=True, license_id=row['license'])
            approved_binaries[relative] = row['sha256']
            row['source'] = relative
        emit(json.dumps(public_art, indent=2) + '\n', 'release/art.json')
    policy_path = ROOT / 'release/provenance_policy.json'
    if policy_path.exists():
        emit(policy_path.read_bytes(), 'release/provenance_policy.json')
    contract = ROOT / 'release/data_contract.json'
    if contract.exists():
        emit(contract.read_bytes(), 'release/data_contract.json')
    for p in sorted((ROOT / 'release/asset-runtime').glob('*')):
        if p.is_file() and p.suffix.lower() in ('.ps1', '.cs', '.json', '.md'):
            emit(p.read_bytes(), 'release/asset-runtime/' + p.name)
    for p in sorted((ROOT / 'project').rglob('*')):
        if p.is_file() and p.suffix.lower() in ('.ini', '.uproject'):
            text = p.read_text(encoding='utf-8-sig')
            if re.search('[A-Za-z]:[/\\\\]', text):
                omitted.append(dict(path=p.relative_to(ROOT).as_posix(), reason='Local project config'))
                continue
            emit(text, p.relative_to(ROOT).as_posix())
    content_root = Path(content_root or os.environ.get('PALCRAFT_CONTENT_ROOT', os.path.join(os.environ.get('PALCRAFT_KIT_ROOT', '.'), 'Content')))
    approved_path = Path(source_manifest or ROOT / 'local/release/source-assets.json')
    count = 0
    if approved_path.exists():
        approved = read_json(approved_path)
        rows = approved.get('assets', []) if isinstance(approved, dict) else approved
        for row in rows:
            relative = row['path'].replace('\\', '/').removeprefix('Content/')
            if not relative.startswith(('Minecraft', 'CustomPals')) or '..' in Path(relative).parts:
                raise ValueError('Source-content path outside original package roots')
            source = content_root / relative
            if row.get('source_override'):
                source = (ROOT / row['source_override']).resolve(strict=True)
                if not source.is_relative_to((ROOT / 'local').resolve()) or row.get('non_metadata_bytes_identical') is not True:
                    raise ValueError('Source metadata override must be a receipted evidence-only copy')
            if row.get('clean') is not True or not row.get('sha256') or sha(source) != row['sha256']:
                raise ValueError('Source asset lacks matching clean SHA256 receipt: ' + relative)
            reasons = audit.reasons('Content/' + relative)
            blank_receipt = ROOT / 'local/taskRA/blank-result.json'
            cleared_replacement = reasons == ['mojang'] and row.get('replacement_method') == 'blank-placeholder' and blank_receipt.exists() and (sha(blank_receipt) == row.get('blank_receipt_sha256'))
            if reasons and (not cleared_replacement):
                omitted.append(dict(path='Content/' + relative, reason='Audit exclusion'))
                continue
            emit(source.read_bytes(), 'project/Content/' + relative, binary=True, license_id=audit.asset_license('Content/' + relative))
            approved_binaries['project/Content/' + relative] = row['sha256']
            count += 1
        if isinstance(approved, dict) and approved.get('complete') is not True:
            issues.append('Source asset owner has not marked the cleared source set complete')
        if isinstance(approved, dict) and approved.get('excluded'):
            issues.append(f"{len(approved['excluded'])} required source packages remain excluded by provenance/metadata review")
    else:
        issues.append('Clean source asset receipt pending; original binary packages omitted')
    if not count:
        issues.append('No cleared modding-kit source content supplied')
    if audit.data is None:
        issues.append('Provenance audit pending')
    if excluded_runtime:
        receipt_path = ROOT / 'local/release/data-generator.json'
        generator = read_json(receipt_path) if receipt_path.exists() else {}
        ready = generator.get('complete') is True and set(excluded_runtime) <= set(generator.get('modules', ()))
        if ready:
            scripts = generator.get('scripts', [])
            ready = bool(scripts) and all((sha(ROOT / r['source']) == r['sha256'] for r in scripts))
        if not ready:
            issues.append(f'{len(excluded_runtime)} required data modules need local generation or cleared replacements')
    if issues and (not candidate):
        write_json(stage / 'EXPORT_BLOCKED.json', dict(status='BLOCKED', reasons=issues))
        raise RuntimeError('Public export incomplete: ' + '; '.join(issues))
    leak_scan(stage, approved_binaries=approved_binaries)
    write_json(stage / 'PUBLIC_EXPORT.json', dict(status='CANDIDATE' if issues else 'READY', fresh_history=True, author='Invi <invi@users.noreply.github.com>', source_content_packages=count, incomplete_reasons=issues, files=files, omitted=omitted))
    leak_scan(stage, approved_binaries=approved_binaries)
    destination = ROOT / 'release/public_repo'
    if destination.exists():
        evidence = ROOT / 'release/evidence'
        evidence.mkdir(exist_ok=True)
        backup = evidence / ('public-repo-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])
        assert destination.resolve().is_relative_to((ROOT / 'release').resolve())
        assert backup.resolve().is_relative_to(evidence.resolve())
        shutil.move(str(destination), str(backup))
    shutil.move(str(stage), str(destination))
    progress('RS5_EXPORT', 'PASS', f"{('CANDIDATE' if issues else 'READY')} files={len(files)} source-assets={count}")
    print(json.dumps(dict(status='CANDIDATE' if issues else 'READY', files=len(files), source_assets=count, reasons=issues), indent=2))
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content-root', type=Path)
    parser.add_argument('--source-manifest', type=Path)
    parser.add_argument('--candidate', action='store_true')
    args = parser.parse_args()
    try:
        export(args.content_root, args.source_manifest, args.candidate)
    except Exception as error:
        check_interrupt()
        progress('RS5_EXPORT', 'FAIL', str(error))
        raise
