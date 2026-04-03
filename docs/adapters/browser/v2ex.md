# V2EX

**Mode**: 🌐 / 🔐 · **Domain**: `v2ex.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz v2ex hot` | Hot topics |
| `opencliz v2ex latest` | Latest topics |
| `opencliz v2ex topic <id>` | Topic detail |
| `opencliz v2ex node <name>` | Topics by node |
| `opencliz v2ex user <username>` | Topics by user |
| `opencliz v2ex member <username>` | User profile |
| `opencliz v2ex replies <id>` | Topic replies |
| `opencliz v2ex nodes` | All nodes (sorted by topic count) |
| `opencliz v2ex daily` | Daily hot |
| `opencliz v2ex me` | My profile (auth required) |
| `opencliz v2ex notifications` | My notifications (auth required) |

## Usage Examples

```bash
# Hot topics
opencliz v2ex hot --limit 5

# Browse topics in a node
opencliz v2ex node python

# View topic replies
opencliz v2ex replies 1000

# User's topics
opencliz v2ex user Livid

# User profile
opencliz v2ex member Livid

# List all nodes
opencliz v2ex nodes --limit 10

# JSON output
opencliz v2ex hot -f json
```

## Prerequisites

Most commands (`hot`, `latest`, `topic`, `node`, `user`, `member`, `replies`, `nodes`) use the public V2EX API and **require no browser or login**.

For `daily`, `me`, and `notifications`:

- Chrome running and **logged into** v2ex.com
- [Browser Bridge extension](/guide/browser-bridge) installed
