# ChatWise

Control the **ChatWise Desktop App** from the terminal via Chrome DevTools Protocol (CDP). ChatWise is an Electron-based multi-LLM client supporting GPT-4, Claude, Gemini, and more.

## Prerequisites

1. Install [ChatWise](https://chatwise.app/).
2. Launch with remote debugging port:
   ```bash
   /Applications/ChatWise.app/Contents/MacOS/ChatWise \
     --remote-debugging-port=9228
   ```

## Setup

```bash
export OPENCLI_CDP_ENDPOINT="http://127.0.0.1:9228"
```

## Commands

### Diagnostics
- `opencliz chatwise status`: Check CDP connection status.
- `opencliz chatwise screenshot`: Export DOM + accessibility snapshot.

### Chat
- `opencliz chatwise new`: Start a new conversation (`Cmd+N`).
- `opencliz chatwise send "message"`: Send a message to the active chat.
- `opencliz chatwise read`: Read the current conversation.
- `opencliz chatwise ask "prompt"`: Send + wait for response + return it (one-shot).

### AI Features
- `opencliz chatwise model`: Get the current AI model.
- `opencliz chatwise model gpt-4`: Switch to a different model.

### Organization
- `opencliz chatwise history`: List conversations from the sidebar.
- `opencliz chatwise export`: Export conversation as Markdown.
