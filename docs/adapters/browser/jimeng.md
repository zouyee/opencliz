# Jimeng AI

**Mode**: 🔐 Browser · **Domain**: `jimeng.jianying.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz jimeng generate` | Text-to-image from a prompt |
| `opencliz jimeng history` | Generation history |

## Usage Examples

```bash
# Generate an image
opencliz jimeng generate --prompt "A cat under a starry sky"

# Use a specific model
opencliz jimeng generate --prompt "cyberpunk city" --model high_aes_general_v50

# Custom wait timeout
opencliz jimeng generate --prompt "sunset landscape" --wait 60

# View generation history
opencliz jimeng history --limit 10
```

### Options (generate)

| Option | Description |
|--------|-------------|
| `--prompt` | Image prompt (required) |
| `--model` | `high_aes_general_v50` (5.0 Lite), `high_aes_general_v42` (4.6), `high_aes_general_v40` (4.0) |
| `--wait` | Seconds to wait for generation (default: 40) |

## Prerequisites

- Chrome running and **logged into** jimeng.jianying.com
- [Browser Bridge extension](/guide/browser-bridge) installed
