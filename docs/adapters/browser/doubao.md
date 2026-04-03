# doubao

Browser adapter for [Doubao Chat](https://www.doubao.com/chat).

## Commands

| Command | Description |
|---------|-------------|
| `opencliz doubao status` | Check whether the page is reachable and whether Doubao appears logged in |
| `opencliz doubao new` | Start a new Doubao conversation |
| `opencliz doubao send "..."` | Send a message to the current Doubao chat |
| `opencliz doubao read` | Read the visible Doubao conversation |
| `opencliz doubao ask "..."` | Send a prompt and wait for a reply |

## Prerequisites

- Chrome is running
- You are already logged into [doubao.com](https://www.doubao.com/)
- Playwright MCP Bridge / browser bridge is configured for OpenCLI

## Examples

```bash
opencliz doubao status
opencliz doubao new
opencliz doubao send "Summarize this document for me"
opencliz doubao read
opencliz doubao ask "Write a Python quicksort example" --timeout 90
```

## Notes

- The adapter targets the web chat page at `https://www.doubao.com/chat`
- `new` first tries the visible “New Chat” button (localized label on zh UI), then falls back to the new-thread route
- `ask` uses DOM polling, so very long generations may need a larger `--timeout`
