# Cursor

Control the **Cursor IDE** from the terminal via Chrome DevTools Protocol (CDP). Since Cursor is built on Electron (VS Code fork), OpenCLI can drive its internal UI, automate Composer interactions, and manipulate chat sessions.

## Prerequisites

1. Install [Cursor](https://cursor.sh/).
2. Launch it with the remote debugging port:
   ```bash
   /Applications/Cursor.app/Contents/MacOS/Cursor --remote-debugging-port=9226
   ```

## Setup

```bash
export OPENCLI_CDP_ENDPOINT="http://127.0.0.1:9226"
```

## Commands

### Diagnostics
- `opencliz cursor status`: Check CDP connection status.
- `opencliz cursor dump`: Dump the full DOM and Accessibility snapshot to `/tmp/cursor-dom.html` and `/tmp/cursor-snapshot.json`.
- `opencliz cursor screenshot`: Capture DOM + snapshot artifacts of the current window.

### Chat Manipulation
- `opencliz cursor new`: Press `Cmd+N` to start a new file/tab.
- `opencliz cursor send "message"`: Inject text into the active Composer/Chat input and submit.
- `opencliz cursor ask "message"`: Send + wait + read in one shot.
- `opencliz cursor read`: Extract the full conversation history from the active chat panel.

### AI Features
- `opencliz cursor composer "prompt"`: Open the Composer panel (`Cmd+I`) and send a prompt for inline AI editing.
- `opencliz cursor model`: Get the currently active AI model (e.g., `claude-4.5-sonnet`).
- `opencliz cursor extract-code`: Extract all code blocks from the current conversation.
- `opencliz cursor history`: List recent chat/composer sessions from the sidebar.
- `opencliz cursor export`: Export the current conversation as Markdown.
