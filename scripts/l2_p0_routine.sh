#!/usr/bin/env bash
# L2 P0 常态化：无网跑全量单测（含 tests/fixtures/json 形状校验）+ 打印与 TS 并排 diff 的操作说明。
# 用法：在仓库根目录执行  ./scripts/l2_p0_routine.sh
# 文档：docs/TS_PARITY_REMAINING.md § 三、docs/TS_PARITY_99_CAP.md §3 P0
#
set -euo pipefail
ROOT="$(cd "$(dirname "${0}")/.." && pwd)"
cd "$ROOT"

echo "== 1/2 L2 P0：zig build test（含 fixture_json_test，默认无网络）==="
zig build test

echo ""
echo "== 2/2 与 TypeScript 版 opencli 并排 JSON diff（需网络 + 本机 jq + 已 zig build）==="
echo "建议本会话: export OPENCLI_CACHE=0"
echo ""
echo "--- 建议命令列表（逐条复制；站点改版可能导致失败）---"
bash "$ROOT/scripts/h_l2_ts_diff_suggestions.sh"
echo ""
echo "--- 导出 Zig JSON ---"
echo "  OPENCLI_CACHE=0 \"$ROOT/scripts/compare_command_json.sh\" hackernews/top --limit 1 -o /tmp/opencli-zig.json"
echo ""
echo "--- 导出 TS JSON（上游：github.com/jackwener/opencli / npm @jackwener/opencli）---"
echo "  \"$ROOT/scripts/record_jackwener_baseline.sh\" /tmp/opencli-ts.json hackernews top --limit 1"
echo "  或: npx @jackwener/opencli hackernews/top --limit 1 -f json | jq -S . > /tmp/opencli-ts.json"
echo "进度与基线表: docs/PARITY_PROGRESS.md"
echo ""
echo "--- 规范化后对比 ---"
echo "  diff -u <(jq -S . /tmp/opencli-zig.json) <(jq -S . /tmp/opencli-ts.json)"
echo ""
echo "--- 或一条命令（TS 已写入 /tmp/opencli-ts.json）---"
echo "  OPENCLI_CACHE=0 \"$ROOT/scripts/compare_command_json.sh\" --diff-ts /tmp/opencli-ts.json hackernews/top --limit 1"
echo ""
echo "--- P0.5：五条公开读命令一键导出并排 diff（见 docs/PARITY_PROGRESS.md）---"
echo "  OPENCLI_CACHE=0 \"$ROOT/scripts/parity_p0_5_export_zig.sh\""
echo "  \"$ROOT/scripts/parity_p0_5_export_upstream.sh\"   # 需 npx + 网络"
echo "  \"$ROOT/scripts/parity_p0_5_diff.sh\""
echo ""
