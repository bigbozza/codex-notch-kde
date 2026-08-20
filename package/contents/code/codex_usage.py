#!/usr/bin/env python3
"""Fetch the minimum data needed by the Codex Quota Plasma widget."""

from __future__ import annotations

import json
import math
import os
import stat
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any


USAGE_URL = "https://chatgpt.com/backend-api/wham/usage"
RESET_CREDITS_URL = "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
MAX_AUTH_BYTES = 1_048_576
MAX_RESPONSE_BYTES = 2_097_152
PLAN_NAMES = {
    "free": "Free",
    "go": "Go",
    "plus": "Plus",
    "pro": "Pro",
    "prolite": "Pro Lite",
    "business": "Business",
    "enterprise": "Enterprise",
    "edu": "Edu",
}


class WidgetError(Exception):
    def __init__(self, status: str, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


class SameHostHTTPSRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Allow redirects only when HTTPS host and port remain unchanged."""

    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Any,
        newurl: str,
    ) -> urllib.request.Request | None:
        original = urllib.parse.urlsplit(req.full_url)
        redirected = urllib.parse.urlsplit(newurl)
        if redirected.scheme != "https" or redirected.netloc.lower() != original.netloc.lower():
            return None
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def emit(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, separators=(",", ":"), allow_nan=False)
    sys.stdout.write("\n")


def read_credentials() -> tuple[str, str | None]:
    configured_root = os.environ.get("CODEX_HOME")
    codex_root = Path(configured_root).expanduser() if configured_root else Path.home() / ".codex"
    auth_path = codex_root / "auth.json"

    try:
        details = auth_path.stat()
        if not stat.S_ISREG(details.st_mode) or details.st_size > MAX_AUTH_BYTES:
            raise WidgetError("unavailable", "Codex authentication file is invalid")
        raw = auth_path.read_bytes()
    except WidgetError:
        raise
    except (FileNotFoundError, PermissionError, OSError) as error:
        raise WidgetError("sign_in_required", "Sign in with Codex to load quota") from error

    try:
        document = json.loads(raw)
        tokens = document["tokens"]
        access_token = tokens["access_token"]
        account_id = tokens.get("account_id")
        if not isinstance(access_token, str) or not access_token:
            raise ValueError("missing access token")
        if account_id is not None and not isinstance(account_id, str):
            account_id = None
        return access_token, account_id
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise WidgetError("unavailable", "Codex authentication file is invalid") from error


def read_limited_json(response: Any) -> dict[str, Any]:
    raw = response.read(MAX_RESPONSE_BYTES + 1)
    if len(raw) > MAX_RESPONSE_BYTES:
        raise WidgetError("unavailable", "ChatGPT quota response is too large")
    try:
        value = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise WidgetError("unavailable", "ChatGPT returned an invalid quota response") from error
    if not isinstance(value, dict):
        raise WidgetError("unavailable", "ChatGPT returned an invalid quota response")
    return value


def fetch_json(url: str, access_token: str, account_id: str | None, timeout: int) -> dict[str, Any]:
    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {access_token}",
        "User-Agent": "CodexQuotaPlasma/1.0",
    }
    if account_id:
        headers["ChatGPT-Account-Id"] = account_id

    request = urllib.request.Request(url, headers=headers, method="GET")
    opener = urllib.request.build_opener(SameHostHTTPSRedirectHandler())
    try:
        with opener.open(request, timeout=timeout) as response:
            return read_limited_json(response)
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            raise WidgetError("sign_in_required", "Codex sign-in has expired") from error
        raise WidgetError("unavailable", f"ChatGPT quota is unavailable (HTTP {error.code})") from error
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise WidgetError("unavailable", "Could not reach ChatGPT quota service") from error


def finite_number(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    number = float(value)
    return number if math.isfinite(number) else None


def integer(value: Any) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int):
        return None
    return value


def parse_timestamp(value: Any) -> float | None:
    number = finite_number(value)
    if number is not None:
        return number / 1000 if number > 1_000_000_000_000 else number
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return parsed.timestamp()
    except ValueError:
        return None


def normalized_plan(value: Any) -> str:
    if not isinstance(value, str):
        return "Unavailable"
    return PLAN_NAMES.get(value.strip().lower(), "Unavailable")


def credits_remaining(value: Any) -> str | None:
    if not isinstance(value, dict):
        return None
    if value.get("unlimited") is True:
        return "Unlimited"
    if value.get("has_credits") is not True:
        return None
    balance = value.get("balance")
    if isinstance(balance, bool) or not isinstance(balance, (str, int, float)):
        return None
    text = str(balance).strip()
    if not text or len(text) > 64:
        return None
    try:
        if not Decimal(text).is_finite():
            return None
    except InvalidOperation:
        return None
    return text


def weekly_window(document: dict[str, Any]) -> dict[str, Any] | None:
    rate_limit = document.get("rate_limit")
    nested = rate_limit if isinstance(rate_limit, dict) else {}
    candidates = [
        document.get("primary_window") or nested.get("primary_window"),
        document.get("secondary_window") or nested.get("secondary_window"),
    ]
    for candidate in candidates:
        if not isinstance(candidate, dict):
            continue
        duration = integer(candidate.get("limit_window_seconds"))
        used = finite_number(candidate.get("used_percent"))
        if duration is None or used is None or not 6 * 86_400 <= max(0, duration) <= 8 * 86_400:
            continue
        clamped_used = min(100.0, max(0.0, used))
        return {
            "weekly_remaining_percent": 100.0 - clamped_used,
            "weekly_reset_at": parse_timestamp(candidate.get("reset_at")),
            "weekly_window_seconds": duration,
        }
    return None


def reset_credit_count(document: dict[str, Any]) -> int | None:
    value = document.get("rate_limit_reset_credits")
    if not isinstance(value, dict):
        return None
    count = integer(value.get("available_count"))
    return count if count is not None and count >= 0 else None


def reset_credit_details(document: dict[str, Any]) -> tuple[float | None, float | None]:
    values = document.get("credits")
    if not isinstance(values, list):
        return None, None

    candidates: list[tuple[float, float | None]] = []
    for value in values:
        if not isinstance(value, dict):
            continue
        if value.get("status") != "available" or value.get("is_supported_by_plan") is False:
            continue
        expiry = parse_timestamp(value.get("expires_at"))
        if expiry is not None:
            candidates.append((expiry, parse_timestamp(value.get("granted_at"))))

    if not candidates:
        return None, None
    expiry, granted = min(candidates, key=lambda item: item[0])
    return granted, expiry


def build_snapshot(access_token: str, account_id: str | None) -> dict[str, Any]:
    usage = fetch_json(USAGE_URL, access_token, account_id, timeout=15)
    weekly = weekly_window(usage) or {
        "weekly_remaining_percent": None,
        "weekly_reset_at": None,
        "weekly_window_seconds": None,
    }
    count = reset_credit_count(usage)
    granted_at = None
    expiry = None
    if count is not None and count > 0:
        try:
            details = fetch_json(RESET_CREDITS_URL, access_token, account_id, timeout=5)
            granted_at, expiry = reset_credit_details(details)
        except WidgetError:
            # The count remains useful when optional expiry metadata is unavailable.
            pass

    return {
        "status": "ok",
        "fetched_at": datetime.now().timestamp(),
        "plan": normalized_plan(usage.get("plan_type")),
        "credits_remaining": credits_remaining(usage.get("credits")),
        **weekly,
        "reset_credits_count": count,
        "reset_credit_granted_at": granted_at,
        "reset_credit_expiry": expiry,
    }


def main() -> None:
    try:
        access_token, account_id = read_credentials()
        emit(build_snapshot(access_token, account_id))
    except WidgetError as error:
        emit({"status": error.status, "message": error.message})
    except Exception:
        # Never serialize exception details: they may include paths or request data.
        emit({"status": "unavailable", "message": "Codex quota could not be loaded"})


if __name__ == "__main__":
    main()
