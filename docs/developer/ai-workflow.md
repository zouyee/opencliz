# AI workflow (Zig opencliz)

Explore → JSON → synthesize YAML → user-dir registration; CLI flags **differ** from the upstream Node CLI—use **`opencliz --help`** in this repo.

## One shot: `--generate`

HTTP-explore a URL and write:

- `~/.opencli/explore/<site>.json` — full explore output (same shape as `synthesize --explore`)
- `~/.opencli/clis/<site>/adapter.yaml` — multi-command YAML (root `commands:`, loaded at startup discovery)

```bash
opencliz --generate https://example.com --site mysite
```

**Registration**: user YAML is scanned at process start; launch a new `opencliz` or run any subcommand to load it.

## Step by step

### 1. Explore + JSON

```bash
opencliz --explore https://example.com --explore-out ./explore.json
# or JSON only:
opencliz -f json --explore https://example.com > explore.json
```

### 2. Synthesize

```bash
opencliz synthesize --explore ./explore.json --site mysite --top 5
```

Output: `~/.opencli/clis/mysite/adapter.yaml`.

### 3. Auth probe (public → cookie → header)

Built-in probe URLs for some sites; others need explicit `--url`:

```bash
opencliz cascade --site github
opencliz cascade --site myapi --url https://api.example.com/v1/status
```

Env: `OPENCLI_COOKIE` / `OPENCLI_<SITE>_COOKIE`, `OPENCLI_<SITE>_TOKEN` / `GITHUB_TOKEN` / `OPENCLI_BEARER_TOKEN`.

### 4. Validate and try

```bash
opencliz validate --path ~/.opencli/clis/mysite/adapter.yaml
opencliz mysite/<command> -f json
```

## Upstream docs

jackwener/opencli’s `CLI-ONESHOT.md` / `CLI-EXPLORER.md` describe the **TypeScript** CLI; this Zig port follows **`docs/TS_PARITY_MIGRATION_PLAN.md`** L7 and this file.
