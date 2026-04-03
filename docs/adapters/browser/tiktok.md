# TikTok

**Mode**: 🔐 Browser · **Domain**: `tiktok.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz tiktok profile` | Get user profile info |
| `opencliz tiktok search` | Search videos |
| `opencliz tiktok explore` | Trending videos from explore page |
| `opencliz tiktok user` | Get recent videos from a user |
| `opencliz tiktok following` | List accounts you follow |
| `opencliz tiktok friends` | Friend suggestions |
| `opencliz tiktok live` | Browse live streams |
| `opencliz tiktok notifications` | Get notifications |
| `opencliz tiktok like` | Like a video |
| `opencliz tiktok unlike` | Unlike a video |
| `opencliz tiktok save` | Add to Favorites |
| `opencliz tiktok unsave` | Remove from Favorites |
| `opencliz tiktok follow` | Follow a user |
| `opencliz tiktok unfollow` | Unfollow a user |
| `opencliz tiktok comment` | Comment on a video |

## Usage Examples

```bash
# View a user's profile
opencliz tiktok profile --username tiktok

# Search videos
opencliz tiktok search "cooking" --limit 10

# Trending explore videos
opencliz tiktok explore --limit 20

# Browse live streams
opencliz tiktok live --limit 10

# List who you follow
opencliz tiktok following

# Friend suggestions
opencliz tiktok friends --limit 10

# Like/unlike a video
opencliz tiktok like --url "https://www.tiktok.com/@user/video/123"
opencliz tiktok unlike --url "https://www.tiktok.com/@user/video/123"

# Save/unsave (Favorites)
opencliz tiktok save --url "https://www.tiktok.com/@user/video/123"
opencliz tiktok unsave --url "https://www.tiktok.com/@user/video/123"

# Follow/unfollow
opencliz tiktok follow --username nasa
opencliz tiktok unfollow --username nasa

# Comment on a video
opencliz tiktok comment --url "https://www.tiktok.com/@user/video/123" --text "Great!"

# JSON output
opencliz tiktok profile --username tiktok -f json
```

## Prerequisites

- Chrome running and **logged into** tiktok.com
- [Browser Bridge extension](/guide/browser-bridge) installed
