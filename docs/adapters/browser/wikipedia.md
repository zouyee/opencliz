# Wikipedia

**Mode**: 🌐 Public · **Domain**: `wikipedia.org`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz wikipedia search` | Search Wikipedia articles |
| `opencliz wikipedia summary` | Get Wikipedia article summary |

## Usage Examples

```bash
# Search articles
opencliz wikipedia search "quantum computing" --limit 10

# Get article summary
opencliz wikipedia summary "Artificial intelligence"

# Use with other languages
opencliz wikipedia search "Shanghai" --lang zh

# JSON output
opencliz wikipedia search "Rust" -f json
```

## Prerequisites

- No browser required — uses public Wikipedia API
