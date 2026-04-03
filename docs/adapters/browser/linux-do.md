# LINUX DO

**Mode**: 🔐 Browser · **Domain**: `linux.do`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz linux-do hot` | Hot topics |
| `opencliz linux-do latest` | Latest topics |
| `opencliz linux-do categories` | Category list |
| `opencliz linux-do category` | Topics in a category |
| `opencliz linux-do search` | Search topics |
| `opencliz linux-do topic` | Topic detail |

## Usage Examples

```bash
# Hot topics this week
opencliz linux-do hot --limit 20

# Hot topics by period
opencliz linux-do hot --period daily
opencliz linux-do hot --period monthly

# Latest topics
opencliz linux-do latest --limit 10

# List all categories
opencliz linux-do categories

# Search topics
opencliz linux-do search "NixOS"

# View topic details
opencliz linux-do topic 12345

# JSON output
opencliz linux-do hot -f json
```

## Prerequisites

- Chrome running and **logged into** linux.do
- [Browser Bridge extension](/guide/browser-bridge) installed
