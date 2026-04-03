# External CLI Integration

OpenCLI can execute any external CLI command and format the output uniformly.

## Usage

```bash
opencli external/<name> <args...>

# Examples
opencli external/gh pr list              # GitHub PRs
opencli external/gh issue list           # GitHub Issues
opencli external/docker ps              # Docker containers
opencli external/docker images          # Docker images
```

## Output Formats

External commands support the same `-f` flag as built-in commands:

```bash
opencli external/gh pr list -f json     # JSON output
opencli external/gh pr list -f table     # Table output (default)
opencli external/gh pr list -f yaml     # YAML output
```

## Configuration

External CLIs are configured in `external-clis.yaml`:

**Project config:** `src/external-clis.yaml` (bundled)
**User config:** `~/.opencli/external-clis.yaml` (takes precedence)

### Format

```yaml
- name: gh
  binary: gh
  description: "GitHub CLI — repos, PRs, issues, releases, gists"
  homepage: "https://cli.github.com"
  tags: [github, git, dev]
  install:
    mac: "brew install gh"
    linux: "brew install gh"
    windows: "winget install GitHub.cli"

- name: docker
  binary: docker
  description: "Docker command-line interface"
  install:
    mac: "brew install --cask docker"
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Command name (used in `external/<name>`) |
| `binary` | Yes | Path or name of the executable |
| `description` | No | Human-readable description |
| `homepage` | No | Link to documentation |
| `tags` | No | Searchable tags |
| `install` | No | Installation commands by platform |

## Adding Custom External Commands

1. Create or edit `~/.opencli/external-clis.yaml`:

```yaml
- name: mytool
  binary: mytool
  description: "My custom CLI tool"
  install:
    mac: "brew install mytool"
```

2. Run `opencli list` to verify the command appears under `external/`

## How It Works

1. At startup, OpenCLI loads all `external-clis.yaml` files
2. Commands are registered under the `external/` namespace
3. When executed, OpenCLI:
   - Checks if the binary exists (fast-fail if not)
   - Passes all arguments through to the binary
   - Captures stdout and stderr
   - Formats output using the `-f` flag

## Built-in Examples

| Command | Description |
|---------|-------------|
| `external/gh` | GitHub CLI |
| `external/docker` | Docker CLI |
| `external/obsidian` | Obsidian vault CLI |
| `external/echo` | Echo command (testing) |
| `external/which` | Which command (testing) |
