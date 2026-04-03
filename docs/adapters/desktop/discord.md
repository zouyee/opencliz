# Discord

Control the **Discord Desktop App** from the terminal via Chrome DevTools Protocol (CDP).

## Prerequisites

Launch with remote debugging port:
```bash
/Applications/Discord.app/Contents/MacOS/Discord --remote-debugging-port=9232
```

## Setup

```bash
export OPENCLI_CDP_ENDPOINT="http://127.0.0.1:9232"
```

## Commands

| Command | Description |
|---------|-------------|
| `opencliz discord-app status` | Check CDP connection |
| `opencliz discord-app send "message"` | Send a message in the active channel |
| `opencliz discord-app read` | Read recent messages |
| `opencliz discord-app channels` | List channels in the current server |
| `opencliz discord-app servers` | List all joined servers |
| `opencliz discord-app search "query"` | Search messages (Cmd+F) |
| `opencliz discord-app members` | List online members |
