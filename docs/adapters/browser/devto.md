# Dev.to

**Mode**: 🌐 Public · **Domain**: `dev.to`

Fetch the latest and greatest developer articles from the DEV community without needing an API key.

## Commands

| Command | Description |
|---------|-------------|
| `opencliz devto top` | Top DEV.to articles of the day |
| `opencliz devto tag` | Latest articles for a specific tag |
| `opencliz devto user` | Recent articles from a specific user |

## Usage Examples

```bash
# Top articles today
opencliz devto top --limit 5

# Articles by tag (positional argument)
opencliz devto tag javascript
opencliz devto tag python --limit 20

# Articles by a specific author
opencliz devto user ben
opencliz devto user thepracticaldev --limit 5

# JSON output
opencliz devto top -f json
```

## Prerequisites

- No browser required — uses the public DEV.to API
