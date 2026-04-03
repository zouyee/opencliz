# Pixiv

**Mode**: 🔐 Browser · **Domain**: `www.pixiv.net`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz pixiv ranking` | Daily/weekly/monthly illustration rankings |
| `opencliz pixiv search <query>` | Search illustrations by keyword or tag |
| `opencliz pixiv user <uid>` | View artist profile info |
| `opencliz pixiv illusts <user-id>` | List illustrations by artist |
| `opencliz pixiv detail <id>` | View illustration details |
| `opencliz pixiv download <illust-id>` | Download original-quality images |

## Usage Examples

### Ranking

```bash
# Daily rankings (default)
opencliz pixiv ranking --limit 10

# Weekly / monthly rankings
opencliz pixiv ranking --mode weekly
opencliz pixiv ranking --mode monthly

# R18 rankings
opencliz pixiv ranking --mode daily_r18
opencliz pixiv ranking --mode weekly_r18

# Other modes: rookie, original, male, female
opencliz pixiv ranking --mode rookie
```

### Search

```bash
# Search by keyword or tag
opencliz pixiv search "Hatsune Miku" --limit 20

# Filter by content rating
opencliz pixiv search "landscape" --mode safe       # Safe-for-work only
opencliz pixiv search "landscape" --mode r18        # R18 only
opencliz pixiv search "landscape" --mode all        # All (default)

# Sort by popularity
opencliz pixiv search "VOCALOID" --order popular_d

# All sort options: date_d (newest), date (oldest), popular_d, popular_male_d, popular_female_d

# Pagination
opencliz pixiv search "オリジナル" --page 2 --limit 30
```

### User & Illustrations

```bash
# View artist profile
opencliz pixiv user 11

# List artist's illustrations (newest first)
opencliz pixiv illusts 11 --limit 10

# View illustration details (tags, stats, type)
opencliz pixiv detail 12345678
```

### Download

```bash
# Download all images from an illustration
opencliz pixiv download 12345678

# Download to a custom directory
opencliz pixiv download 12345678 --output ./my-images
```

### Output Formats

```bash
# JSON output
opencliz pixiv ranking -f json

# Verbose mode
opencliz pixiv search "test" -v
```

## Prerequisites

- Chrome running and **logged into** pixiv.net
- [Browser Bridge extension](/guide/browser-bridge) installed
