# Sina Blog

**Mode**: 🌐 Public (search) / 🔐 Browser (hot, article, user) · **Domain**: `blog.sina.com.cn`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz sinablog hot` | Hot / recommended posts |
| `opencliz sinablog search` | Search posts (Sina search API, no browser) |
| `opencliz sinablog article` | Single post detail |
| `opencliz sinablog user` | User’s post list |

## Usage Examples

```bash
# Hot posts
opencliz sinablog hot --limit 10

# Search (public API, no browser)
opencliz sinablog search "machine learning"

# Article detail
opencliz sinablog article "https://blog.sina.com.cn/s/blog_xxx.html"

# User posts
opencliz sinablog user 1234567890 --limit 10

# JSON output
opencliz sinablog hot -f json
```

## Prerequisites

- `search`: no login (public API)
- `hot`, `article`, `user`: Chrome can reach `blog.sina.com.cn`, Browser Bridge extension installed
