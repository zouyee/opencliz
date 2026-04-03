# npm

**Mode**: 🌐 Public · **Domain**: `registry.npmjs.org` / `api.npmjs.org`

Cookie (optional): `OPENCLI_NPM_COOKIE` (mapped to site `npm` via `hostToSiteKey`).

## Commands

| Command | Description |
|---------|-------------|
| `opencliz npm search` | Search packages |
| `opencliz npm info` | Package latest manifest |
| `opencliz npm downloads` | Weekly download point |

## Examples

```bash
opencliz npm search --query react -f json
opencliz npm info --package lodash -f json
```
