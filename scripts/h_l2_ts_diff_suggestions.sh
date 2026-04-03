#!/usr/bin/env bash
# 阶段 H.1 / L2 P0：建议与上游 jackwener/opencli（npx @jackwener/opencli）同参并排 JSON diff（需网络）。
# 一键流程：./scripts/l2_p0_routine.sh（先无网单测，再打印本列表与 diff 示例）
# 用法：./scripts/h_l2_ts_diff_suggestions.sh
# 配合：./scripts/compare_command_json.sh <同上> > zig.json
#       (cd ../opencli && npx opencli … -f json) > ts.json
#       diff -u <(jq -S . zig.json) <(jq -S . ts.json)
#
# 降低缓存导致的假差异：可在一次会话前执行 `export OPENCLI_CACHE=0`（见 MIGRATION_GAP 批次 49）。
#
set -euo pipefail
echo "# 核心公开读（低参数）；按站点改版情况部分可能失败"
echo "hackernews/top --limit 2"
echo "github/trending --language zig --limit 2"
echo "v2ex/hot --limit 3"
echo "bilibili/hot --limit 2"
echo "stackoverflow/hot --limit 2"
echo "npm/search --query express --limit 2"
echo "pypi/search --query requests --limit 2"
echo "crates/search --query serde --limit 2"
echo "# 百科 / 中文（与 tests/fixtures/json 形状对照）"
echo "wikipedia/search --query 'OpenAI' --limit 2"
echo "wikipedia/summary --title 'Zig_(programming_language)'"
echo "douban/search --type movie --keyword test --limit 3"
echo "douban/movie-hot --limit 3"
echo "# 有环境变量或登录时再加：reddit、twitter、weibo、zhihu 等"
