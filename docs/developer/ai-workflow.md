# AI Workflow（Zig opencli）

探索 → JSON → 合成 YAML → 用户目录注册；与上游 Node 版 CLI 参数**不完全相同**，以本仓库 **`opencli --help`** 为准。

## 一键：`--generate`

对 URL 做 HTTP 探索，写：

- `~/.opencli/explore/<site>.json` — 完整探索结果（与 `synthesize --explore` 同格式）
- `~/.opencli/clis/<site>/adapter.yaml` — 多命令 YAML（根级 `commands:`，启动时 discovery 加载）

```bash
opencli --generate https://example.com --site mysite
```

**注册**：用户 YAML 在进程启动时扫描；新开一次 `opencli` 或执行任意子命令以加载。

## 分步

### 1. 探索 + JSON

```bash
opencli --explore https://example.com --explore-out ./explore.json
# 或仅 JSON：
opencli -f json --explore https://example.com > explore.json
```

### 2. 合成

```bash
opencli synthesize --explore ./explore.json --site mysite --top 5
```

输出：`~/.opencli/clis/mysite/adapter.yaml`。

### 3. 认证探测（public → cookie → header）

内置若干站点的探针 URL；其它站点须显式 `--url`：

```bash
opencli cascade --site github
opencli cascade --site myapi --url https://api.example.com/v1/status
```

依据环境变量：`OPENCLI_COOKIE` / `OPENCLI_<SITE>_COOKIE`、`OPENCLI_<SITE>_TOKEN` / `GITHUB_TOKEN` / `OPENCLI_BEARER_TOKEN`。

### 4. 校验与试跑

```bash
opencli validate --path ~/.opencli/clis/mysite/adapter.yaml
opencli mysite/<command> -f json
```

## 上游文档

jackwener/opencli 的 `CLI-ONESHOT.md` / `CLI-EXPLORER.md` 描述的是 **TypeScript 版**交互；本 Zig 版以 **`docs/TS_PARITY_MIGRATION_PLAN.md`** L7 与本文为准。
