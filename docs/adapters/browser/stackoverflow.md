# Stack Overflow

**Mode**: 🌐 Public · **Domain**: `stackoverflow.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz stackoverflow hot` | Hot questions |
| `opencliz stackoverflow search` | Search questions |
| `opencliz stackoverflow bounties` | Questions with active bounties |
| `opencliz stackoverflow unanswered` | Unanswered questions |

## Usage Examples

```bash
# Hot questions
opencliz stackoverflow hot --limit 10

# Search questions
opencliz stackoverflow search "async await" --limit 20

# Active bounties
opencliz stackoverflow bounties --limit 10

# Unanswered questions
opencliz stackoverflow unanswered --limit 10

# JSON output
opencliz stackoverflow hot -f json
```

## Prerequisites

- No browser required — uses public Stack Exchange API
