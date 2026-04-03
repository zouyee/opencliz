#!/usr/bin/env bash
# 列出 http_exec 中仍为 todo / 登录占位 的分支，便于按站点维护 L3/L4 backlog。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v rg >/dev/null 2>&1; then
  rg -n 'put\("status"|need_uid_or_cookie|login required|login_required|desktop_cdp|http_or_cdp|need_argument|local_app' src/adapters/http_exec.zig || true
else
  grep -n 'put("status"\|need_uid_or_cookie\|login required\|login_required\|desktop_cdp\|http_or_cdp\|need_argument\|local_app' src/adapters/http_exec.zig || true
fi
