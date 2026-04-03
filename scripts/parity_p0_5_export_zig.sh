#!/usr/bin/env bash
# PARITY_PROGRESS P0.5：导出 Zig opencli 五条公开读命令的 JSON（jq -S），供与上游并排 diff。
# 用法（仓库根）: OPENCLI_CACHE=0 ./scripts/parity_p0_5_export_zig.sh
# 输出目录: parity-output/zig/（默认，见 .gitignore）
set -euo pipefail
ROOT="$(cd "$(dirname "${0}")/.." && pwd)"
OUT="${PARITY_OUT:-$ROOT/parity-output}/zig"
ZIG_BIN="${ZIG_BIN:-$ROOT/zig-out/bin/opencliz}"
export OPENCLI_CACHE="${OPENCLI_CACHE:-0}"

mkdir -p "$OUT"
if [[ ! -x "$ZIG_BIN" ]]; then
    echo "请先: cd \"$ROOT\" && zig build" >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "需要 jq" >&2
    exit 1
fi

run() {
    local name="$1"
    shift
    echo "zig: $name" >&2
    "$ZIG_BIN" "$@" -f json | jq -S . >"$OUT/${name}.json"
}

run hackernews_top hackernews/top --limit 2
run github_trending github/trending --language rust --limit 2
run v2ex_hot v2ex/hot --limit 3
run npm_search npm/search --query express --limit 2
run crates_search crates/search --query serde --limit 2

echo "Wrote JSON under $OUT" >&2
