# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
"""Release policy shared by the payload builder and clean-source exporter."""
from __future__ import annotations
import os
from datetime import datetime
from pathlib import Path
import fnmatch
import hashlib
import json
import os
import re
ROOT = Path(__file__).resolve().parents[2]
PACKS = ('core', 'hud_skins', 'islands_animals', 'map_art')
MOD = 'Mods/NativeMods/UE4SS/Mods/PalCraft'
SCHEMA = 'Mods/NativeMods/UE4SS/Mods/PalSchema/mods'
PAKS = 'Pal/Content/Paks/~mods/PalCraft'
UNSAFE = {'mojang', 'palworld', 'owner-personal', 'test'}
STRIP_FILES = ['task*.lua', '*probe*.lua', 'timer_tests.lua', 'map_historyN.lua', 'discovery*.lua', 'newworld_check65b.lua', 'harness*', '*fixture*', '*-enabled.txt', 'test-mode.txt', 'views.txt', 'skin_*-skinImage.png']
STRIP_FILES += ['sunny_x8.png', 'zuri_x8.png', 'owner-*.png', 'loading_dirt.png', 'alex.png', 'steve-wide.png', 'steve-slim.png']
TOKEN = re.compile('--\\[(=*)\\[.*?\\]\\1\\]|--[^\\n]*|\\[(=*)\\[.*?\\]\\2\\]|"(?:\\\\.|[^"\\\\])*"|\'(?:\\\\.|[^\'\\\\])*\'|[A-Za-z_][A-Za-z_0-9]*|\\S', re.S)

def evidence_root():
    return Path(os.environ.get('PALCRAFT_TEST_OUTPUT', str(ROOT / 'local/release/rs')))

def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for part in iter(lambda: f.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()

def progress(item, status, detail):
    target = ROOT / 'coordination/CODEX_PROGRESS.txt'
    if not target.parent.exists():
        return
    with target.open('a', encoding='utf-8') as f:
        f.write(f"{os.environ.get('PALCRAFT_TASK_PREFIX', 'RS')} {datetime.now():%H:%M} {item} {status} {detail}\n")

def check_interrupt():
    p = ROOT / 'coordination/OPUS_INTERRUPT.txt'
    if not p.exists():
        return
    text = p.read_text(encoding='utf-8-sig')
    matches = re.findall('SEQ\\s*(\\d+)', text)
    prior = (ROOT / 'coordination/CODEX_PROGRESS.txt').read_text(encoding='utf-8-sig')
    for seq in matches:
        if f'ACK INTERRUPT {seq}' not in prior:
            progress('ACK', 'INTERRUPT', seq)
    latest = re.split('(?=SEQ\\d+)', text)[-1]
    offline_authorized = 'offline work' in latest.lower() and 'NO game launch' in latest
    if re.search('STATU${PALCRAFT_ASSET_ROOT}', latest, re.I) or ('OWNER IS USING THE PC' in latest and (not offline_authorized)):
        raise RuntimeError('Coordination interrupt requires stopping: ' + latest)

def stripped(path):
    return any((fnmatch.fnmatch(Path(path).name.lower(), p.lower()) for p in STRIP_FILES))

def deps(source):
    result = set(re.findall('[/]([\\w]+)\\.lua[\'"]', source))
    result.update(re.findall('\\bload\\([\'"]([\\w]+)[\'"]\\)', source))
    result.update(re.findall('\\brequire\\([\'"](?:PalCraft\\.)?([\\w]+)[\'"]\\)', source))
    return result

def _remove_calls(source, names):
    pattern = re.compile('(?:UE\\.dofileJ|dofile|loadfile)\\([^\\n]*?/(' + '|'.join(map(re.escape, names)) + ')\\.lua[\'"]\\)')
    for match in reversed(list(pattern.finditer(source))):
        start, end = match.span()
        rest = source[end:]
        leading = len(rest) - len(rest.lstrip())
        if rest[leading:leading + 1] == '(':
            depth = 0
            for token in TOKEN.finditer(rest[leading:]):
                value = token[0]
                if value.startswith('--') or value.startswith(('"', "'", '[[')):
                    continue
                if value == '(':
                    depth += 1
                elif value == ')':
                    depth -= 1
                    if depth == 0:
                        end += leading + token.end()
                        break
        source = source[:start] + '(function()return nil end)()' + source[end:]
    return source

def release_lua(path, source, test_names=()):
    if Path(path).name == 'map_historyN.lua':
        return '-- SPDX-License-Identifier: GPL-3.0-or-later\nreturn {version=1,world="",rows={}}\n'
    source = source.replace('/map_historyN.lua', '/marker_history.lua')
    if Path(path).name == 'main.lua':
        source = re.sub("do local f=io.open\\(base\\.\\.'/test-mode.txt'.*?(?=Timers.trace)", 'config.test_mode=false;config.debug=false;config.legacy_debug_keys=false\n', source, flags=re.S)
        source, n = re.subn('^if config.test_mode then\\n    task12=.*?^end\\n', '', source, flags=re.M | re.S)
        if n != 1 and 'config.test_mode=false;config.debug=false;config.legacy_debug_keys=false' not in source:
            raise ValueError('Expected exactly one development dispatcher to strip')
        source = source.replace("UE.testWorld65 = '1F0EEEE64B0E92451CA03F94C3C9C5CE'", "UE.testWorld65 = string.rep('0',32)")
        source = re.sub('local profile=Timers.endBudgetProfile\\(\\);local f=.*?f:close\\(\\)', 'Timers.endBudgetProfile()', source)
    if Path(path).name == 'native_harvestR.lua':
        source = re.sub('^ local probe=io.open.*$', '', source, flags=re.M)
    source = _remove_calls(source, list(test_names)) if test_names else source
    source = TOKEN.sub(lambda m: '' if m[0].startswith('--') else m[0], source)
    source = source.replace('[MinecraftBlocks]', '[PalCraft]').replace("'MinecraftBlocks.timers'", "'PalCraft.timers'")
    source = source.replace('"MinecraftBlocks.timers"', '"PalCraft.timers"')
    source = re.sub('\\n[ \\t]*\\n(?:[ \\t]*\\n)+', '\n\n', source)
    return '-- SPDX-License-Identifier: GPL-3.0-or-later\n-- Copyright Invi\n' + source.lstrip()

def data_adapter(name):
    assert re.fullmatch('[A-Za-z_][A-Za-z_0-9]*', name)
    return f"-- SPDX-License-Identifier: GPL-3.0-or-later\n-- Copyright Invi\n-- PalCraft local-data adapter; original jar-derived table excluded.\nlocal base=debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\\\]')\nreturn dofile(base..'/local_data.lua').load(base,{name!r})\n"

class Audit:
    """Absent/unknown data never grants binary-asset clearance."""

    def __init__(self, path=None):
        default = ROOT / 'local/release/audit.json'
        if not default.exists():
            default = ROOT / 'release/provenance.json'
        self.path = Path(path or default)
        policy = ROOT / 'release/provenance_policy.json'
        self.policy = read_json(policy) if policy.exists() else {}
        self.data = read_json(self.path) if self.path.exists() else None
        self.rules = []
        if self.data:
            self._collect(self.data)
        self.exact = {}
        self.wildcards = []
        self.asset_licenses = {}
        if isinstance(self.data, list):
            for row in self.data:
                if isinstance(row, dict) and 'path' in row:
                    kind = str(row.get('kind', '')).lower()
                    license_id = 'GPL-3.0-or-later' if 'blueprint' in kind or 'material' in kind else 'CC-BY-4.0'
                    self.asset_licenses[self.canonical(row['path'])] = license_id
        for pattern, reasons in self.rules:
            if any((c in pattern for c in '*?[')):
                self.wildcards.append((pattern, reasons))
            else:
                self.exact.setdefault(pattern.rstrip('/'), set()).update(reasons)

    def _collect(self, value, inherited=(), path_hint=None):
        if isinstance(value, dict):
            if 'provenance' in value and self.effective_provenance(value) != value['provenance']:
                value = dict(value, provenance=self.effective_provenance(value))
            tag_values = []
            for key in ('category', 'classification', 'tags', 'provenance', 'license_class'):
                tag = value.get(key, [])
                tag_values.extend(tag if isinstance(tag, list) else [tag])
            tags = {str(t).lower().replace('_', '-') for t in tag_values} | set(inherited)
            blocked = {kind for kind in UNSAFE if any((t == kind or t.startswith(kind + '-') or t.startswith(kind + '/') for t in tags))}
            if value.get('exclude') is True or value.get('redistributable') is False:
                blocked.add('excluded')
            for key in ('path', 'source', 'pattern', 'glob', 'file', 'name'):
                if isinstance(value.get(key), str) and blocked:
                    self.rules.append((value[key].replace('\\', '/').lower(), sorted(blocked)))
                    self.rules.append((self.canonical(value[key]), sorted(blocked)))
            if path_hint and blocked:
                self.rules.append((path_hint.replace('\\', '/').lower(), sorted(blocked)))
            for key, item in value.items():
                if key in ('excluded_patterns', 'exclude_patterns', 'excluded_files') and isinstance(item, list):
                    self.rules.extend(((str(s).replace('\\', '/').lower(), ['excluded']) for s in item if isinstance(s, str)))
                tag = key.lower().replace('_', '-')
                child_tags = tags | ({tag} if any((tag == t or tag.startswith(t + '-') for t in UNSAFE)) else set())
                hint = key if '/' in key or '\\' in key or Path(key).suffix.lower() in ('.png', '.pak', '.uasset', '.lua') else path_hint
                if child_tags & UNSAFE and isinstance(item, list):
                    self.rules.extend(((v.replace('\\', '/').lower(), sorted(child_tags & UNSAFE)) for v in item if isinstance(v, str)))
                self._collect(item, child_tags, hint)
        elif isinstance(value, list):
            for item in value:
                self._collect(item, inherited, path_hint)

    def reasons(self, path):
        value = str(path).replace('\\', '/').lower()
        parts = [value, Path(value).name, self.canonical(value)]
        for prefix in ('runtime/', 'schema/', 'content/'):
            if prefix in value:
                parts.append(value[value.index(prefix):])
        found = set()
        for part in parts:
            found.update(self.exact.get(part, ()))
            parent = part
            while '/' in parent:
                parent = parent.rsplit('/', 1)[0]
                found.update(self.exact.get(parent, ()))
        for pattern, reasons in self.wildcards:
            if any((fnmatch.fnmatch(v, pattern) or v == pattern or v.startswith(pattern.rstrip('/') + '/') for v in parts)):
                found.update(reasons)
        return sorted(found)

    def asset_license(self, path):
        key = self.canonical(path)
        if key in self.asset_licenses:
            return self.asset_licenses[key]
        name = key.rsplit('/', 1)[-1]
        return 'GPL-3.0-or-later' if name.startswith(('bp_', 'abp_', 'm_', 'mi_', 'mf_')) else 'CC-BY-4.0'

    def effective_provenance(self, row):
        provenance = row.get('provenance')
        path = self.canonical(row.get('path', ''))
        if path.startswith('runtime/minecraftblocks/') and path.rsplit('/', 1)[-1] in self.policy.get('local_generation_lua', ()):
            return 'mojang'
        if not self.policy.get('original_box_geometry') or provenance not in ('mojang', 'unknown'):
            return provenance
        path = self.canonical(row.get('path', ''))
        name = path.rsplit('/', 1)[-1]
        if name in self.policy.get('geometry_lua', ()) and path.startswith('runtime/minecraftblocks/'):
            return 'ours'
        if row.get('kind') in self.policy.get('asset_kinds', ()) and path.startswith(('content/minecraft', 'content/custompals')):
            return 'ours'
        return provenance

    @staticmethod
    def canonical(path):
        path = str(path).replace('\\', '/').lower()
        for name in ('minecraftblocks', 'palcraft'):
            marker = '/mods/' + name + '/'
            if marker in path:
                return 'runtime/minecraftblocks/' + path.split(marker, 1)[1]
        if path.startswith('runtime/palcraft/'):
            return 'runtime/minecraftblocks/' + path[len('runtime/palcraft/'):]
        for marker in ('pal/content/', 'project/content/'):
            if marker in path:
                return 'content/' + path.split(marker, 1)[1]
        return path
PRIVATE_STEM = bytes((100, 97, 110, 105, 101))
ASCII_PATH = re.compile(b'(?<![A-Za-z])[A-Za-z]:[\\\\/][A-Za-z0-9_ .-]{3}')
UNICODE_PATH = re.compile(b'[A-Za-z]\\x00:\\x00[\\\\/]\\x00(?:[A-Za-z0-9_ .-]\\x00){3}')
EMAIL = re.compile(b'(?<![\\w.+-])[\\w.+-]{1,64}@[\\w.-]{1,253}\\.[A-Za-z]{2,63}')
APPROVED_EMAILS = {b'invi@users.noreply.github.com', b'licensing@fsf.org', b'info@fsf.org'}

def serialized_string_contains(raw, position, encoding):
    import struct
    for at in range(max(0, position - 4096), position + 1):
        if at + 4 > len(raw):
            break
        n = struct.unpack_from('<i', raw, at)[0]
        if encoding == 'utf-8' and 1 < n <= 65536:
            start = at + 4
            end = start + n - 1
            terminator = 1
        elif encoding == 'utf-16-le' and -65536 <= n < -1:
            start = at + 4
            end = start + (-n - 1) * 2
            terminator = 2
        else:
            continue
        if not start <= position < end or end + terminator > len(raw) or raw[end:end + terminator] != bytes(terminator):
            continue
        try:
            text = raw[start:end].decode(encoding)
        except UnicodeDecodeError:
            continue
        if all((ord(c) >= 32 or c in '\r\n\t' for c in text)):
            return True
    return False

def private_metadata(raw, binary=False, png=False):
    if png and raw.startswith(b'\x89PNG\r\n\x1a\n'):
        import struct, zlib
        parts = []
        offset = 8
        while offset + 12 <= len(raw):
            size = struct.unpack_from('>I', raw, offset)[0]
            kind = raw[offset + 4:offset + 8]
            data = raw[offset + 8:offset + 8 + size]
            if kind in (b'tEXt', b'iTXt', b'eXIf'):
                parts.append(data)
            if kind == b'zTXt':
                try:
                    parts.append(zlib.decompressobj().decompress(data.split(b'\x00', 1)[1][1:], 1048576))
                except Exception:
                    raise ValueError('Unrecognized compressed PNG metadata')
            offset += 12 + size
        raw = b'\n'.join(parts)
        binary = False
    lower = raw.lower()
    if PRIVATE_STEM in lower or PRIVATE_STEM.decode().encode('utf-16-le') in lower:
        return True
    for pattern, encoding in ((ASCII_PATH, 'utf-8'), (UNICODE_PATH, 'utf-16-le')):
        for match in pattern.finditer(raw):
            if not binary or serialized_string_contains(raw, match.start(), encoding):
                return True
    for match in EMAIL.finditer(raw):
        if match[0].lower() not in APPROVED_EMAILS and (not binary or serialized_string_contains(raw, match.start(), 'utf-8')):
            return True
    return False

def leak_scan(root, audit=None, approved_binaries=None):
    errors = []
    emails = EMAIL
    approved_binaries = approved_binaries or {}
    for p in sorted(Path(root).rglob('*')):
        if not p.is_file():
            continue
        rel = p.relative_to(root).as_posix()
        if PRIVATE_STEM in rel.lower().encode('utf-8'):
            errors.append((rel, 'personal identifier in filename'))
        if stripped(p) or ('/skins/' in '/' + rel.lower() and p.suffix.lower() == '.png'):
            errors.append((rel, 'excluded filename'))
        if audit and audit.reasons(rel):
            errors.append((rel, 'audit exclusion'))
        raw = p.read_bytes()
        if p.suffix.lower() in ('.pak', '.uasset', '.uexp', '.ubulk', '.png', '.jpg', '.jpeg', '.tga', '.dds', '.ogg', '.wav', '.fbx', '.blend'):
            if approved_binaries.get(rel) != hashlib.sha256(raw).hexdigest():
                errors.append((rel, 'binary asset lacks clean provenance/hash receipt'))
        if rel.lower().startswith(('project/content/pal/', 'content/pal/')) or p.name.lower() == 'pal-windows.pak':
            errors.append((rel, 'base-game content'))
        binary = p.suffix.lower() in ('.uasset', '.uexp', '.ubulk', '.pak', '.png', '.jpg', '.jpeg', '.tga', '.dds', '.ogg', '.wav', '.fbx', '.blend')
        if private_metadata(raw, binary=binary, png=p.suffix.lower() == '.png'):
            errors.append((rel, 'personal identifier or absolute local path'))
        if p.suffix.lower() not in ('.pak', '.uasset', '.uexp', '.ubulk'):
            for email in emails.findall(raw):
                if email.lower() not in (b'invi@users.noreply.github.com', b'licensing@fsf.org', b'info@fsf.org'):
                    errors.append((rel, 'unapproved email'))
            if p.suffix == '.lua' and re.search(b'harness-control|test-mode\\.txt|/task\\w*\\.lua', raw, re.I):
                errors.append((rel, 'development dispatcher or token'))
    if errors:
        raise ValueError('Release leak check failed: ' + json.dumps(errors[:30]))
    return True
