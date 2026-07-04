#!/usr/bin/env python3
"""Unit + end-to-end tests for auth_proxy.py's two-tier credential routing.

Run with: python3 -m unittest docker.containers.bifrost-server.test_auth_proxy -v
Or from this directory: python3 -m unittest test_auth_proxy -v

No third-party dependencies (stdlib unittest only), matching auth_proxy.py itself.
"""
import http.client
import importlib
import json
import os
import sys
import threading
import time
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


_RELEVANT_ENV_KEYS = (
    "ANTHROPIC_OAUTH_VALUES",
    "ANTHROPIC_APIKEY_POOL_VALUES",
    "ANTHROPIC_EFFECTIVE_KEY",
    "ANTHROPIC_EFFECTIVE_KEY_TYPE",
)


def _reload_auth_proxy(env):
    """Set the given env (clearing any other auth_proxy-relevant vars first) and reload the
    module so its module-level `pool` picks up the new values. Env is left applied — tests build
    fresh CredentialPool() instances afterward, which also read from the live environment."""
    for key in _RELEVANT_ENV_KEYS:
        os.environ.pop(key, None)
    os.environ.update(env)
    if "auth_proxy" in sys.modules:
        module = importlib.reload(sys.modules["auth_proxy"])
    else:
        module = importlib.import_module("auth_proxy")
    return module


class TestClassifyTier(unittest.TestCase):
    def setUp(self):
        self.ap = _reload_auth_proxy({
            "ANTHROPIC_OAUTH_VALUES": "oauth-1\noauth-2",
            "ANTHROPIC_APIKEY_POOL_VALUES": "apikey-1\napikey-2\napikey-3",
        })
        self.pool = self.ap.CredentialPool()

    def test_oauth_value_classified_as_oauth(self):
        self.assertEqual(self.pool.classify_tier("oauth-1"), "oauth")
        self.assertEqual(self.pool.classify_tier("oauth-2"), "oauth")

    def test_apikey_value_classified_as_apikey(self):
        self.assertEqual(self.pool.classify_tier("apikey-2"), "apikey")

    def test_unknown_value_classified_as_effective(self):
        self.assertEqual(self.pool.classify_tier("sk-ant-something-else"), "effective")

    def test_empty_pools_classify_everything_as_effective(self):
        ap = _reload_auth_proxy({})
        pool = ap.CredentialPool()
        self.assertEqual(pool.classify_tier("anything"), "effective")


class TestOAuthSelection(unittest.TestCase):
    def setUp(self):
        self.ap = _reload_auth_proxy({
            "ANTHROPIC_OAUTH_VALUES": "oauth-1\noauth-2\noauth-3",
            "ANTHROPIC_APIKEY_POOL_VALUES": "apikey-1\napikey-2",
        })
        self.pool = self.ap.CredentialPool()

    def test_picks_first_healthy_in_order(self):
        self.assertEqual(self.pool.select_credential_for_tier("oauth"), "oauth-1")

    def test_excludes_given_credentials(self):
        picked = self.pool.select_credential_for_tier("oauth", exclude={"oauth-1"})
        self.assertEqual(picked, "oauth-2")

    def test_skips_unhealthy_credentials(self):
        self.pool.mark_unhealthy("oauth-1", 429)
        picked = self.pool.select_credential_for_tier("oauth")
        self.assertEqual(picked, "oauth-2")

    def test_returns_none_when_all_oauth_exhausted(self):
        for cred in ("oauth-1", "oauth-2", "oauth-3"):
            self.pool.mark_unhealthy(cred, 401)
        self.assertIsNone(self.pool.select_credential_for_tier("oauth"))

    def test_oauth_selection_ignores_body_hash(self):
        # OAuth tier is not sticky — same first-healthy pick regardless of body content.
        pick_a = self.pool.select_credential_for_tier("oauth", body=b'{"system": "A"}')
        pick_b = self.pool.select_credential_for_tier("oauth", body=b'{"system": "totally different"}')
        self.assertEqual(pick_a, pick_b)


class TestApikeyStickySelection(unittest.TestCase):
    def setUp(self):
        self.ap = _reload_auth_proxy({
            "ANTHROPIC_APIKEY_POOL_VALUES": "apikey-1\napikey-2\napikey-3\napikey-4\napikey-5",
        })
        self.pool = self.ap.CredentialPool()

    def test_same_body_always_selects_same_key(self):
        body = b'{"system": "you are a coding assistant", "messages": []}'
        picks = {self.pool.select_credential_for_tier("apikey", body) for _ in range(50)}
        self.assertEqual(len(picks), 1, f"sticky selection must be stable, got {picks}")

    def test_prefers_system_field_over_full_body(self):
        # Two requests with the same `system` but different `messages` must hash identically —
        # this is what keeps a multi-turn coding session pinned to one API key for cache reuse.
        body1 = b'{"system": "same context", "messages": [{"role": "user", "content": "turn 1"}]}'
        body2 = b'{"system": "same context", "messages": [{"role": "user", "content": "turn 2 is longer"}]}'
        self.assertEqual(
            self.pool.select_credential_for_tier("apikey", body1),
            self.pool.select_credential_for_tier("apikey", body2),
        )

    def test_different_system_prompts_can_select_different_keys(self):
        # Not a strict guarantee (hash collisions are possible with only 5 buckets), but with
        # enough distinct inputs we should see more than one bucket used.
        picks = set()
        for i in range(20):
            body = json.dumps({"system": f"distinct context #{i}"}).encode()
            picks.add(self.pool.select_credential_for_tier("apikey", body))
        self.assertGreater(len(picks), 1, "expected sticky hash to spread across multiple keys")

    def test_no_body_falls_back_to_first_healthy(self):
        self.assertEqual(self.pool.select_credential_for_tier("apikey"), "apikey-1")

    def test_unhealthy_key_excluded_from_sticky_pick(self):
        body = b'{"system": "pin me"}'
        original_pick = self.pool.select_credential_for_tier("apikey", body)
        self.pool.mark_unhealthy(original_pick, 529)
        retry_pick = self.pool.select_credential_for_tier("apikey", body)
        self.assertNotEqual(retry_pick, original_pick)

    def test_returns_none_when_all_apikeys_exhausted(self):
        for i in range(1, 6):
            self.pool.mark_unhealthy(f"apikey-{i}", 401)
        self.assertIsNone(self.pool.select_credential_for_tier("apikey", b'{"system": "x"}'))


class TestCircuitBreakerCooldowns(unittest.TestCase):
    def setUp(self):
        self.ap = _reload_auth_proxy({"ANTHROPIC_APIKEY_POOL_VALUES": "apikey-1\napikey-2"})
        self.pool = self.ap.CredentialPool()

    def test_401_uses_long_cooldown(self):
        with mock.patch.object(self.ap.time, "time", return_value=1_000_000.0):
            self.pool.mark_unhealthy("apikey-1", 401)
        self.assertEqual(
            self.pool.unhealthy["apikey-1"], 1_000_000.0 + self.ap.CIRCUIT_BREAKER_COOLDOWN_401
        )

    def test_429_uses_short_cooldown(self):
        with mock.patch.object(self.ap.time, "time", return_value=1_000_000.0):
            self.pool.mark_unhealthy("apikey-1", 429)
        self.assertEqual(
            self.pool.unhealthy["apikey-1"], 1_000_000.0 + self.ap.CIRCUIT_BREAKER_COOLDOWN_429
        )

    def test_529_uses_short_cooldown(self):
        with mock.patch.object(self.ap.time, "time", return_value=1_000_000.0):
            self.pool.mark_unhealthy("apikey-1", 529)
        self.assertEqual(
            self.pool.unhealthy["apikey-1"], 1_000_000.0 + self.ap.CIRCUIT_BREAKER_COOLDOWN_529
        )

    def test_non_breaker_status_is_ignored(self):
        self.pool.mark_unhealthy("apikey-1", 500)
        self.assertNotIn("apikey-1", self.pool.unhealthy)

    def test_credential_recovers_after_cooldown_expires(self):
        with mock.patch.object(self.ap.time, "time", return_value=1_000_000.0):
            self.pool.mark_unhealthy("apikey-1", 429)
        # Still within cooldown window.
        with mock.patch.object(self.ap.time, "time", return_value=1_000_000.0 + 10):
            self.assertTrue(self.pool._is_unhealthy("apikey-1"))
        # Past cooldown window — should recover and be pruned from the unhealthy map.
        with mock.patch.object(self.ap.time, "time", return_value=1_000_000.0 + 61):
            self.assertFalse(self.pool._is_unhealthy("apikey-1"))
        self.assertNotIn("apikey-1", self.pool.unhealthy)


class TestEffectiveLegacyTier(unittest.TestCase):
    def test_effective_reads_current_env_value(self):
        ap = _reload_auth_proxy({})
        pool = ap.CredentialPool()
        os.environ["ANTHROPIC_EFFECTIVE_KEY"] = "sk-ant-legacy-key"
        try:
            self.assertEqual(pool.select_credential_for_tier("effective"), "sk-ant-legacy-key")
        finally:
            del os.environ["ANTHROPIC_EFFECTIVE_KEY"]

    def test_effective_returns_none_when_unset(self):
        ap = _reload_auth_proxy({})
        pool = ap.CredentialPool()
        os.environ.pop("ANTHROPIC_EFFECTIVE_KEY", None)
        self.assertIsNone(pool.select_credential_for_tier("effective"))


class TestEndToEndRequestFlow(unittest.TestCase):
    """Spins the real ThreadedHTTPServer and drives it through http.client, with
    http.client.HTTPSConnection (the call to api.anthropic.com) mocked out."""

    def setUp(self):
        self.ap = _reload_auth_proxy({
            "ANTHROPIC_OAUTH_VALUES": "oauth-1\noauth-2",
            "ANTHROPIC_APIKEY_POOL_VALUES": "apikey-1\napikey-2",
        })
        self.server = self.ap.ThreadedHTTPServer(("127.0.0.1", 0), self.ap.BearerAuthProxy)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

    def _send(self, x_api_key, body=b'{"messages": []}'):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request("POST", "/v1/messages", body=body, headers={
            "x-api-key": x_api_key,
            "Content-Type": "application/json",
        })
        resp = conn.getresponse()
        data = resp.read()
        conn.close()
        return resp, data

    def _mock_upstream(self, responses):
        """responses: list of (status, headers_dict, body_bytes) consumed in order per call."""
        calls = []
        state = {"i": 0}

        def fake_https_connection(host, context=None, timeout=None):
            mock_conn = mock.Mock()

            def fake_request(method, path, body=None, headers=None):
                calls.append({"headers": dict(headers or {}), "body": body})

            def fake_getresponse():
                idx = min(state["i"], len(responses) - 1)
                status, headers, body = responses[idx]
                state["i"] += 1
                resp = mock.Mock()
                resp.status = status
                resp.getheaders.return_value = list(headers.items())
                _remaining = [body]

                def fake_read(n=None):
                    chunk = _remaining[0]
                    _remaining[0] = b""
                    return chunk

                resp.read.side_effect = fake_read
                return resp

            mock_conn.request.side_effect = fake_request
            mock_conn.getresponse.side_effect = fake_getresponse
            mock_conn.close.return_value = None
            return mock_conn

        return calls, mock.patch.object(self.ap.http.client, "HTTPSConnection", side_effect=fake_https_connection)

    def test_oauth_success_sends_bearer_header(self):
        calls, patcher = self._mock_upstream([(200, {"Content-Length": "2"}, b"ok")])
        with patcher:
            resp, data = self._send("oauth-1")
        self.assertEqual(resp.status, 200)
        self.assertEqual(data, b"ok")
        self.assertIn("Authorization", calls[0]["headers"])
        self.assertEqual(calls[0]["headers"]["Authorization"], "Bearer oauth-1")
        self.assertNotIn("x-api-key", {k.lower() for k in calls[0]["headers"]})

    def test_apikey_success_sends_x_api_key_header(self):
        # Sticky selection re-derives the credential from the request body hash rather than
        # trusting which specific pool member bifrost forwarded — so the exact key picked can
        # differ from "apikey-1", but it must still be a real pool member sent as x-api-key.
        calls, patcher = self._mock_upstream([(200, {"Content-Length": "2"}, b"ok")])
        with patcher:
            resp, data = self._send("apikey-1")
        self.assertEqual(resp.status, 200)
        self.assertIn(calls[0]["headers"].get("x-api-key"), ("apikey-1", "apikey-2"))
        self.assertNotIn("Authorization", calls[0]["headers"])

    def test_oauth_429_retries_next_oauth_credential(self):
        calls, patcher = self._mock_upstream([
            (429, {"Content-Length": "0"}, b""),
            (200, {"Content-Length": "2"}, b"ok"),
        ])
        with patcher:
            resp, data = self._send("oauth-1")
        self.assertEqual(resp.status, 200)
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0]["headers"]["Authorization"], "Bearer oauth-1")
        self.assertEqual(calls[1]["headers"]["Authorization"], "Bearer oauth-2")

    def test_oauth_full_exhaustion_falls_back_to_apikey_pool(self):
        calls, patcher = self._mock_upstream([
            (401, {"Content-Length": "0"}, b""),  # oauth-1 fails
            (401, {"Content-Length": "0"}, b""),  # oauth-2 fails
            (200, {"Content-Length": "2"}, b"ok"),  # falls into apikey pool -> succeeds
        ])
        with patcher:
            resp, data = self._send("oauth-1")
        self.assertEqual(resp.status, 200)
        self.assertEqual(len(calls), 3)
        # First two attempts are Bearer (OAuth), the fallback attempt must be x-api-key, not Bearer.
        self.assertIn("Authorization", calls[0]["headers"])
        self.assertIn("Authorization", calls[1]["headers"])
        self.assertNotIn("Authorization", calls[2]["headers"])
        self.assertIn(calls[2]["headers"].get("x-api-key"), ("apikey-1", "apikey-2"))

    def test_tier2_apikey_never_falls_back_to_oauth_pool(self):
        """Compliance test: Tier 2 handler must never select OAuth credentials.

        Anthropic ToS forbids OAuth/subscription credentials for autonomous/agentic workloads.
        When Tier 2 (API-key) is exhausted, it returns 503 — it never falls back to Tier 1 (OAuth).
        """
        calls, patcher = self._mock_upstream([
            (429, {"Content-Length": "0"}, b""),  # apikey-1 fails
            (429, {"Content-Length": "0"}, b""),  # apikey-2 fails
            # All Tier 2 credentials exhausted; no fallback to OAuth is permitted.
        ])
        with patcher:
            resp, data = self._send("apikey-1")
        # Should exhaust Tier 2 and return 503, not attempt fallback to Tier 1 (OAuth).
        self.assertEqual(resp.status, 503)
        # Verify that no calls used Bearer auth (OAuth) — all attempted keys must have been x-api-key.
        for call in calls:
            self.assertNotIn("Authorization", call["headers"], "Tier 2 must never use Bearer/OAuth headers")
            self.assertIn("x-api-key", call["headers"], "Tier 2 must always use x-api-key headers")

    def test_all_credentials_exhausted_returns_503(self):
        calls, patcher = self._mock_upstream([(429, {"Content-Length": "0"}, b"")] * 10)
        with patcher:
            resp, data = self._send("apikey-1")
        self.assertEqual(resp.status, 503)

    def test_unknown_key_uses_effective_legacy_path(self):
        os.environ["ANTHROPIC_EFFECTIVE_KEY"] = "sk-ant-legacy"
        os.environ["ANTHROPIC_EFFECTIVE_KEY_TYPE"] = "apikey"
        try:
            calls, patcher = self._mock_upstream([(200, {"Content-Length": "2"}, b"ok")])
            with patcher:
                resp, data = self._send("some-unrecognized-key")
            self.assertEqual(resp.status, 200)
            self.assertEqual(calls[0]["headers"].get("x-api-key"), "sk-ant-legacy")
            self.assertNotIn("Authorization", calls[0]["headers"])
        finally:
            os.environ.pop("ANTHROPIC_EFFECTIVE_KEY", None)
            os.environ.pop("ANTHROPIC_EFFECTIVE_KEY_TYPE", None)


if __name__ == "__main__":
    unittest.main(verbosity=2)
