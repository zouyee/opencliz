#!/usr/bin/env bash
# 供 OPENCLI_HTML_TO_MD_SCRIPT 指向本脚本（或复制到 PATH）：将 .opencli/article-html-input.html 转为 Markdown。
# 依赖: pandoc（brew install pandoc / apt install pandoc）
# 用法:
#   export OPENCLI_HTML_TO_MD_SCRIPT="$PWD/examples/html_to_md_pandoc_wrap.sh"
#   # 再跑带 article 导出的 zig 命令
set -euo pipefail
if [[ $# -lt 1 ]]; then
    echo "用法: $0 <html-file>" >&2
    exit 1
fi
exec pandoc -f html -t gfm "$1"
