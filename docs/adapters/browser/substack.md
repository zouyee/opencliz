# Substack

**Mode**: 🌐 Public (search) / 🔐 Browser (feed, publication) · **Domain**: `substack.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz substack feed` | Trending Substack feed |
| `opencliz substack search` | Search posts and newsletters (no browser) |
| `opencliz substack publication` | Latest posts for a given newsletter |

## Usage Examples

```bash
# Trending feed
opencliz substack feed --limit 10

# Feed by category
opencliz substack feed --category tech --limit 10

# Search posts (public API, no browser)
opencliz substack search "AI"

# Search newsletters
opencliz substack search "technology" --type publications

# Latest from one newsletter
opencliz substack publication "https://example.substack.com" --limit 10

# JSON output
opencliz substack search "AI" -f json
```

## Prerequisites

- `search`: no login (public API)
- `feed`, `publication`: Chrome can reach `substack.com`, Browser Bridge extension installed
