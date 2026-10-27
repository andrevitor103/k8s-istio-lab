#!/usr/bin/env python3
"""Vitrine. Chama o catálogo pela URL em CATALOG_URL e devolve versão e latência."""

import json
import os
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

CATALOG_URL = os.environ.get(
    "CATALOG_URL", "http://catalog.lab.svc.cluster.local:8080"
).rstrip("/")
PORT = int(os.environ.get("PORT", "8080"))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[storefront] {fmt % args}", flush=True)

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send(200, {"status": "ok"})
            return
        if parsed.path not in {"/", "/item"}:
            self._send(404, {"error": "not found"})
            return

        query = parse_qs(parsed.query)
        delay = query.get("delay_ms", ["0"])[0]
        fail = query.get("fail", ["0"])[0]
        url = f"{CATALOG_URL}/items/1?delay_ms={delay}&fail={fail}"
        request = urllib.request.Request(url)
        if delay not in {"", "0"}:
            request.add_header("x-delay-ms", delay)
        if fail in {"1", "true"}:
            request.add_header("x-fail", "1")

        started = time.perf_counter()
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                catalog = json.loads(response.read().decode())
                status = response.status
        except urllib.error.HTTPError as error:
            elapsed = round((time.perf_counter() - started) * 1000, 1)
            self._send(
                error.code,
                {
                    "storefront": "error",
                    "catalog_status": error.code,
                    "latency_ms": elapsed,
                    "body": error.read().decode(),
                },
            )
            return
        except Exception as error:  # noqa: BLE001 — o lab precisa ver a falha crua
            elapsed = round((time.perf_counter() - started) * 1000, 1)
            self._send(
                502,
                {
                    "storefront": "error",
                    "latency_ms": elapsed,
                    "error": str(error),
                },
            )
            return

        elapsed = round((time.perf_counter() - started) * 1000, 1)
        self._send(
            status,
            {
                "storefront": "ok",
                "latency_ms": elapsed,
                "catalog": catalog,
            },
        )


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"storefront na porta {PORT} catalog={CATALOG_URL}", flush=True)
    server.serve_forever()
