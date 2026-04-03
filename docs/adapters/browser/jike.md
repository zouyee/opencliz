# Jike

**Mode**: 🔐 Browser · **Domain**: `web.okjike.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz jike feed` | Home feed |
| `opencliz jike search` | Search posts |
| `opencliz jike post` | Post detail and comments |
| `opencliz jike topic` | Topic detail |
| `opencliz jike user` | User profile |
| `opencliz jike create` | Publish a post |
| `opencliz jike comment` | Comment on a post |
| `opencliz jike like` | Like a post |
| `opencliz jike repost` | Repost |
| `opencliz jike notifications` | Notifications |

## Usage Examples

```bash
# View feed
opencliz jike feed --limit 10

# Search posts
opencliz jike search "AI" --limit 20

# View post details and comments
opencliz jike post <post-id>

# Create a new post
opencliz jike create --content "Hello Jike!"

# Like a post
opencliz jike like <post-id>

# JSON output
opencliz jike feed -f json
```

## Prerequisites

- Chrome running and **logged into** web.okjike.com
- [Browser Bridge extension](/guide/browser-bridge) installed
