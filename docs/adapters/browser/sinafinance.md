# Sina Finance

**Mode**: 🌐 Public · **Domain**: `finance.sina.com.cn`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz sinafinance news` | Sina Finance 7×24 flash headlines |

## Usage Examples

```bash
# Latest financial news
opencliz sinafinance news --limit 20

# Filter by type
opencliz sinafinance news --type 1   # A-shares
opencliz sinafinance news --type 2   # Macro
opencliz sinafinance news --type 6   # International

# JSON output
opencliz sinafinance news -f json
```

### Options

| Option | Description |
|--------|-------------|
| `--limit` | Max results, up to 50 (default: 20) |
| `--type` | News type: `0`=all, `1`=A-shares, `2`=macro, `3`=company, `4`=data, `5`=market, `6`=international, `7`=opinion, `8`=central bank, `9`=other |

## Prerequisites

- No browser — public API
