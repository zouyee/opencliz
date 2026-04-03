# npm

**Mode**: 🌐 Public · **Domain**: `registry.npmjs.org` / `api.npmjs.org`

Cookie（可选）：`OPENCLI_NPM_COOKIE`（经 `hostToSiteKey` 映射为站点 `npm`）。

## Commands

| Command | Description |
|---------|-------------|
| `opencli npm search` | Search packages |
| `opencli npm info` | Package latest manifest |
| `opencli npm downloads` | Weekly download point |

## Examples

```bash
opencli npm search --query react -f json
opencli npm info --package lodash -f json
```
