#!/usr/bin/env bash
# PARITY_PROGRESS P0.5：对 parity-output/zig 与 parity-output/ts 同名 JSON 做 diff（需先跑两个 export）。
# 用法: ./scripts/parity_p0_5_diff.sh
# exit 1 若任一文件有差异（便于 CI）；仅查看可: ./scripts/parity_p0_5_diff.sh || true
set -euo pipefail
ROOT="$(cd "$(dirname "${0}")/.." && pwd)"
BASE="${PARITY_OUT:-$ROOT/parity-output}"
ZDIR="$BASE/zig"
TDIR="$BASE/ts"
FAIL=0

for name in hackernews_top github_trending v2ex_hot npm_search crates_search; do
    zf="$ZDIR/${name}.json"
    tf="$TDIR/${name}.json"
    if [[ ! -f "$zf" || ! -f "$tf" ]]; then
        if [[ "$name" == "v2ex_hot" && -n "${PARITY_SKIP_V2EX:-}" ]]; then
            echo "skip diff v2ex_hot (PARITY_SKIP_V2EX)" >&2
            continue
        fi
    fi
    if [[ ! -f "$zf" ]]; then
        echo "缺少 $zf（先运行 parity_p0_5_export_zig.sh）" >&2
        FAIL=1
        continue
    fi
    if [[ ! -f "$tf" ]]; then
        echo "缺少 $tf（先运行 parity_p0_5_export_upstream.sh）" >&2
        FAIL=1
        continue
    fi
    echo "=== diff $name ===" >&2
    if diff -u "$zf" "$tf"; then
        echo "OK $name" >&2
    else
        echo "DIFF $name" >&2
        FAIL=1
    fi
done

exit "$FAIL"
