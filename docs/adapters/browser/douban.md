# Douban

**Mode**: 🔐 Browser (Cookie) · **Domain**: `douban.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz douban search` | Search movies, books, or music |
| `opencliz douban top250` | Douban Top 250 movies |
| `opencliz douban subject` | Subject (item) detail |
| `opencliz douban marks` | Your marks |
| `opencliz douban reviews` | Your short reviews |
| `opencliz douban movie-hot` | Hot movies chart |
| `opencliz douban book-hot` | Hot books chart |

## Usage Examples

```bash
# Search movies
opencliz douban search "The Wandering Earth"

# Search books
opencliz douban search --type book "Three-Body"

# Search music
opencliz douban search --type music "Jay Chou"

# Movie Top 250
opencliz douban top250 --limit 10

# Subject detail
opencliz douban subject 1292052

# Hot movies
opencliz douban movie-hot --limit 10

# Hot books
opencliz douban book-hot --limit 10

# JSON output
opencliz douban top250 -f json
```

## Prerequisites

- Chrome logged into `douban.com`
- Browser Bridge extension installed
