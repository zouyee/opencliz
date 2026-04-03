# WeRead

**Mode**: 🔐 Browser · **Domain**: `weread.qq.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz weread shelf` | List books on your bookshelf |
| `opencliz weread search` | Search books on WeRead |
| `opencliz weread book` | View book details |
| `opencliz weread ranking` | Book rankings by category |
| `opencliz weread notebooks` | List books that have highlights or notes |
| `opencliz weread highlights` | List your highlights (underlines) in a book |
| `opencliz weread notes` | List your notes (thoughts) on a book |

## Usage Examples

```bash
# View your bookshelf
opencliz weread shelf --limit 20

# Search books
opencliz weread search "Three-Body"

# View book details
opencliz weread book <book-id>

# Book rankings
opencliz weread ranking --limit 10

# List books with notes/highlights
opencliz weread notebooks

# View highlights for a book
opencliz weread highlights <book-id>

# View your notes
opencliz weread notes <book-id>

# JSON output
opencliz weread shelf -f json
```

## Prerequisites

- Chrome running and **logged into** weread.qq.com
- [Browser Bridge extension](/guide/browser-bridge) installed
