# Runtime model and plugin design (opencliz)

This document is the **detailed** companion to **`ARCHITECTURE.md`** (project architecture: **Zig + Bun + QuickJS**; **our implementation does not use Node.js**).

It describes how **opencliz** runs code at runtime, and how that differs from the **upstream** TypeScript OpenCLI ([jackwener/opencli](https://github.com/jackwener/opencli)), which ships on **npm** and assumes **Node.js**.

---

## 1. Policy: **Node is not used by opencliz**

| Topic | Policy |
|-------|--------|
| **Node.js** | **Not invoked** by this repository’s binary for any built-in path. The previous optional **`OPENCLI_ENABLE_NODE_SUBPROCESS`** / **`node <modulePath>`** flow is **removed**. |
| **npm / `node_modules`** | **Not required** to run **`opencliz`**. The Zig binary links QuickJS-ng and optional native deps via **`build.zig.zon`**; there is no runtime npm tree inside opencliz. |
| **Bun** | **Optional**, **only** for legacy **`cli-manifest.json`** entries with **`type: ts`** (`source=ts_legacy`). Enable with **`OPENCLI_ENABLE_BUN_SUBPROCESS=1`** and **`bun` on `PATH`**. See **`PLUGIN_QUICKJS.md`**. |
| **QuickJS** | **Default** embedded JS engine for **`plugin.yaml`** per-command **`script`** / **`js_init`**. Not a Node replacement; API surface is **`opencli`** + optional **`opencli.http`** (allowlisted). |

**Upstream** OpenCLI remains a **Node/TypeScript** product for comparison and parity scripts; that does **not** imply opencliz embeds Node.

---

## 2. Execution paths (summary)

```
CLI argv
   │
   ├─► internal / adapter / yaml pipeline / external CLI  →  Zig (+ HTTP / CDP as configured)
   │
   ├─► plugin + script                                     →  QuickJS (`evalPluginHandlerBody`, `PLUGIN_QUICKJS.md`)
   │
   └─► ts_legacy (`type: ts` from manifest)
         ├─ default                                      →  JSON stub `ts_adapter_not_supported`
         └─ OPENCLI_ENABLE_BUN_SUBPROCESS=1 + bun        →  `bun <modulePath> …` → stdout JSON
```

---

## 3. Environment variables (Bun subprocess only)

| Variable | Meaning |
|----------|---------|
| **`OPENCLI_ENABLE_BUN_SUBPROCESS`** | Set to **`1`** to run **`ts_legacy`** modules with **`bun`**. |
| **`OPENCLI_BUN_SUBPROCESS_TIMEOUT_MS`** | Child wall time before SIGKILL (POSIX); **`0`** disables timeout. |
| **`OPENCLI_BUN_MAX_OUTPUT_BYTES`** | Cap on stdout read size. |

Non-zero exit from the child is surfaced as **`status: "bun_error"`** in JSON.

---

## 4. User-supplied external scripts

Pipelines may call **`OPENCLI_HTML_TO_MD_SCRIPT`** or similar hooks: those are **separate processes** chosen by the user (shell, **Bun**, Deno, etc.). opencliz does **not** require Node for them.

---

## 5. Parity / baseline tooling

Scripts such as **`scripts/record_jackwener_baseline.sh`** may still invoke **upstream** `opencli` via **`npx`** or **`bunx @jackwener/opencli`** — that runs the **reference** CLI on your machine, not inside **opencliz**. Prefer **Bun** for local tooling if you want to avoid Node on your dev box:

```bash
bunx @jackwener/opencli <args>
```

---

## 6. Related documents

| Doc | Role |
|-----|------|
| **`ARCHITECTURE.md`** | **Project architecture / 设计方案** (this doc’s parent summary) |
| **`PLUGIN_QUICKJS.md`** | QuickJS API, **`opencli.http`**, Bun subprocess details |
| **`TS_PARITY_MIGRATION_PLAN.md`** | Phase B / L6 and migration layers |
| **`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** | Product vs upstream |
| **`TS_PARITY_99_CAP.md`** | What we do not promise |

---

*Last updated: 2026-04-04 — bump when changing subprocess policy or env names; keep in sync with **`ARCHITECTURE.md`**.*
