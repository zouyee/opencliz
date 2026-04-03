# Xueqiu

**Mode**: 🔐 Browser · **Domain**: `xueqiu.com` / `danjuanfunds.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz xueqiu feed` | Home timeline |
| `opencliz xueqiu earnings-date` | Next / scheduled earnings dates for a symbol |
| `opencliz xueqiu hot-stock` | Hot stocks leaderboard |
| `opencliz xueqiu hot` | Hot posts feed |
| `opencliz xueqiu search` | Search stocks (ticker or name) |
| `opencliz xueqiu stock` | Real-time quote for a symbol |
| `opencliz xueqiu watchlist` | Your watchlist |
| `opencliz xueqiu fund-holdings` | Danjuan fund holdings (optional `--account` for a sub-account) |
| `opencliz xueqiu fund-snapshot` | Danjuan snapshot (total assets, sub-accounts, positions; use `-f json`) |

## Usage Examples

```bash
# Quick start
opencliz xueqiu feed --limit 5

# Search stocks
opencliz xueqiu search Moutai

# View one stock
opencliz xueqiu stock SH600519

# Upcoming earnings dates
opencliz xueqiu earnings-date SH600519 --next

# Danjuan all holdings
opencliz xueqiu fund-holdings

# Filter one Danjuan sub-account
opencliz xueqiu fund-holdings --account "Default"

# Full Danjuan snapshot as JSON
opencliz xueqiu fund-snapshot -f json

# JSON output
opencliz xueqiu feed -f json

# Verbose mode
opencliz xueqiu feed -v
```

## Prerequisites

- Chrome running and **logged into** `xueqiu.com`
- For fund commands, Chrome must also be logged into `danjuanfunds.com` and able to open `https://danjuanfunds.com/my-money`
- [Browser Bridge extension](/guide/browser-bridge) installed

## Notes

- `fund-holdings` exposes both market value and share fields (`volume`, `usableRemainShare`)
- `fund-snapshot -f json` is the easiest way to persist a full account snapshot for later analysis or diffing
- If the commands return empty data, first confirm the logged-in browser can directly see the Danjuan asset page
