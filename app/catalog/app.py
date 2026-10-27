#!/usr/bin/env python3
"""API do catálogo. A versão vem da env VERSION (v1 ou v2)."""

import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

VERSION = os.environ.get("VERSION", "v1")
PORT = int(os.environ.get("PORT", "8080"))
READY = os.environ.get("READY", "true").lower() in {"1", "true", "yes"}
# Estado só deste processo. Um Pod pode ficar doente sem o Kubernetes tirá-lo do Service.
SICK = False

ITEMS = {
    "1": {"id": "1", "name": "Caderno de laboratório"},
}


def clamp_delay(raw):
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return None
    return max(0, min(value, 10000))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[catalog {VERSION}] {fmt % args}", flush=True)

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        global SICK
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/health":
            self._send(200, {"status": "ok", "version": VERSION})
            return
        if path == "/ready":
            if READY:
                self._send(200, {"status": "ready", "version": VERSION})
            else:
                self._send(503, {"status": "not-ready", "version": VERSION})
            return
        if path == "/admin/sick":
            SICK = True
            self._send(200, {"sick": True, "version": VERSION})
            return
        if path == "/admin/healthy":
            SICK = False
            self._send(200, {"sick": False, "version": VERSION})
            return
        if path.startswith("/items/"):
            item_id = path.removeprefix("/items/")
            item = ITEMS.get(item_id)
            if item is None:
                self._send(404, {"error": "not found"})
                return
            if SICK:
                self._send(503, {"error": "pod sick", "version": VERSION})
                return

            delay = clamp_delay(query.get("delay_ms", ["0"])[0])
            header_delay = self.headers.get("x-delay-ms")
            if header_delay is not None:
                delay = clamp_delay(header_delay)
            if delay is None:
                self._send(400, {"error": "delay_ms inválido"})
                return
            if delay:
                time.sleep(delay / 1000)

            fail = query.get("fail", ["0"])[0] in {"1", "true"} or self.headers.get("x-fail") == "1"
            if fail:
                self._send(503, {"error": "injected failure", "version": VERSION})
                return

            self._send(200, {**item, "version": VERSION})
            return

        self._send(404, {"error": "not found"})


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"catalog {VERSION} na porta {PORT} ready={READY}", flush=True)
    server.serve_forever()
