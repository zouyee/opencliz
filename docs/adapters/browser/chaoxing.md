# Chaoxing (learning platform)

**Mode**: 🔐 Browser · **Domain**: `mooc2-ans.chaoxing.com`

## Commands

| Command | Description |
|---------|-------------|
| `opencliz chaoxing assignments` | Assignment list |
| `opencliz chaoxing exams` | Exam list |

## Usage Examples

```bash
# List all assignments
opencliz chaoxing assignments --limit 20

# Filter exams by course name
opencliz chaoxing exams --course "Calculus"

# Filter exams by status
opencliz chaoxing exams --status ongoing

# JSON output
opencliz chaoxing assignments -f json
```

### Options

| Option | Description |
|--------|-------------|
| `--course` | Filter by course name (fuzzy match) |
| `--status` | Filter: `all`, `upcoming`, `ongoing`, `finished` |
| `--limit` | Max results (default: 20) |

## Prerequisites

- Chrome running and **logged into** mooc2-ans.chaoxing.com
- [Browser Bridge extension](/guide/browser-bridge) installed
