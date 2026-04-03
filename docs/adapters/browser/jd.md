# JD.com

**Mode**: 🔐 Browser · **Domain**: `item.jd.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz jd item <sku>` | Fetch product details (price, images, specs) |

## Usage Examples

```bash
# Get product details by SKU
opencliz jd item 100291143898

# Limit detail images
opencliz jd item 100291143898 --images 5

# JSON output
opencliz jd item 100291143898 -f json
```

## Prerequisites

- Chrome running and **logged into** jd.com
- [Browser Bridge extension](/guide/browser-bridge) installed
