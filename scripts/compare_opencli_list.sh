#!/usr/bin/env bash
# 阶段 G：导出排序后的「命令清单」便于与 TS 版 `opencli list` 输出 diff
#
# 默认：TSV 数据行（无表头），列：site, name, source, pipeline(0|1), script(0|1)，按整行 LC_ALL=C 排序
#   ./scripts/compare_opencli_list.sh > zig-commands.tsv
#
# 含表头（给表格/脚本解析）：
#   OPENCLI_LIST_HEADER=1 ./scripts/compare_opencli_list.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/zig-out/bin/opencli"
if [[ ! -x "$BIN" ]]; then
  echo "请先: cd \"$ROOT\" && zig build" >&2
  exit 1
fi

if [[ -n "${OPENCLI_LIST_HEADER:-}" ]]; then
  exec "$BIN" list --tsv
fi

"$BIN" list --tsv 2>/dev/null | tail -n +2 | LC_ALL=C sort
