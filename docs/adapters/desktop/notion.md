# Notion

Control the **Notion Desktop App** from the terminal via Chrome DevTools Protocol (CDP).

## Prerequisites

Launch with remote debugging port:
```bash
/Applications/Notion.app/Contents/MacOS/Notion --remote-debugging-port=9230
```

## Setup

```bash
export OPENCLI_CDP_ENDPOINT="http://127.0.0.1:9230"
```

## Commands

| Command | Description |
|---------|-------------|
| `opencliz notion status` | Check CDP connection |
| `opencliz notion search "query"` | Quick Find search (Cmd+P) |
| `opencliz notion read` | Read the current page content |
| `opencliz notion new "title"` | Create a new page (Cmd+N) |
| `opencliz notion write "text"` | Append text to the current page |
| `opencliz notion sidebar` | List pages from the sidebar |
| `opencliz notion favorites` | List pages from the Favorites section |
| `opencliz notion export` | Export page as Markdown |
