# Medium

**Mode**: 🌗 Mixed · **Domain**: `medium.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz medium feed` | Get hot Medium posts, optionally scoped to a topic |
| `opencliz medium search` | Search Medium posts by keyword |
| `opencliz medium user` | Get recent articles by a user |

## Usage Examples

```bash
# Get the general Medium feed
opencliz medium feed --limit 10

# Search posts by keyword
opencliz medium search ai

# Get articles by a user
opencliz medium user @username

# Topic feed as JSON
opencliz medium feed --topic programming -f json
```

## Prerequisites

- `opencliz medium search` can run without a browser
- `opencliz medium feed` and `opencliz medium user` require Browser Bridge access to `medium.com`
