# jackwener/opencli parity — progress tracker

> **Upstream**: [jackwener/opencli](https://github.com/jackwener/opencli) (`@jackwener/opencli`) · **`docs/UPSTREAM_REFERENCE.md`**  
> **How to update**: flip **Status** when done; add **batch** notes in **`MIGRATION_GAP.md`** when needed.

---

## Legend

| Mark | Meaning |
|------|---------|
| ✅ | Delivered (code / docs / CI traceable) |
| 🔄 | In progress / ongoing |
| ⏳ | Scheduled, not started |
| ⛔ | Explicitly not targeted (**`TS_PARITY_99_CAP.md` §4**) |

---

## P0 — L2: public API shape and JSON drift control

| # | Task | Status | Deliverable / notes |
|---|------|--------|---------------------|
| P0.1 | Fixtures + `fixture_json_test` for high-traffic responses | ✅ | `tests/fixtures/json/` + **`src/tests/fixture_json_test.zig`** |
| P0.2 | Side-by-side diff tooling | ✅ | **`scripts/l2_p0_routine.sh`**, **`compare_command_json.sh --diff-ts`**, batch **61** |
| P0.3 | Manual CI entry | ✅ | **`.github/workflows/l2-json-parity-dispatch.yml`** |
| P0.4 | Record upstream JSON baseline (versioned) | 🔄 | **`scripts/record_jackwener_baseline.sh`**; fill **Baseline log** below with **npm version / commit** (needs network; after **P0.5** export, record real **`JACKWENER_OPENCLI_PKG`**) |
| P0.5 | Pick 5 commands, `jq -S` diff vs upstream, archive deltas | ✅ | **`scripts/parity_p0_5_export_zig.sh`**, **`parity_p0_5_export_upstream.sh`**, **`parity_p0_5_diff.sh`**; default output **`parity-output/{zig,ts}/`** (**.gitignore**d); summary in **Baseline log** or issues |

---

## P1 — L4 / L7: boundaries and daemon contract

| # | Task | Status | Deliverable / notes |
|---|------|--------|---------------------|
| P1.1 | L4 site read/write boundary matrix | ✅ | **`AUTH_AND_WRITE_PATH.md`** § P1 · batch **62** |
| P1.2 | Daemon auth / OPTIONS / TCP | ✅ | **`daemon_*_test`** · batch **62** |
| P1.3 | Unknown-command HTTP semantics vs REST / upstream | ✅ | Unregistered **`/execute`** → **404** + `Command not found` · batch **65** |

---

## P2 — L3 / L6: CDP CI and plugin HTTP

| # | Task | Status | Deliverable / notes |
|---|------|--------|---------------------|
| P2.1 | Zig + Chrome multi-scenario CI | ✅ | **`zig-chrome-ci.yml`** five scenarios + schedule · batch **63** |
| P2.2 | `opencli.http` error code table | ✅ | **`PLUGIN_QUICKJS.md`**, `http_error` · API **0.2.3** · batch **63** |

---

## P3 — L5 / UX: articles and media

| # | Task | Status | Deliverable / notes |
|---|------|--------|---------------------|
| P3.1 | Built-in HTML→MD increment (not Turndown) | ✅ | **`html_to_md_simple`** inline + blocks · batches **55/60** |
| P3.2 | External HTML→MD script first | ✅ | **`OPENCLI_HTML_TO_MD_SCRIPT`** · **`examples/html_to_md_pandoc_wrap.sh`** (Pandoc) · **`MARKDOWN_ARTICLE_PIPELINE.md`** examples |
| P3.3 | Image pipeline vs upstream article-download | ⛔ / ⏳ | Limited switches only; full pipeline **not** a goal or long backlog |

---

## P4 — Docs and baseline anchors

| # | Task | Status | Deliverable / notes |
|---|------|--------|---------------------|
| P4.1 | Upstream repo + npm spelled out | ✅ | **`UPSTREAM_REFERENCE.md`** · batch **64** |
| P4.2 | This progress tracker | ✅ | This file · batch **65** |

---

## Baseline log (update with P0.4 / P0.5)

| Date | @jackwener/opencli version / commit | Commands | Delta summary |
|------|-------------------------------------|----------|---------------|
| _TBD_ | _e.g. 1.6.1 or git SHA_ | _e.g. hackernews/top --limit 1_ | _none / field x differs_ |

---

## Next steps (order)

1. **P0.4**: On a networked machine run **`parity_p0_5_export_upstream.sh`** (or **`record_jackwener_baseline.sh`** alone); fill **Baseline log** with version/commit and deltas.  
2. **P0.5 regression**: Before releases or major upstream bumps run **`parity_p0_5_export_zig.sh`** → **`parity_p0_5_export_upstream.sh`** → **`parity_p0_5_diff.sh`** (optionally pin **`JACKWENER_OPENCLI_PKG`**).  
3. **P3.2**: Article export acceptance → **`MARKDOWN_ARTICLE_PIPELINE.md`** H.4; Turndown/Node wrappers remain user-supplied CLIs.  
4. **Upstream-only features** (extension bridge, default daemon port, full `operate`, sysexits): track only after **`UPSTREAM_REFERENCE.md`** + **`TS_PARITY_99_CAP.md`** review—avoid forcing 1:1 with current Zig architecture.

---

*Keep in sync with **`TS_PARITY_REMAINING.md` §3–§4**; after large features bump **`MIGRATION_GAP`** batch numbers.*
