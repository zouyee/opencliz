#!/usr/bin/env bash
# check-doc-coverage.sh — 对照「已注册站点」检查 docs/adapters 是否有对应页面（Zig 版仓库）。
#
# Exit codes:
#   0 — 全部有文档，或仅报告（默认）
#   1 — --strict 且存在缺失
#
# Usage:
#   bash scripts/check-doc-coverage.sh
#   bash scripts/check-doc-coverage.sh --strict

set -euo pipefail

STRICT=false
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_BROWSER="$ROOT_DIR/docs/adapters/browser"
DOCS_DESKTOP="$ROOT_DIR/docs/adapters/desktop"
ADAPTER_SRC="$ROOT_DIR/src/adapters"

missing=()
total=0

# 从 Zig 适配器源码提取站点名（与 rg 口径一致）
while IFS= read -r site; do
  [[ -z "$site" ]] && continue
  total=$((total + 1))

  doc_ok=false
  if [[ -f "$DOCS_BROWSER/$site.md" ]]; then
    doc_ok=true
  elif [[ -f "$DOCS_DESKTOP/$site.md" ]]; then
    doc_ok=true
  elif [[ "$site" == *"-app" ]]; then
    alt="${site%-app}"
    if [[ -f "$DOCS_BROWSER/$alt.md" ]] || [[ -f "$DOCS_DESKTOP/$alt.md" ]]; then
      doc_ok=true
    fi
  fi

  if $doc_ok; then
    :
  else
    missing+=("$site")
  fi
done < <(rg 'pub const name = "' "$ADAPTER_SRC" -g'*.zig' | sed -E 's/.*name = "([^"]+)".*/\1/' | sort -u)

covered=$((total - ${#missing[@]}))

echo "📊 Doc coverage (Zig adapters): $covered/$total sites have docs/adapters/browser|desktop/*.md"
echo ""

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "⚠️  Missing docs for ${#missing[@]} site(s):"
  for name in "${missing[@]}"; do
    echo "   - $name  →  docs/adapters/browser/$name.md or docs/adapters/desktop/$name.md"
  done
  echo ""
  if $STRICT; then
    echo "❌ Doc check failed (--strict mode)."
    exit 1
  fi
  echo "💡 Run with --strict to fail CI on missing docs."
  exit 0
fi

echo "✅ All registered sites have documentation stubs or pages."
exit 0
