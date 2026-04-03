# Barchart

**Mode**: 🔐 Browser · **Domain**: `barchart.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz barchart quote` | Stock quote with price, volume, and key metrics |
| `opencliz barchart options` | Options chain with greeks, IV, volume, and open interest |
| `opencliz barchart greeks` | Options greeks overview (IV, delta, gamma, theta, vega) |
| `opencliz barchart flow` | Unusual options activity / options flow |

## Usage Examples

```bash
# Get stock quote
opencliz barchart quote AAPL

# View options chain
opencliz barchart options TSLA

# Options greeks overview
opencliz barchart greeks NVDA

# Unusual options flow
opencliz barchart flow --limit 20 -f json
```

## Prerequisites

- Chrome running and able to open `barchart.com`
- [Browser Bridge extension](/guide/browser-bridge) installed
