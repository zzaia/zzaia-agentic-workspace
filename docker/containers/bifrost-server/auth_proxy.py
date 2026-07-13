#!/usr/bin/env python3
"""Auth proxy: two-tier credential routing (OAuth vs API-key) with circuit breaker.

Tier 1 (OAuth): Claude Code CLI/VSCode, can fall back to API-key pool on exhaustion.
Tier 2 (API-key): Autonomous agents, strictly confined to API-key pool (compliance: Anthropic ToS forbids OAuth for agentic workloads).
"""
import http.server
import http.client
import ssl
import os
import sys
import threading
import json
import hashlib
import time
from typing import Optional, Set

PORT = 8099
CIRCUIT_BREAKER_COOLDOWN_401 = 3600
CIRCUIT_BREAKER_COOLDOWN_429 = 60
CIRCUIT_BREAKER_COOLDOWN_529 = 60


def _log_tier(event: str, context: dict):
    """Emit structured log line for tier routing events (tier=1|2, event, context)."""
    ctx_str = " ".join(f"{k}={v}" for k, v in context.items()) if context else ""
    msg = f"[auth-proxy] {event}" + (f" {ctx_str}" if ctx_str else "")
    print(msg, file=sys.stderr)


class CredentialPool:
    def __init__(self):
        self.oauth_values: Set[str] = set()
        self.oauth_list = []
        self.apikey_values: Set[str] = set()
        self.apikey_list = []
        self.unhealthy = {}
        self.lock = threading.Lock()
        self._load_from_env()

    def _load_from_env(self):
        oauth_str = os.environ.get("ANTHROPIC_OAUTH_VALUES", "").strip()
        if oauth_str:
            self.oauth_list = [v.strip() for v in oauth_str.split('\n') if v.strip()]
            self.oauth_values = set(self.oauth_list)

        apikey_str = os.environ.get("ANTHROPIC_APIKEY_POOL_VALUES", "").strip()
        if apikey_str:
            self.apikey_list = [v.strip() for v in apikey_str.split('\n') if v.strip()]
            self.apikey_values = set(self.apikey_list)

    def classify_tier(self, incoming_key: str) -> str:
        """Classify incoming key as 'oauth', 'apikey', or 'effective'."""
        if incoming_key in self.oauth_values:
            return "oauth"
        if incoming_key in self.apikey_values:
            return "apikey"
        return "effective"

    def select_credential_for_tier(self, tier: str, body: Optional[bytes] = None, exclude: Optional[Set[str]] = None) -> Optional[str]:
        """Select a healthy credential from the given tier, optionally excluding some values."""
        if exclude is None:
            exclude = set()

        with self.lock:
            if tier == "oauth":
                healthy = [k for k in self.oauth_list if k not in exclude and not self._is_unhealthy(k)]
                return healthy[0] if healthy else None

            if tier == "apikey":
                healthy = [k for k in self.apikey_list if k not in exclude and not self._is_unhealthy(k)]
                if not healthy:
                    return None
                if body:
                    hash_val = self._hash_body(body)
                    return healthy[hash_val % len(healthy)]
                return healthy[0]

            if tier == "effective":
                eff_key = os.environ.get("ANTHROPIC_EFFECTIVE_KEY", "").strip()
                if eff_key and eff_key not in exclude:
                    return eff_key
                return None

            return None

    def mark_unhealthy(self, cred: str, status_code: int):
        """Mark a credential as unhealthy for a cooldown period."""
        if status_code == 401:
            cooldown = CIRCUIT_BREAKER_COOLDOWN_401
        elif status_code in (429, 529):
            cooldown = CIRCUIT_BREAKER_COOLDOWN_429 if status_code == 429 else CIRCUIT_BREAKER_COOLDOWN_529
        else:
            return
        with self.lock:
            self.unhealthy[cred] = time.time() + cooldown

    def _is_unhealthy(self, cred: str) -> bool:
        """Check if a credential is currently in the unhealthy cooldown window."""
        if cred not in self.unhealthy:
            return False
        if time.time() > self.unhealthy[cred]:
            del self.unhealthy[cred]
            return False
        return True

    def _hash_body(self, body: bytes) -> int:
        """Hash the request body (preferring 'system' field) for sticky selection."""
        try:
            data = json.loads(body.decode('utf-8', errors='ignore'))
            if isinstance(data, dict) and 'system' in data:
                hash_input = str(data['system']).encode('utf-8')
            else:
                hash_input = body[:4096]
        except Exception:
            hash_input = body[:4096]
        return int(hashlib.md5(hash_input).hexdigest(), 16)


pool = CredentialPool()


class BearerAuthProxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def do_request(self):
        """Dispatch to appropriate tier handler based on credential classification."""
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        incoming_key = self.headers.get("x-api-key", "").strip() or ""
        if not incoming_key and "authorization" in self.headers:
            auth_header = self.headers.get("authorization", "").strip()
            if auth_header.lower().startswith("bearer "):
                incoming_key = auth_header[7:]

        tier = pool.classify_tier(incoming_key) if incoming_key else "effective"

        if tier == "oauth":
            self.handle_tier1_oauth(body)
        elif tier == "apikey":
            self.handle_tier2_apikey(body)
        else:  # "effective" (legacy single-key mode or two-tier without incoming key)
            # In two-tier mode, if no incoming key is provided, default to Tier-1 (OAuth with fallback to API-key)
            # This handles cases where Bifrost forwards requests without client auth headers
            if pool.oauth_values or pool.apikey_values:
                # Two-tier mode detected: use Tier-1 handler (which has fallback to Tier-2)
                self.handle_tier1_oauth(body)
            else:
                # Single-key mode: use the configured effective key type
                effective_is_oauth = os.environ.get("ANTHROPIC_EFFECTIVE_KEY_TYPE", "") == "oauth"
                if effective_is_oauth:
                    self.handle_tier1_oauth(body)
                else:
                    self._handle_effective_apikey(body)

    def handle_tier1_oauth(self, body: Optional[bytes]):
        """Tier 1 handler: OAuth pool with fallback to shared Tier-2 API-key pool.

        ToS: OAuth/subscription (Claude Pro/Max) credentials are for interactive use.
        Fallback to API-key pool is allowed for interactive Claude Code CLI/VSCode extension.
        """
        exhausted = set()
        max_retries = 10

        for attempt in range(max_retries):
            selected_cred = pool.select_credential_for_tier("oauth", body, exclude=exhausted)
            if selected_cred:
                actual_tier = "oauth"
            else:
                # Tier-1 fallback: shared Tier-2 API-key pool (allowed for interactive use).
                selected_cred = pool.select_credential_for_tier("apikey", body, exclude=exhausted)
                if selected_cred:
                    actual_tier = "apikey"
                    _log_tier(
                        "tier=1 event=fallback_to_apikey_pool",
                        {"attempt": attempt + 1, "reason": "oauth_pool_exhausted"}
                    )
                else:
                    self._error_response(503, "No healthy credentials available for tier: oauth")
                    _log_tier("tier=1 event=exhausted", {"attempt": attempt + 1})
                    return

            resp = self._proxy_request(selected_cred, actual_tier, body)
            if resp is None:
                return

            status_code = resp.status if resp else 0

            if status_code in (401, 429, 529):
                pool.mark_unhealthy(selected_cred, status_code)
                exhausted.add(selected_cred)
                _log_tier(
                    f"tier=1 event=circuit_breaker status={status_code}",
                    {"credential_tier": actual_tier, "cooldown_sec": CIRCUIT_BREAKER_COOLDOWN_401 if status_code == 401 else CIRCUIT_BREAKER_COOLDOWN_429}
                )
                continue

            self._send_response(resp, body)
            _log_tier("tier=1 event=success", {"attempt": attempt + 1})
            return

        self._error_response(503, "All credentials exhausted after retries")
        _log_tier("tier=1 event=max_retries_exceeded", {})

    def handle_tier2_apikey(self, body: Optional[bytes]):
        """Tier 2 handler: API-key pool only (NO fallback to OAuth pool).

        Compliance: Anthropic ToS forbids OAuth/subscription credentials for autonomous/agentic workloads.
        This handler is structurally confined to apikey_list and never references oauth_list.
        Sticky selection via request-body hash preserves prompt-cache coherence per key.
        """
        exhausted = set()
        max_retries = 10

        for attempt in range(max_retries):
            selected_cred = pool.select_credential_for_tier("apikey", body, exclude=exhausted)
            if not selected_cred:
                self._error_response(503, "No healthy credentials available for tier: apikey")
                _log_tier("tier=2 event=exhausted", {"attempt": attempt + 1})
                return

            resp = self._proxy_request(selected_cred, "apikey", body)
            if resp is None:
                return

            status_code = resp.status if resp else 0

            if status_code in (401, 429, 529):
                pool.mark_unhealthy(selected_cred, status_code)
                exhausted.add(selected_cred)
                _log_tier(
                    f"tier=2 event=circuit_breaker status={status_code}",
                    {"cooldown_sec": CIRCUIT_BREAKER_COOLDOWN_401 if status_code == 401 else CIRCUIT_BREAKER_COOLDOWN_429}
                )
                continue

            self._send_response(resp, body)
            _log_tier("tier=2 event=success", {"attempt": attempt + 1})
            return

        self._error_response(503, "All credentials exhausted after retries")
        _log_tier("tier=2 event=max_retries_exceeded", {})

    def _handle_effective_apikey(self, body: Optional[bytes]):
        """Handle legacy single-key mode when ANTHROPIC_EFFECTIVE_KEY_TYPE is 'apikey'."""
        selected_cred = pool.select_credential_for_tier("effective", body)
        if not selected_cred:
            self._error_response(503, "No Anthropic credentials available")
            _log_tier("tier=1 event=exhausted", {})
            return

        resp = self._proxy_request(selected_cred, "effective", body)
        if resp is None:
            return

        self._send_response(resp, body)
        _log_tier("tier=1 event=success", {"mode": "effective_apikey"})

    def _proxy_request(self, cred: str, tier: str, body: Optional[bytes]) -> Optional[object]:
        """Forward request to Anthropic with the given credential. Returns response object or None on exception."""
        headers = {}
        for k, v in self.headers.items():
            if k.lower() in ("x-api-key", "authorization", "host", "content-length"):
                continue
            headers[k] = v

        effective_is_oauth = os.environ.get("ANTHROPIC_EFFECTIVE_KEY_TYPE", "") == "oauth"
        if tier == "oauth" or (tier == "effective" and effective_is_oauth):
            headers["Authorization"] = f"Bearer {cred}"
        else:
            headers["x-api-key"] = cred

        if body:
            headers["Content-Length"] = str(len(body))

        ssl_ctx = ssl.create_default_context()
        try:
            conn = http.client.HTTPSConnection("api.anthropic.com", context=ssl_ctx, timeout=300)
            conn.request(self.command, self.path, body=body, headers=headers)
            return conn.getresponse()
        except Exception as e:
            try:
                self._error_response(502, str(e))
            except Exception:
                pass
            return None

    def _send_response(self, resp, body: Optional[bytes]):
        """Send the Anthropic response back to the client."""
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

    def _error_response(self, status: int, message: str):
        try:
            self.send_response(status)
            error = f'{{"error": "{message}"}}'.encode()
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
    has_creds = bool(pool.oauth_values or pool.apikey_values or os.environ.get("ANTHROPIC_EFFECTIVE_KEY"))
    if not has_creds:
        print("[auth-proxy] WARN: no Anthropic credentials configured — requests will fail", file=sys.stderr)
    else:
        cred_summary = []
        if pool.oauth_values:
            cred_summary.append(f"Tier1(OAuth): {len(pool.oauth_values)} keys [falls back to Tier2 on exhaustion]")
        if pool.apikey_values:
            cred_summary.append(f"Tier2(API-key): {len(pool.apikey_values)} keys [agentic workloads only, no fallback to Tier1]")
        if os.environ.get("ANTHROPIC_EFFECTIVE_KEY"):
            cred_summary.append("Effective: 1 key (legacy mode)")
        print(f"[auth-proxy] Two-tier routing: {'; '.join(cred_summary)}", file=sys.stderr)

    server = ThreadedHTTPServer(("127.0.0.1", PORT), BearerAuthProxy)
    print(f"[auth-proxy] Listening on 127.0.0.1:{PORT} → two-tier credential proxy with circuit breaker", file=sys.stderr)
    sys.stdout.flush()
    server.serve_forever()
