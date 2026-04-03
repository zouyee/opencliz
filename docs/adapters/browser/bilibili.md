# Bilibili

**Mode**: 🔐 Browser · **Domain**: `bilibili.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz bilibili hot` | |
| `opencliz bilibili search` | |
| `opencliz bilibili me` | |
| `opencliz bilibili favorite` | |
| `opencliz bilibili history` | |
| `opencliz bilibili feed` | |
| `opencliz bilibili subtitle` | |
| `opencliz bilibili dynamic` | |
| `opencliz bilibili ranking` | |
| `opencliz bilibili following` | |
| `opencliz bilibili user-videos` | |
| `opencliz bilibili download` | |

## Usage Examples

```bash
# Quick start
opencliz bilibili hot --limit 5

# Search videos
opencliz bilibili search "Black Myth" --limit 10

# Read one creator's videos
opencliz bilibili user-videos 2 --limit 10

# Fetch subtitles
opencliz bilibili subtitle BV1xx411c7mD --lang zh-CN

# JSON output
opencliz bilibili hot -f json

# Verbose mode
opencliz bilibili hot -v
```

## Prerequisites

- Chrome running and **logged into** bilibili.com
- [Browser Bridge extension](/guide/browser-bridge) installed
