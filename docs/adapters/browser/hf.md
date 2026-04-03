# Hugging Face

**Mode**: 🌐 Public · **Domain**: `huggingface.co`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz hf top` | Top upvoted Hugging Face papers |

## Usage Examples

```bash
# Today's top papers
opencliz hf top --limit 10

# All papers (no limit)
opencliz hf top --all

# Specific date
opencliz hf top --date 2025-03-01

# Weekly/monthly top papers
opencliz hf top --period weekly
opencliz hf top --period monthly

# JSON output
opencliz hf top -f json
```

### Options

| Option | Description |
|--------|-------------|
| `--limit` | Number of papers (default: 20) |
| `--all` | Return all papers, ignoring limit |
| `--date` | Date in `YYYY-MM-DD` format (defaults to most recent) |
| `--period` | Time period: `daily`, `weekly`, or `monthly` (default: daily) |

## Prerequisites

- No browser required — uses public Hugging Face API
