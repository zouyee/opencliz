# Facebook

**Mode**: 🔐 Browser · **Domain**: `facebook.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz facebook profile` | Get user/page profile info |
| `opencliz facebook notifications` | Get recent notifications |
| `opencliz facebook feed` | Get news feed posts |
| `opencliz facebook search` | Search people, pages, posts |

## Usage Examples

```bash
# View a profile
opencliz facebook profile zuck

# Get notifications
opencliz facebook notifications --limit 10

# News feed
opencliz facebook feed --limit 5

# Search
opencliz facebook search "OpenAI" --limit 5

# JSON output
opencliz facebook profile zuck -f json
```

## Prerequisites

- Chrome running and **logged into** facebook.com
- [Browser Bridge extension](/guide/browser-bridge) installed
