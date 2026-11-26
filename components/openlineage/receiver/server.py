#!/usr/bin/env python3
"""最小 OpenLineage 接收端：把事件追加到 data/events.jsonl，便于观察结构。"""
import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)
EVENTS_FILE = DATA_DIR / "events.jsonl"
PORT = int(os.environ.get("PORT", "15000"))


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"status": "ok"})
        elif self.path == "/api/v1/events":
            count = sum(1 for _ in EVENTS_FILE.open(encoding="utf-8")) if EVENTS_FILE.exists() else 0
            self._send(200, {"count": count})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/api/v1/lineage":
            self._send(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        try:
            event = json.loads(raw)
        except json.JSONDecodeError as exc:
            self._send(400, {"error": f"invalid json: {exc}"})
            return

        record = {
            "received_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "event": event,
        }
        with EVENTS_FILE.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")

        job = event.get("job", {})
        print(f"[receiver] {event.get('eventType')} {job.get('namespace')}.{job.get('name')}", flush=True)
        self._send(201, {"status": "ok"})

    def log_message(self, fmt, *args):
        return  # 静默访问日志，输出只看事件


if __name__ == "__main__":
    print(f"[receiver] listening on http://localhost:{PORT}", flush=True)
    print(f"[receiver] events -> {EVENTS_FILE}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
