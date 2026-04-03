# Web

**Mode**: 🔐 Browser · **Domain**: any URL

## Commands

| Command | Description |
|---------|-------------|
| `opencliz web read <url>` | Fetch any web page and export as Markdown |

## Usage Examples

```bash
# Read a web page and save as Markdown
opencliz web read https://example.com/article

# Custom output directory
opencliz web read https://example.com/article --output ./my-articles

# Skip image download
opencliz web read https://example.com/article --download-images false

# JSON output
opencliz web read https://example.com/article -f json
```

## Prerequisites

- **TypeScript upstream** users: Chrome + [Browser Bridge extension](/guide/browser-bridge) (upstream docs).
- **This Zig port (`opencliz`)**: no extension. Use **`OPENCLI_USE_BROWSER=1`** and a CDP-capable browser (spawned Chrome, your own debugging Chrome, or **`OPENCLI_CDP_WEBSOCKET`**). See **`../../CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** and **`../../advanced/cdp.md`**.
