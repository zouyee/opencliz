#!/usr/bin/env bash
# P0：导出上游 jackwener/opencli 的 JSON（jq -S），供与 Zig 并排 diff；需网络与 Node/npm。
# 用法:
#   ./scripts/record_jackwener_baseline.sh /tmp/ts-hn.json hackernews top --limit 1
# 环境变量:
#   JACKWENER_OPENCLI_PKG  默认 @jackwener/opencli（可 pin 版本如 @jackwener/opencli@1.6.1）
#
# 将包版本写入基线表: docs/PARITY_PROGRESS.md §「基线记录」
set -euo pipefail
if [[ $# -lt 2 ]]; then
    echo "用法: $0 <输出.json> <site> <command> [opencli 参数...]" >&2
    echo "示例: $0 /tmp/ts.json hackernews top --limit 1" >&2
    exit 1
fi
OUT="$1"
shift
PKG="${JACKWENER_OPENCLI_PKG:-@jackwener/opencli}"
if ! command -v jq >/dev/null 2>&1; then
    echo "$0: 需要 jq" >&2
    exit 1
fi
mkdir -p "$(dirname "$OUT")"
echo "Recording: npx -y $PKG $* -f json -> $OUT (sorted)" >&2
npx -y "$PKG" "$@" -f json | jq -S . >"$OUT"
echo "Wrote $OUT" >&2
