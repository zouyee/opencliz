# Article / Markdown pipeline (phase E)

> **English (Zig port)**: Article/Markdown export vs upstream Turndown is summarized in **[`CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md`](CURRENT_CAPABILITIES_AND_UPSTREAM_DIFF.md)** §2.5 and this file.

> **Goal**: Match TS “export readable Markdown” **shape**, not Turndown rule-by-rule parity.

## Current Zig behavior (summary)

| Capability | Description |
|------------|-------------|
| Default body | `article_pipeline`: plain text + frontmatter (`---` / source URL / title) |
| Optional disk | Command-level `--output` etc. (per adapter) |
| External HTML→MD | Set executable **`OPENCLI_HTML_TO_MD_SCRIPT`**: input path `.opencli/article-html-input.html`, stdout = Markdown body (**preferred** over built-in) |
| Built-in simplified HTML→MD | Set **`OPENCLI_BUILTIN_HTML_TO_MD=1`** and no successful external script: `src/adapters/html_to_md_simple.zig` — blocks include **`<h1>`–`<h6>`, `<p>`, `<li>`, `<br>`, `<pre>`, `<blockquote>`, `<hr>` (`---`), minimal `<table>` (GFM header row)**; inside those blocks, **`<a href>`** and inline **strong/b/em/i/code/del/s/strike/img/comment** share one inline path (batch **60**, see **`MIGRATION_GAP.md`**) — **not** Turndown-grade |
| In-body images | **`OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1`**: with `output`, try to download absolute URL images to `article-images/` and add Markdown refs |

## Differences vs TS upstream

- No embedded Turndown; fine rules need **`OPENCLI_HTML_TO_MD_SCRIPT`** or optional built-in; **`<blockquote>`** runs inline Markdown first then **`> `** per line (nested block HTML still weak); tables/complex lists weaker than Turndown.
- Image path is “limited download”, not the legacy full media pipeline.

## Recommended toolchain

Any CLI/HTML→MD tool can be wrapped as **`OPENCLI_HTML_TO_MD_SCRIPT`** (contract below).

### `OPENCLI_HTML_TO_MD_SCRIPT` contract

- Zig invokes: `argv = [ script path, ".opencli/article-html-input.html" ]` (see **`article_pipeline.runHtmlToMdScript`**).
- Script reads the HTML path, prints Markdown on **stdout**, **exit 0** on success.

### Repo example: Pandoc wrapper

**`examples/html_to_md_pandoc_wrap.sh`** (needs **`pandoc`**):

```bash
chmod +x examples/html_to_md_pandoc_wrap.sh
export OPENCLI_HTML_TO_MD_SCRIPT="$PWD/examples/html_to_md_pandoc_wrap.sh"
# then run opencliz commands that export article/HTML
```

(For Turndown-like rules, use a small **`turndown`** script run by **Bun** or any CLI with the same stdin/stdout contract; not bundled in this repo.)

---

## H.4 / Wave 4: checklist vs TS upstream (L5, ongoing)

> **Goal**: Testable UX alignment, not Turndown or legacy media 1:1.

| Check | Zig lever | Side-by-side with TS |
|-------|-----------|----------------------|
| Body source | Default text + frontmatter; `OPENCLI_HTML_TO_MD_SCRIPT` first | TS may default Turndown; diff readability not bytes |
| Built-in HTML→MD | `OPENCLI_BUILTIN_HTML_TO_MD=1` (batch **60** inline + in-block) | Still not Turndown ruleset; tables/lists weaker |
| Images | `OPENCLI_ARTICLE_DOWNLOAD_IMAGES=1` + export with `output` | TS may add proxy/cache layers |
| Acceptance log | Structured `status` / empty body | Record drift in `MIGRATION_GAP` or issues |

---

*Phase E baseline; **H.4** evolves with L5; built-in converter batches **55/60** in **`MIGRATION_GAP.md`**.*
