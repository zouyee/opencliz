#!/usr/bin/env bash
# L2 P0：导出 Zig opencli 某命令的 JSON，便于与 TS 版同参数输出 diff（见 docs/TS_PARITY_REMAINING.md § 三、scripts/l2_p0_routine.sh）。
#
# 用法:
#   ./scripts/compare_command_json.sh hackernews/top --limit 2
#   ./scripts/compare_command_json.sh bilibili/hot --limit 3 -o /tmp/zig-hot.json
#   ./scripts/compare_command_json.sh --validate github/trending --language rust --limit 1
#   OPENCLI_CACHE=0 ./scripts/compare_command_json.sh --diff-ts /tmp/ts.json hackernews/top --limit 1
#
# 环境变量:
#   ZIG_BIN  默认: <repo>/zig-out/bin/opencli
#   OPENCLI_CACHE=0  建议与 TS 并排 diff 时关闭适配器 fetchJson 的 JSON 内存缓存（批次 56；TTL 见 OPENCLI_CACHE_*）
#
# 与上游 TS 版并排对比（基线：github.com/jackwener/opencli；需 jq 排序键）:
#   ./scripts/compare_command_json.sh hackernews/top --limit 1 > zig.json
#   npx @jackwener/opencli hackernews/top --limit 1 -f json > ts.json
#   或克隆 jackwener/opencli 后在其目录 npx opencli …
#   diff -u <(jq -S . zig.json) <(jq -S . ts.json)
#
# 一键对比（Zig  stdout 与 TS 已落盘文件，经 jq -S 规范化后 diff；exit 1 表示有差异）:
#   OPENCLI_CACHE=0 ./scripts/compare_command_json.sh --diff-ts ts.json hackernews/top --limit 1
#
set -euo pipefail
ROOT="$(cd "$(dirname "${0}")/.." && pwd)"
ZIG_BIN="${ZIG_BIN:-$ROOT/zig-out/bin/opencli}"

VALIDATE=0
OUTPUT=""
DIFF_TS=""
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            sed -n '2,24p' "$0"
            exit 0
            ;;
        --validate)
            VALIDATE=1
            shift
            ;;
        --diff-ts)
            DIFF_TS="${2:-}"
            if [[ -z "$DIFF_TS" ]]; then
                echo "compare_command_json.sh: --diff-ts 需要文件路径" >&2
                exit 1
            fi
            shift 2
            ;;
        -o)
            OUTPUT="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#ARGS[@]} -eq 0 ]]; then
    echo "用法: $0 [--validate] [--diff-ts FILE] [-o FILE] <site/command> [opencli 参数...]" >&2
    exit 1
fi

if [[ -n "$DIFF_TS" && -n "$OUTPUT" ]]; then
    echo "compare_command_json.sh: 与 --diff-ts 同时使用时忽略 -o（Zig 输出仅用于内存对比）" >&2
fi

if [[ ! -x "$ZIG_BIN" ]]; then
    echo "请先: cd \"$ROOT\" && zig build" >&2
    exit 1
fi

run_zig_json() {
    "$ZIG_BIN" "${ARGS[@]}" -f json
}

pipe_out() {
    if [[ -n "$OUTPUT" ]]; then
        cat >"$OUTPUT"
    else
        cat
    fi
}

if [[ -n "$DIFF_TS" ]]; then
    if [[ ! -f "$DIFF_TS" ]]; then
        echo "compare_command_json.sh: --diff-ts 不是可读文件: $DIFF_TS" >&2
        exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "compare_command_json.sh: --diff-ts 需要系统已安装 jq" >&2
        exit 1
    fi
    zig_tmp="$(mktemp "${TMPDIR:-/tmp}/opencli-zig-json.XXXXXX")"
    cleanup() { rm -f "$zig_tmp"; }
    trap cleanup EXIT
    run_zig_json >"$zig_tmp"
    set +e
    diff -u <(jq -S . "$zig_tmp") <(jq -S . "$DIFF_TS")
    ec=$?
    set -e
    if [[ $ec -eq 0 ]]; then
        echo "compare_command_json.sh: jq -S 规范化后 Zig 与 TS 文件一致" >&2
    elif [[ $ec -eq 1 ]]; then
        echo "compare_command_json.sh: 存在差异（unified diff 见上）；CI 可用 exit 1 判红" >&2
    else
        echo "compare_command_json.sh: diff/jq 异常 (exit $ec)" >&2
    fi
    exit "$ec"
fi

if [[ $VALIDATE -eq 1 ]]; then
    if command -v jq >/dev/null 2>&1; then
        run_zig_json | jq . | pipe_out
    elif command -v python3 >/dev/null 2>&1; then
        run_zig_json | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), ensure_ascii=False, indent=2))' | pipe_out
    else
        echo "compare_command_json.sh: --validate 需要 jq 或 python3" >&2
        exit 1
    fi
else
    run_zig_json | pipe_out
fi
