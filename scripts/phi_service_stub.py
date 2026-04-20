#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class Handler(BaseHTTPRequestHandler):
    service = "service"
    label = "Service"
    port = 0
    root = Path(".")

    def _payload(self) -> dict[str, object]:
        summary_path = self.root / "dist" / "command_core" / "summary.txt"
        return {
            "service": self.service,
            "label": self.label,
            "status": "ok",
            "port": self.port,
            "timestamp": utc_now(),
            "command_core_summary_present": summary_path.exists(),
        }

    def _send_json(self, code: int, payload: dict[str, object]) -> None:
        body = (json.dumps(payload, indent=2) + "\n").encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_text(self, code: int, body: str, content_type: str = "text/plain; charset=utf-8") -> None:
        data = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/" or self.path == "":
            self._send_text(
                200,
                f"{self.label} ready on port {self.port}\nhealth: /health\n",
            )
            return

        if self.path.startswith("/health") or self.path in {"/ready", "/healthz", "/version", "/status"}:
            self._send_json(200, self._payload())
            return

        if self.path == "/metrics":
            self._send_text(
                200,
                f'phi_service_up{{service="{self.service}",port="{self.port}"}} 1\n',
                "text/plain; version=0.0.4; charset=utf-8",
            )
            return

        if self.path == "/demo":
            self._send_text(
                200,
                f"<html><body><h1>{self.label}</h1><p>Demo bridge active.</p></body></html>\n",
                "text/html; charset=utf-8",
            )
            return

        self._send_json(404, {"service": self.service, "status": "not_found", "path": self.path})

    def log_message(self, fmt: str, *args: object) -> None:
        return


def main() -> int:
    parser = argparse.ArgumentParser(description="Lightweight PHI service stub")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--root", default=".")
    args = parser.parse_args()

    root = Path(args.root).resolve()

    class ConfiguredHandler(Handler):
        pass

    ConfiguredHandler.service = args.service
    ConfiguredHandler.label = args.label
    ConfiguredHandler.port = args.port
    ConfiguredHandler.root = root

    server = ThreadingHTTPServer(("127.0.0.1", args.port), ConfiguredHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
