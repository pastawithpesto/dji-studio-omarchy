#!/usr/bin/env python3
"""Loopback-only DLL research console using the existing local CLI logins."""
import argparse
import datetime
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import selectors
import shutil
import subprocess
import threading
import time
from urllib.parse import parse_qs, urlsplit
from data import Catalog, MODELS, activity, observed_usage, workers
from jobs import Queue, utc


class Usage:
    def __init__(self, project):
        self.project = project
        self.lock = threading.Lock()
        self.data = dict(total_tokens=0, input_tokens=0, output_tokens=0, cached_tokens=0, sessions=[], limits=None, limits_updated_at=None, note='Usage collection is starting.')
        self.closed = False
        threading.Thread(target=self.loop, daemon=True).start()

    def limits(self):
        if not shutil.which('codex'):
            return None, None
        proc = subprocess.Popen(['codex', 'app-server', '--listen', 'stdio://'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, start_new_session=True)
        selector = selectors.DefaultSelector()
        selector.register(proc.stdout, selectors.EVENT_READ)
        def send(value):
            proc.stdin.write(json.dumps(value) + '\n')
            proc.stdin.flush()
        limit, summary = None, None
        try:
            send(dict(id=1, method='initialize', params={'clientInfo': {'name': 'dll_research_console', 'title': 'DLL Research Console', 'version': '0.1.0'}, 'capabilities': {'experimentalApi': True}}))
            deadline = time.monotonic() + 18
            waiting = {1}
            while waiting and time.monotonic() < deadline and proc.poll() is None:
                if not selector.select(0.5):
                    continue
                line = proc.stdout.readline()
                if not line:
                    break
                item = json.loads(line)
                if not isinstance(item, dict):
                    continue
                ident = item.get('id')
                if ident not in waiting:
                    continue
                waiting.remove(ident)
                if ident == 1:
                    if 'error' in item:
                        break
                    send({'method': 'initialized'})
                    send({'id': 2, 'method': 'account/rateLimits/read'})
                    send({'id': 3, 'method': 'account/usage/read'})
                    waiting.update((2, 3))
                elif ident == 2:
                    limit = item.get('result', {}).get('rateLimits')
                elif ident == 3:
                    summary = item.get('result', {}).get('summary')
        except (OSError, ValueError, BrokenPipeError):
            pass
        finally:
            selector.close()
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        return limit, summary

    def loop(self):
        while not self.closed:
            value = observed_usage(self.project)
            try:
                limit, summary = self.limits()
            except (OSError, subprocess.SubprocessError):
                limit, summary = None, None
            value.update(limits=limit, account_summary=summary, limits_updated_at=utc() if limit else None)
            with self.lock:
                self.data = value
            for _ in range(60):
                if self.closed:
                    return
                time.sleep(1)

    def snapshot(self):
        with self.lock:
            return dict(self.data)


class App:
    def __init__(self, project, runtime, launch=True, usage=True):
        self.project = Path(project).resolve()
        self.source = Path(__file__).resolve().parent
        self.catalog = Catalog(self.project, self.source)
        self.queue = Queue(self.project, runtime, self.catalog, launch)
        self.usage = Usage(self.project) if usage else None
        self.csrf = secrets.token_urlsafe(32)

    def state(self):
        pool = workers()
        owned = {job.get('pid') for job in self.queue.snapshot() if job['status'] == 'running'}
        for worker in pool:
            worker['owned'] = worker['pid'] in owned
        models = [dict(id=key, name=value['name'], backend=value['backend'], available=bool(shutil.which('codex' if value['backend'] == 'codex' else 'opencode'))) for key, value in MODELS.items()]
        return dict(csrf=self.csrf, updated_at=utc(), modules=self.catalog.inventory(), models=models,
                    workers=pool, slots={'active': len(pool), 'limit': Queue.LIMIT}, jobs=self.queue.snapshot(),
                    usage=self.usage.snapshot() if self.usage else observed_usage(self.project), activity=activity(self.project))

    def module(self, ident):
        result = self.catalog.module(ident)
        for job in self.queue.snapshot():
            if job['dll'] == ident and job['status'] in ('queued', 'running'):
                for part in result['parts']:
                    if part['id'] in job['parts']:
                        part['owner'] = MODELS[job['model']]['name'] + ' · ' + job['status']
        if ident == 'ThumbnailProvider.dll':
            blocker = self.queue.external_blocker(ident, [dict(id='internals')], 'research')
            if blocker:
                for part in result['parts']:
                    if part.get('owner_feature') == 'thumbnailprovider-kimi-k3':
                        part['owner'] = 'Kimi K3 High · existing assignment'
        return result

    def job_artifact(self, ident, name):
        if ident not in self.queue.jobs or name not in ('FINAL.txt', 'REPORT.md', 'CONTRACT.json', 'REVIEW.md', 'REVIEW.json', 'MANIFEST.json', 'PROGRESS.json'):
            raise ValueError('Unknown public job artifact')
        root = (self.queue.output / ident).resolve()
        path = (root / name).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError('Artifact has not been produced')
        with path.open('rb') as stream:
            return stream.read(2_000_000)


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def setup(self):
        super().setup()
        self.connection.settimeout(10)

    def log_message(self, *_):
        pass

    def local(self):
        port = self.server.server_port
        return self.headers.get('Host') in (f'localhost:{port}', f'127.0.0.1:{port}')

    def reply(self, value, status=200, mime='application/json; charset=utf-8'):
        body = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False).encode()
        self.send_response(status)
        if status >= 400:
            self.close_connection = True
            self.send_header('Connection', 'close')
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'none'")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if not self.local():
            return self.reply({'error': 'Use the localhost console address'}, 403)
        app = self.server.app
        url = urlsplit(self.path)
        query = parse_qs(url.query)
        try:
            if url.path == '/api/state':
                return self.reply(app.state())
            if url.path == '/api/module':
                return self.reply(app.module(query.get('id', [''])[0]))
            if url.path == '/api/artifact':
                return self.reply(app.catalog.artifact(query.get('path', [''])[0]), mime='text/plain; charset=utf-8')
            bits = url.path.strip('/').split('/')
            if len(bits) == 5 and bits[:2] == ['api', 'jobs'] and bits[3] == 'artifact':
                return self.reply(app.job_artifact(bits[2], bits[4]), mime='text/plain; charset=utf-8')
            names = {'/': 'index.html', '/index.html': 'index.html', '/app.js': 'app.js', '/style.css': 'style.css', '/static/style.css': 'style.css', '/static/app.js': 'app.js'}
            if url.path in names:
                path = app.source / 'static' / names[url.path]
                mime = {'.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css'}[path.suffix]
                return self.reply(path.read_bytes(), mime=mime + '; charset=utf-8')
            return self.reply({'error': 'Not found'}, 404)
        except (ValueError, TypeError):
            return self.reply({'error': 'Unknown or unavailable DLL/evidence selection'}, 400)
        except OSError:
            return self.reply({'error': 'Requested local file is unavailable'}, 404)

    def do_POST(self):
        app = self.server.app
        origin = self.headers.get('Origin')
        valid_origins = {f'http://localhost:{self.server.server_port}', f'http://127.0.0.1:{self.server.server_port}'}
        if not self.local() or origin not in valid_origins or not hmac.compare_digest(self.headers.get('X-Console-Token', '').encode(), app.csrf.encode()):
            return self.reply({'error': 'Local origin and console session token are required'}, 403)
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 65536:
                raise ValueError('Request body must be between 1 and 65536 bytes')
            body = json.loads(self.rfile.read(length))
            if not isinstance(body, dict):
                raise ValueError('Expected a JSON task object')
            url = urlsplit(self.path)
            if url.path == '/api/preview':
                return self.reply(app.queue.preview(body)[0])
            if url.path == '/api/jobs':
                return self.reply({'job': app.queue.enqueue(body)}, 201)
            bits = url.path.strip('/').split('/')
            if len(bits) == 4 and bits[:2] == ['api', 'jobs'] and bits[3] in ('pause', 'resume'):
                return self.reply({'job': getattr(app.queue, bits[3])(bits[2])})
            return self.reply({'error': 'Unknown control'}, 404)
        except (ValueError, TypeError):
            return self.reply({'error': 'Invalid task, selection, model or job state'}, 400)
        except (OSError, subprocess.SubprocessError):
            return self.reply({'error': 'Local control could not complete; existing artifacts are preserved'}, 409)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--runtime', type=Path)
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--no-launch', action='store_true', help='Inspect and queue without starting model workers')
    args = parser.parse_args()
    project = args.project.resolve()
    runtime = args.runtime or project / 'reconstruction/dll-console-runtime'
    app = App(project, runtime, launch=not args.no_launch)
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    server.app = app
    print(f'DLL Research Console: http://127.0.0.1:{server.server_port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        app.queue.closed = True
        if app.usage:
            app.usage.closed = True
        server.server_close()


if __name__ == '__main__':
    main()
