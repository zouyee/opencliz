# HackerNews

**Mode**: 🌐 Public · **Domain**: `news.ycombinator.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz hackernews top` | Hacker News top stories |
| `opencliz hackernews new` | Hacker News newest stories |
| `opencliz hackernews best` | Hacker News best stories |
| `opencliz hackernews ask` | Hacker News Ask HN posts |
| `opencliz hackernews show` | Hacker News Show HN posts |
| `opencliz hackernews jobs` | Hacker News job postings |
| `opencliz hackernews search <query>` | Search Hacker News stories |
| `opencliz hackernews user <username>` | Hacker News user profile |

## Usage Examples

```bash
# Top stories
opencliz hackernews top --limit 5

# Newest stories
opencliz hackernews new --limit 10

# Search stories
opencliz hackernews search "machine learning" --limit 5

# User profile
opencliz hackernews user pg

# JSON output
opencliz hackernews top -f json

# Sort search by date
opencliz hackernews search "rust" --sort date
```

## Prerequisites

- No browser required — uses public API
