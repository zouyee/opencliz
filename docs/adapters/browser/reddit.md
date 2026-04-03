# Reddit

**Mode**: 🔐 Browser · **Domain**: `reddit.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz reddit hot` | |
| `opencliz reddit frontpage` | |
| `opencliz reddit popular` | |
| `opencliz reddit search` | |
| `opencliz reddit subreddit` | |
| `opencliz reddit read` | |
| `opencliz reddit user` | |
| `opencliz reddit user-posts` | |
| `opencliz reddit user-comments` | |
| `opencliz reddit upvote` | |
| `opencliz reddit save` | |
| `opencliz reddit comment` | |
| `opencliz reddit subscribe` | |
| `opencliz reddit saved` | |
| `opencliz reddit upvoted` | |

## Usage Examples

```bash
# Quick start
opencliz reddit hot --limit 5

# Read one subreddit
opencliz reddit subreddit python --limit 10

# Read a post thread
opencliz reddit read 1abc123 --depth 2

# Comment on a post
opencliz reddit comment 1abc123 "Great post"

# JSON output
opencliz reddit hot -f json

# Verbose mode
opencliz reddit hot -v
```

## Prerequisites

- Chrome running and **logged into** reddit.com
- [Browser Bridge extension](/guide/browser-bridge) installed
