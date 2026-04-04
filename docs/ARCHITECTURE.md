# Architecture & design (opencliz)

This document is the **project-level design record** for how **opencliz** is structured. It states the technology choices for **this repository’s implementation** and how they differ from the **upstream** [jackwener/opencli](https://github.com/jackwener/opencli) (TypeScript / npm / Node.js).

**Detailed runtime rules** (env vars, execution diagram, subprocess policy): **`RUNTIME_MODEL.md`**.

---

## 1. Design decision: **Zig + Bun — no Node.js in our implementation**

| Layer | Technology | Role |
|-------|------------|------|
| **Core CLI & adapters** | **Zig** | Single static binary: command routing, HTTP, YAML pipelines, CDP client, daemon, registry, most adapter logic. Built with **`zig build`**. |
| **Embedded plugin scripts** | **QuickJS** (via zig-quickjs-ng) | `plugin.yaml` **`script`** / **`js_init`**: lightweight JS with injected **`opencli`** API; **not** a full browser or Node runtime. |
| **Legacy `type: ts` manifests** | **Bun** (optional subprocess) | Only when **`OPENCLI_ENABLE_BUN_SUBPROCESS=1`**: run **`bun <modulePath>`** and parse stdout JSON. **Node is not spawned.** |
| **Docs site & JS CI** | **Bun** | Root **`package.json`**: VitePress build, Vitest placeholders, **`bun.lock`**. GitHub Actions use **`oven-sh/setup-bun`**, not `setup-node`. |

**Conclusion (normative for this repo):** In **our implementation**, **Node.js is not required and not invoked** by the **`opencliz`** binary or by the **documented** CI/docs toolchain. Any mention of Node in parity docs refers to **upstream OpenCLI** or **optional** maintainer tools (e.g. `OPENCLI_UPSTREAM_CLI_RUNNER=npx` for baseline capture), not to opencliz itself.

---

## 2. One-line stack summary

```
opencliz = Zig (executable) + QuickJS (in-process plugins) + optional Bun (ts_legacy + repo tooling)
```

---

## 3. Boundary vs upstream (Node / npm)

| | **Upstream OpenCLI** | **opencliz (this repo)** |
|--|----------------------|---------------------------|
| Primary runtime | Node.js + npm packages | **Zig binary** |
| TS adapters in manifest | Often run under Node | **`ts_legacy`** stub or **Bun** subprocess |
| Plugin story | Node ecosystem | **QuickJS** subset + **`opencli.http`** allowlist |
| npm | Package manager for `opencli` | **Not** used to run `opencliz`; **`npm` site** commands are HTTP adapters to registry APIs |

---

## 4. Related documents

| Document | Content |
|----------|---------|
| **`RUNTIME_MODEL.md`** | Policy table, execution paths, Bun env vars, baseline scripts |
| **`PLUGIN_QUICKJS.md`** | QuickJS API, breaking change from removed Node subprocess |
| **`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`** | Feature-level diff vs upstream |
| **`CAPABILITY_MIGRATION_MAP.md`** | L0–L7 migration status vs OpenCLI |
| **`README.md`** | User-facing quick start and links |

---

*Maintainers: when changing subprocess or JS toolchain policy, update this file and **`RUNTIME_MODEL.md`** in the same change.*
