# phil-ai-workflow

A portable Claude Code plugin for managing work context across issue trackers, git branches, and task managers.

## Features

- **Cross-profile work tracking**: Scan and manage work across multiple project profiles (work, personal, play, home)
- **Unified workflow commands**: Start, finish, status, and resume work with consistent commands
- **Issue tracker integration**: GitHub, Jira, or no tracker - configurable per profile
- **Git branch automation**: Create feature branches with consistent naming conventions
- **OmniFocus integration**: Optional task creation for work items (macOS)
- **Metrics capture**: Track work events for velocity analysis

## Installation

### Via Plugin System (Recommended)

```bash
# Add the marketplace
/plugin marketplace add /path/to/phil-ai-workflow

# Install the plugin
/plugin install phil-ai-workflow@phil-ai-workflow-dev

# Restart Claude Code
```

### Via GitHub

```bash
/plugin marketplace add pjbeyer/phil-ai-workflow
/plugin install phil-ai-workflow@pjbeyer-phil-ai-workflow
```

## Commands

| Command | Description |
|---------|-------------|
| `/work-start [description]` | Create issue, branch, and task to begin new work |
| `/work-finish` | Close issue, cleanup branches, update task when complete |
| `/work-status` | Show active work across all profiles |
| `/work-resume [issue-id or branch]` | Restore context for specific work item |

## Configuration

### Profile Configuration

Each profile can be configured via `{profile}/.workflow/overrides.yaml`:

```yaml
profile_overrides:
  # Issue tracking: "github", "jira", or "none"
  issue_tracker: github

  # Include issue number in branch name?
  branch_prefix_issue: true

  # Auto-create OmniFocus tasks?
  auto_create_omnifocus_task: false

  # Auto-create documentation issues on completion?
  auto_create_doc_issues: false
```

### Plugin Profile Mapping

For plugin development in `~/.claude/plugins/cache/`, create `~/.config/workflow/plugin-profiles.yaml`:

```yaml
plugin_mappings:
  my-plugin: pjbeyer  # Maps plugin directory to profile
  work-plugin: work
```

## Directory Structure

```
phil-ai-workflow/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   └── marketplace.json     # Dev marketplace
├── skills/
│   └── workflow/
│       ├── SKILL.md         # Main skill documentation
│       ├── start.md         # Start operation
│       ├── finish.md        # Finish operation
│       ├── status.md        # Status operation
│       ├── resume.md        # Resume operation
│       ├── scripts/         # Utility scripts
│       └── reference/       # Conventions docs
├── commands/
│   ├── work-start.md
│   ├── work-finish.md
│   ├── work-status.md
│   └── work-resume.md
└── README.md
```

## Requirements

- Claude Code CLI
- Git
- GitHub CLI (`gh`) for GitHub integration
- macOS (for OmniFocus integration - optional)
- Bash 4+ (via Homebrew on macOS: `/opt/homebrew/bin/bash`)

## Usage Examples

### Starting New Work

```
/work-start Add user authentication feature
```

This will:
1. Detect your current profile
2. Create an issue (GitHub/Jira based on config)
3. Create a feature branch
4. Optionally create an OmniFocus task
5. Display next steps

### Checking Work Status

```
/work-status
```

Shows all active feature branches across profiles with:
- Branch names and associated issues
- Last commit timestamps
- Stale work warnings (>7 days)

### Resuming Work

```
/work-resume 123
/work-resume feature/123-user-auth
```

Finds and checks out the matching branch, shows issue context and recent commits.

### Finishing Work

```
/work-finish
```

Interactive workflow to:
1. Verify PR status
2. Close associated issue
3. Cleanup local/remote branches
4. Complete OmniFocus task
5. Record metrics

## Metrics

Work events are captured in `~/Projects/.workflow/metrics/{profile}-{YYYY-MM}.json`:

```json
{"event":"work_started","profile":"pjbeyer","date":"2025-12-07 10:30:00","issue":"123","branch":"feature/123-auth","type":"feature"}
{"event":"work_finished","profile":"pjbeyer","date":"2025-12-07 14:45:00","issue":"123","branch":"feature/123-auth"}
```

## License

MIT

## Author

Phil Beyer - [GitHub](https://github.com/pjbeyer)

## Related Projects

- [phil-ai](https://github.com/pjbeyer/phil-ai) - Personal AI infrastructure
- [phil-ai-docs](https://github.com/pjbeyer/phil-ai-docs) - Documentation suite
- [phil-ai-learning](https://github.com/pjbeyer/phil-ai-learning) - Learning capture system
- [phil-ai-context](https://github.com/pjbeyer/phil-ai-context) - Context optimization
