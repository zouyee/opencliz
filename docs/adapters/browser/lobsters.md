# Lobsters

**Mode**: 🌐 Public · **Domain**: `lobste.rs`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz lobsters hot` | Hottest stories |
| `opencliz lobsters newest` | Latest stories |
| `opencliz lobsters active` | Most active discussions |
| `opencliz lobsters tag` | Stories by tag |

## Usage Examples

```bash
# Quick start
opencliz lobsters hot --limit 10

# Filter by tag
opencliz lobsters tag --tag rust --limit 5

# JSON output
opencliz lobsters hot -f json

# Verbose mode
opencliz lobsters hot -v
```

## Prerequisites

None — all commands use the public JSON API, no browser or login required.
