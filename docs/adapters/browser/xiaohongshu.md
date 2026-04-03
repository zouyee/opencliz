# Xiaohongshu

**Mode**: 🔐 Browser · **Domain**: `xiaohongshu.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz xiaohongshu search` | Search notes by keyword (returns title, author, likes, URL) |
| `opencliz xiaohongshu notifications` | |
| `opencliz xiaohongshu feed` | |
| `opencliz xiaohongshu user` | |
| `opencliz xiaohongshu download` | |
| `opencliz xiaohongshu creator-notes` | |
| `opencliz xiaohongshu creator-note-detail` | |
| `opencliz xiaohongshu creator-notes-summary` | |
| `opencliz xiaohongshu creator-profile` | |
| `opencliz xiaohongshu creator-stats` | |

## Usage Examples

```bash
# Search for notes
opencliz xiaohongshu search food --limit 10

# JSON output
opencliz xiaohongshu search travel -f json

# Other commands
opencliz xiaohongshu feed
opencliz xiaohongshu notifications
opencliz xiaohongshu download <url>
```

## Prerequisites

- Chrome running and **logged into** xiaohongshu.com
- [Browser Bridge extension](/guide/browser-bridge) installed
