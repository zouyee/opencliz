# Instagram

**Mode**: 🔐 Browser · **Domain**: `instagram.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz instagram profile` | Get user profile info |
| `opencliz instagram search` | Search users |
| `opencliz instagram user` | Get recent posts from a user |
| `opencliz instagram explore` | Discover trending posts |
| `opencliz instagram followers` | List user's followers |
| `opencliz instagram following` | List user's following |
| `opencliz instagram saved` | Get your saved posts |

## Usage Examples

```bash
# View a user's profile
opencliz instagram profile nasa

# Search users
opencliz instagram search nasa --limit 5

# View a user's recent posts
opencliz instagram user nasa --limit 10

# Discover trending posts
opencliz instagram explore --limit 20

# List followers/following
opencliz instagram followers nasa --limit 20
opencliz instagram following nasa --limit 20

# Get your saved posts
opencliz instagram saved --limit 10

# JSON output
opencliz instagram profile nasa -f json
```

## Prerequisites

- Chrome running and **logged into** instagram.com
- [Browser Bridge extension](/guide/browser-bridge) installed
