#!/usr/bin/env bash
# H.2 / 波次 2.3：有 Cookie 的写路径与读私有 API — 手工回归命令速查（需本机凭据与网络）。
# 详细步骤见 docs/AUTH_AND_WRITE_PATH.md §「写路径 Cookie 手工回归步骤」。
# 站点级承诺边界见同文档 §「P1：高频站点读/写边界签字矩阵」（批次 62）。
set -euo pipefail
echo "=== Reddit（OPENCLI_COOKIE）==="
echo 'opencli reddit/upvote --post-id "t3_xxx" --direction up -f json'
echo 'opencli reddit/save --post-id "t3_xxx" -f json'
echo "OPENCLI_USE_BROWSER=1 opencli reddit/comment --post-id \"t3_xxx\" --text \"…\" -f json"
echo ""
echo "=== Bilibili（OPENCLI_BILIBILI_COOKIE）==="
echo "opencli bilibili/favorite --uid <uid> --limit 5 -f json"
echo ""
echo "=== V2EX（OPENCLI_V2EX_COOKIE）==="
echo "opencli v2ex/notifications --limit 10 -f json"
echo "opencli v2ex/me -f json"
