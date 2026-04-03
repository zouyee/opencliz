# WeChat (official accounts)

**Mode**: 🔐 Browser · **Domain**: `mp.weixin.qq.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz weixin download` | Download a WeChat article as Markdown |

## Usage Examples

```bash
# Export article to Markdown
opencliz weixin download --url "https://mp.weixin.qq.com/s/xxx" --output ./weixin

# Export with locally downloaded images
opencliz weixin download --url "https://mp.weixin.qq.com/s/xxx" --download-images

# Export without images
opencliz weixin download --url "https://mp.weixin.qq.com/s/xxx" --no-download-images
```

## Output

Downloads to `<output>/<article-title>/`:
- `<article-title>.md` — Markdown with frontmatter (title, author, publish time, source URL)
- `images/` — Downloaded images (if `--download-images` is enabled, default: true)

## Prerequisites

- Chrome running and **logged into** mp.weixin.qq.com (for articles behind login wall)
- [Browser Bridge extension](/guide/browser-bridge) installed
