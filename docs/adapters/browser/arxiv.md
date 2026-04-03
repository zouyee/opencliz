# arXiv

**Mode**: 🌐 Public · **Domain**: `arxiv.org`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz arxiv search` | Search arXiv papers |
| `opencliz arxiv paper` | Get arXiv paper details by ID |

## Usage Examples

```bash
# Search for papers
opencliz arxiv search "transformer attention" --limit 10

# Get paper details by arXiv ID
opencliz arxiv paper 2301.00001

# JSON output
opencliz arxiv search "LLM" -f json
```

## Prerequisites

- No browser required — uses public arXiv API
