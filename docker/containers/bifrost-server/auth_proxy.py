#!/usr/bin/env python3
"""Auth proxy: converts x-api-key to Authorization: Bearer for Anthropic OAuth tokens."""
import http.server
import http.client
import ssl
import os
import sys
import threading

ANTHROPIC_EFFECTIVE_KEY = os.environ.get("ANTHROPIC_EFFECTIVE_KEY", "")
PORT = 8099


class BearerAuthProxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def do_request(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        headers = {}
        for k, v in self.headers.items():
            if k.lower() in ("x-api-key", "authorization", "host", "content-length"):
                continue
            headers[k] = v

        if ANTHROPIC_EFFECTIVE_KEY:
            headers["Authorization"] = f"Bearer {ANTHROPIC_EFFECTIVE_KEY}"
        if body:
            headers["Content-Length"] = str(len(body))

        ssl_ctx = ssl.create_default_context()
        try:
            conn = http.client.HTTPSConnection("api.anthropic.com", context=ssl_ctx, timeout=300)
            conn.request(self.command, self.path, body=body, headers=headers)
            resp = conn.getresponse()

            self.send_response(resp.status)
            has_content_length = False
            for k, v in resp.getheaders():
                low = k.lower()
                if low == "transfer-encoding":
                    continue
                if low == "content-length":
                    has_content_length = True
                self.send_header(k, v)

            if not has_content_length:
                self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()

            if has_content_length:
                while True:
                    chunk = resp.read(65536)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
            else:
                while True:
                    chunk = resp.read(65536)
                    if not chunk:
                        self.wfile.write(b"0\r\n\r\n")
                        self.wfile.flush()
                        break
                    size_hex = format(len(chunk), "x").encode()
                    self.wfile.write(size_hex + b"\r\n" + chunk + b"\r\n")
                    self.wfile.flush()
            conn.close()
        except Exception as e:
            try:
                self.send_response(502)
                error = f'{{"error": "{e}"}}'.encode()
                self.send_header("Content-Length", str(len(error)))
                self.end_headers()
                self.wfile.write(error)
            except Exception:
                pass

    do_GET = do_POST = do_PUT = do_DELETE = do_OPTIONS = do_request


class ThreadedHTTPServer(http.server.HTTPServer):
    def process_request(self, request, client_address):
        t = threading.Thread(target=self._handle, args=(request, client_address))
        t.daemon = True
        t.start()

    def _handle(self, request, client_address):
        try:
            self.finish_request(request, client_address)
        except Exception:
            self.handle_error(request, client_address)
        finally:
            self.shutdown_request(request)


if __name__ == "__main__":
    if not ANTHROPIC_EFFECTIVE_KEY:
        print("[auth-proxy] WARN: ANTHROPIC_EFFECTIVE_KEY not set — requests will be unauthenticated", file=sys.stderr)
    server = ThreadedHTTPServer(("127.0.0.1", PORT), BearerAuthProxy)
    print(f"[auth-proxy] Listening on 127.0.0.1:{PORT} → Bearer auth proxy", file=sys.stderr)
    sys.stdout.flush()
    server.serve_forever()
