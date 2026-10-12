"""Local source-backed inventory, bounded evidence states and observed usage."""
import copy
import hashlib
import json
import os
import re
from pathlib import Path
import sqlite3
import time
from pe import inspect_pe

MODELS = {
    'luna': {'name': 'Luna High', 'backend': 'codex', 'model': 'gpt-6-luna'},
    'sol': {'name': 'Sol High', 'backend': 'codex', 'model': 'gpt-6.1-sol'},
    'astra': {'name': 'Astra High', 'backend': 'codex', 'model': 'gpt-6-astra'},
    'kimi': {'name': 'Kimi K3 High', 'backend': 'opencode', 'model': 'nvidia/moonshotai/kimi-k3#high'},
}


def load_json(path, default=None):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def readonly_db(path):
    return sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True, timeout=2)


def start_ticks(pid):
    try:
        return Path(f'/proc/{int(pid)}/stat').read_text().rsplit(')', 1)[1].split()[19]
    except (OSError, ValueError, IndexError):
        return None


def alive(pid, ticks=None):
    try:
        fields = Path(f'/proc/{int(pid)}/stat').read_text().rsplit(')', 1)[1].split()
        return fields[0] != 'Z' and (ticks is None or fields[19] == str(ticks))
    except (OSError, ValueError, IndexError):
        return False


def workers():
    result = []
    for path in Path('/proc').iterdir():
        if not path.name.isdigit():
            continue
        try:
            name = (path / 'comm').read_text().strip()
            args = (path / 'cmdline').read_bytes().decode(errors='replace').split('\0')
            if not alive(path.name):
                continue
            if not ((name == 'codex' and 'exec' in args) or (name == 'opencode' and 'run' in args) or name == 'zcode-cli'):
                continue
            if name == 'zcode-cli':
                fields = (path / 'stat').read_text().rsplit(')', 1)[1].split()
                if Path(f'/proc/{fields[1]}/comm').read_text().startswith('zcode-host'):
                    continue
            model = next((args[args.index(flag) + 1] for flag in ('-m', '--model') if flag in args), name)
            result.append(dict(pid=int(path.name), model=model, kind=name, scope=Path(os.readlink(path / 'cwd')).name, owned=False))
        except (OSError, ValueError, IndexError):
            continue
    return result


class Catalog:
    def __init__(self, project, source):
        self.root, self.source = Path(project).resolve(), Path(source)
        self.seed = load_json(self.source / 'catalog.json', {})
        self.base = self.root / 'extracted/1.0.0.30839'
        self.files = {str(p.relative_to(self.base)): p for p in sorted(self.base.rglob('*.dll'))} if self.base.exists() else {}
        self.cache = {}

    def inventory(self):
        vendor = set(self.seed) | {'VinceEditor.dll', 'nle_core.dll', 'base.dll', 'album_sdk.dll', 'effect.dll', 'nd_filter.dll', 'video_denoise.dll', 'video_analysis.dll', 'adaptive_video_tone.dll', 'audio_highlight.dll', 'pano_selfcali.dll', 'dual_fisheye_video_eis_win.dll', 'PerfMonitorSDK.dll', 'resource_sdk.dll'}
        return [dict(id=name, name=name, bytes=p.stat().st_size, category='application' if name in vendor else 'dependency') for name, p in sorted(self.files.items(), key=lambda item: (item[0] not in self.seed, list(self.seed).index(item[0]) if item[0] in self.seed else item[0]))]

    def evidence_state(self, part):
        review = part.get('review_json')
        markdown = part.get('review_markdown')
        if markdown:
            file = (self.root / markdown).resolve()
            if not file.is_relative_to(self.root) or not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != part.get('review_sha256'):
                part.update(research='blocked', statusSource='Pinned bounded review no longer matches')
            elif re.search(r'^Disposition: approved for the bounded (?:scalar Rust|decimal) leaf[.]', file.read_text(), re.MULTILINE):
                part['research'] = 'reviewed'
            else:
                part['research'] = 'unreviewed'
            return part
        if not review:
            return part
        data = load_json(self.root / review)
        if not isinstance(data, dict):
            part['research'] = 'unreviewed'
            part['statusSource'] = 'The declared review artifact is unavailable'
            return part
        if part.get('review_sha256') and hashlib.sha256((self.root / review).read_bytes()).hexdigest() != part['review_sha256']:
            part.update(research='blocked', statusSource='The pinned review record has changed')
            return part
        decision = str(data.get('decision', data.get('disposition', ''))).lower()
        candidate = data.get('candidate', {})
        valid = True
        for key, hash_key in [('contract', 'contract_sha256'), ('manifest', 'manifest_sha256'), ('report_path', 'report_sha256')]:
            if isinstance(candidate, dict) and candidate.get(key) and candidate.get(hash_key):
                file = (self.root / candidate[key]).resolve()
                valid = valid and file.is_relative_to(self.root) and file.is_file()
                if valid:
                    valid = hashlib.sha256(file.read_bytes()).hexdigest() == candidate[hash_key]
        for pin in part.get('review_pins', []):
            file = (self.root / pin['path']).resolve()
            valid = valid and file.is_relative_to(self.root) and file.is_file()
            if valid:
                valid = hashlib.sha256(file.read_bytes()).hexdigest() == pin['sha256']
        if not valid:
            part['research'] = 'blocked'
            part['statusSource'] = 'Reviewed candidate pins no longer match'
        elif decision == 'approved' or decision.startswith('approved_bounded'):
            part['research'] = 'reviewed'
            part['statusSource'] = part.get('statusSource', 'Recorded bounded independent review')
        elif decision in ('changes_requested', 'rejected'):
            part['research'] = 'blocked'
            part['statusSource'] = 'Review requests changes'
        else:
            part['research'] = 'unreviewed'
        return part

    def module(self, ident):
        if ident not in self.files:
            raise ValueError('Unknown DLL')
        file = self.files[ident]
        stamp = (file.stat().st_mtime_ns, file.stat().st_size)
        if self.cache.get(ident, (None,))[0] != stamp:
            self.cache[ident] = (stamp, inspect_pe(file))
        result = copy.deepcopy(self.cache[ident][1])
        seed = self.seed.get(ident, {})
        parts = copy.deepcopy(seed.get('parts', []))
        if not parts:
            parts = [dict(id='exports', label='Export contracts', group='Interfaces', detail='Resolve original exports and their actual target bodies.', addresses=[], research='missing', implementation='missing', reference='missing', missing=['Per-export behavior and independent evidence review'], evidence=[]),
                     dict(id='internals', label='Internal behavior', group='Implementation', detail='Trace internal procedure and dependency behavior from original bytes.', addresses=[], research='missing', implementation='missing', reference='missing', missing=['Internal method contracts and dependency joins'], evidence=[]),
                     dict(id='reference', label='Reference comparison', group='Validation', detail='Compare behavior with the original build and representative inputs.', addresses=[], research='missing', implementation='missing', reference='missing', missing=['Reproducible original-reference observations'], evidence=[])]
        for part in parts:
            self.evidence_state(part)
            part.setdefault('owner', None)
        expected = seed.get('sha256')
        if expected and expected != result['sha256']:
            for part in parts:
                part['research'] = 'blocked'
                part['statusSource'] = 'Original DLL hash differs from the catalog pin'
        result.update(id=ident, name=ident, path=str(file.relative_to(self.root)), bytes=file.stat().st_size,
                      category=next(item['category'] for item in self.inventory() if item['id'] == ident), parts=parts, notes=seed.get('notes', 'PE metadata establishes structure. Its behavior is not yet mapped.'))
        return result

    def selections(self, module, ids):
        if not isinstance(ids, list) or not 1 <= len(ids) <= 40 or any(not isinstance(x, str) for x in ids):
            raise ValueError('Select between 1 and 40 parts')
        found = {part['id']: part for part in module['parts']}
        for export in module['exports']:
            found.setdefault('export:' + export['va'], dict(id='export:' + export['va'], label=export['name'], addresses=[export['va']], detail='Original PE export; actual body contract requires evidence.', evidence=[], research='missing', implementation='missing', reference='missing', missing=['Target behavior, caller/dependency joins and review']))
        if len(set(ids)) != len(ids) or any(x not in found for x in ids):
            raise ValueError('Unknown or duplicate selected part')
        return [found[x] for x in ids]

    def artifact(self, relative):
        allowed = {e['path'] for seed in self.seed.values() for p in seed.get('parts', []) for e in p.get('evidence', []) if 'path' in e}
        if relative not in allowed:
            raise ValueError('This file is not a declared evidence artifact')
        path = (self.root / relative).resolve()
        if not path.is_relative_to(self.root) or not path.is_file() or path.suffix.lower() not in ('.md', '.json', '.txt'):
            raise ValueError('Evidence file is unavailable')
        with path.open('rb') as stream:
            body = stream.read(2_000_001)
        if len(body) > 2_000_000:
            body = body[:2_000_000] + b'\n[Preview truncated; original file preserved.]\n'
        return body


def activity(project):
    try:
        with readonly_db(Path(project) / 'coordination/messages.sqlite3') as db:
            rows = db.execute('SELECT id,created_utc,sender,kind,feature,payload FROM messages ORDER BY id DESC LIMIT 18')
            return [dict(id=r[0], time=r[1], sender=r[2], kind=r[3], feature=r[4], body=str(json.loads(r[5]).get('body', ''))[:1200]) for r in rows]
    except (OSError, sqlite3.Error, ValueError):
        return []


def observed_usage(project, home=None):
    home = Path(home or Path.home())
    result = dict(total_tokens=0, input_tokens=0, output_tokens=0, cached_tokens=0, sessions=[], note='Reported project sessions; quota and billing are separate.')
    seen = set()
    for path in sorted(home.joinpath('.codex').glob('state*.sqlite'), reverse=True):
        try:
            with readonly_db(path) as db:
                rows = db.execute('SELECT id,model,tokens_used,updated_at,rollout_path,cwd FROM threads ORDER BY updated_at DESC LIMIT 1000').fetchall()
            for ident, model, tokens, updated, rollout, cwd in rows:
                if not isinstance(cwd, str) or not Path(cwd).is_relative_to(Path(project).resolve()) or ident in seen:
                    continue
                seen.add(ident)
                usage = {}
                try:
                    with Path(rollout).open('rb') as stream:
                        stream.seek(max(0, Path(rollout).stat().st_size - 262144))
                        for line in stream:
                            try:
                                item = json.loads(line)
                                payload = item.get('payload', {})
                                if item.get('type') == 'event_msg' and payload.get('type') == 'token_count':
                                    usage = payload.get('info', {}).get('total_token_usage', {})
                            except (ValueError, AttributeError):
                                continue
                except (OSError, TypeError):
                    pass
                total = int(usage.get('total_tokens', tokens or 0))
                entry = dict(id=ident, model=model or 'Codex', provider='Codex', total_tokens=total, input_tokens=int(usage.get('input_tokens', 0)), output_tokens=int(usage.get('output_tokens', 0)), cached_tokens=int(usage.get('cached_input_tokens', 0)), updated_at=updated)
                result['sessions'].append(entry)
        except (sqlite3.Error, OSError, ValueError, TypeError):
            continue
    try:
        with readonly_db(home / '.local/share/opencode/opencode.db') as db:
            rows = db.execute('SELECT id,model,tokens_input,tokens_output,tokens_cache_read,time_updated,directory FROM session_v2').fetchall()
        for ident, model, inp, out, cached, updated, cwd in rows:
            if not isinstance(cwd, str) or not Path(cwd).is_relative_to(Path(project).resolve()):
                continue
            try:
                parsed = json.loads(model) if model else {}
            except ValueError:
                continue
            if not isinstance(parsed, dict):
                continue
            result['sessions'].append(dict(id=ident, model=parsed.get('id', 'OpenCode'), provider='OpenCode', total_tokens=(inp or 0) + (out or 0), input_tokens=inp or 0, output_tokens=out or 0, cached_tokens=cached or 0, updated_at=updated / 1000))
    except (sqlite3.Error, OSError, ValueError, TypeError):
        pass
    for field in ('total_tokens', 'input_tokens', 'output_tokens', 'cached_tokens'):
        result[field] = sum(x[field] for x in result['sessions'])
    result['sessions'].sort(key=lambda x: x['updated_at'], reverse=True)
    result['sessions'] = result['sessions'][:30]
    return result
