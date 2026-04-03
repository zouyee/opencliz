#!/usr/bin/env bash
# PARITY_PROGRESS P0.5：导出 jackwener/opencli 同五条命令的 JSON（需网络 + npx）。
# 用法: ./scripts/parity_p0_5_export_upstream.sh
# 可选: JACKWENER_OPENCLI_PKG=@jackwener/opencli@1.6.1 PARITY_OUT=/tmp/p ./scripts/parity_p0_5_export_upstream.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${0}")/.." && pwd)"
OUT="${PARITY_OUT:-$ROOT/parity-output}/ts"
PKG="${JACKWENER_OPENCLI_PKG:-@jackwener/opencli}"
REC="$ROOT/scripts/record_jackwener_baseline.sh"

mkdir -p "$OUT"
if ! command -v jq >/dev/null 2>&1; then
    echo "需要 jq" >&2
    exit 1
fi

echo "上游包: $PKG" >&2
"$REC" "$OUT/hackernews_top.json" hackernews top --limit 2
"$REC" "$OUT/github_trending.json" github trending --language rust --limit 2
"$REC" "$OUT/v2ex_hot.json" v2ex hot --limit 3
"$REC" "$OUT/npm_search.json" npm search --query express --limit 2
"$REC" "$OUT/crates_search.json" crates search --query serde --limit 2

echo "Wrote JSON under $OUT" >&2
