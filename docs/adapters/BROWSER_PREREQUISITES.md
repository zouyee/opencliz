# Browser prerequisites: TypeScript upstream vs Zig port (`opencliz`)

Many per-site adapter pages under **`adapters/browser/`** were written for the **TypeScript** OpenCLI workflow and list the **Browser Bridge** Chrome extension.

## TypeScript upstream ([jackwener/opencli](https://github.com/jackwener/opencli))

Typically: Chrome running + **Browser Bridge** extension + local daemon — as in upstream docs.

## This repository (Zig build)

**No Browser Bridge extension is used.**

1. Try **HTTP** paths and cookie env vars first (`OPENCLI_COOKIE`, site-specific vars — see **`../AUTH_AND_WRITE_PATH.md`**).
2. For commands marked **`browser: true`** that need a rendered DOM or lazy-loaded content, set **`OPENCLI_USE_BROWSER=1`**. The CLI uses **CDP**:
   - default: spawn Chrome with remote debugging, or  
   - **`OPENCLI_CDP_WEBSOCKET`**: connect to an external **`ws://`** CDP server (e.g. Lightpanda).
3. Read **`../CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** and **`../advanced/cdp.md`** for tunnels, env vars, and limitations (**`wss://`** not supported yet).

Individual adapter pages may still mention the extension; treat those lines as **upstream-oriented** unless the page has been updated with a Zig-specific prerequisites block.
