"""
Keystone Client Core HTTP SDK
Provides high-level programmatic access to Keystone gateway endpoints.
"""

import json
import urllib.request
import urllib.error
from typing import Dict, Any, Optional
from .models import HealthStatus, ParseResult


class KeystoneClient:
    """Client SDK for interacting with Keystone B2B Transaction Mesh."""

    def __init__(self, base_url: str = "http://127.0.0.1:8088", timeout: float = 10.0):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def check_health(self) -> HealthStatus:
        """Queries the /api/v1/health status endpoint."""
        url = f"{self.base_url}/api/v1/health"
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=self.timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return HealthStatus(
                status=data.get("status", "UNKNOWN"),
                version=data.get("version", ""),
                subsystems=data.get("subsystems", {}),
            )

    def parse_document(self, protocol: str, content: str) -> ParseResult:
        """Submits raw payload to /api/v1/parse for AST extraction."""
        url = f"{self.base_url}/api/v1/parse"
        body = json.dumps({"protocol": protocol, "content": content}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json", "Accept": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                return ParseResult(
                    success=data.get("success", False),
                    ast=data.get("ast", {}),
                    errors=data.get("errors", []),
                    warnings=data.get("warnings", []),
                )
        except urllib.error.HTTPError as e:
            err_data = json.loads(e.read().decode("utf-8"))
            return ParseResult(
                success=False,
                ast={},
                errors=[err_data.get("error", str(e))],
            )

    def fetch_metrics(self) -> str:
        """Fetches raw Prometheus exposition metrics."""
        url = f"{self.base_url}/api/v1/metrics"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=self.timeout) as resp:
            return resp.read().decode("utf-8")
