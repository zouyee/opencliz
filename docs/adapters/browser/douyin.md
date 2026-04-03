# Douyin (Creator Center)

**Mode**: 🔐 Browser · **Domain**: `creator.douyin.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz douyin profile` | Account info |
| `opencliz douyin videos` | Published works list |
| `opencliz douyin drafts` | Draft list |
| `opencliz douyin draft` | Upload video and save as draft |
| `opencliz douyin publish` | Schedule publish to Douyin |
| `opencliz douyin update` | Update video metadata |
| `opencliz douyin delete` | Delete a work |
| `opencliz douyin stats` | Analytics for a work |
| `opencliz douyin collections` | Collections list |
| `opencliz douyin activities` | Official activities list |
| `opencliz douyin location` | Search locations usable for publishing |
| `opencliz douyin hashtag search` | Search hashtags by keyword |
| `opencliz douyin hashtag suggest` | Suggest hashtags from a cover URI |
| `opencliz douyin hashtag hot` | Trending hashtag terms |

## Usage Examples

```bash
# Account and works
opencliz douyin profile
opencliz douyin videos --limit 10
opencliz douyin videos --status scheduled
opencliz douyin drafts

# Before publishing
opencliz douyin collections
opencliz douyin activities
opencliz douyin location "Tokyo Tower"
opencliz douyin hashtag search "spring trip"
opencliz douyin hashtag hot --limit 10

# Save draft
opencliz douyin draft ./video.mp4 \
  --title "Spring trip vlog" \
  --caption "#springtrip saving as draft"

# Scheduled publish
opencliz douyin publish ./video.mp4 \
  --title "Spring trip vlog" \
  --caption "#springtrip cherry blossoms today" \
  --schedule "2026-04-08T12:00:00+09:00"

# Unix epoch seconds also supported
opencliz douyin publish ./video.mp4 \
  --title "Spring trip vlog" \
  --schedule 1775617200

# Update and delete
opencliz douyin update 1234567890 --caption "Updated caption"
opencliz douyin update 1234567890 --reschedule "2026-04-09T20:00:00+09:00"
opencliz douyin delete 1234567890

# JSON output
opencliz douyin profile -f json
```

## Prerequisites

- Chrome running and **logged into** `creator.douyin.com`
- The logged-in account must have access to Douyin Creator Center publishing features
- [Browser Bridge extension](/guide/browser-bridge) installed

## Notes

- `publish` requires `--schedule` to be at least 2 hours later and no more than 14 days later
- `draft` and `publish` upload the video through Douyin/ByteDance browser-authenticated APIs, so cookies in the active browser session must be valid
- `hashtag suggest` expects a valid `cover`/`cover_uri` value produced during the publish pipeline; for normal manual use, `hashtag search` and `hashtag hot` are usually more convenient
