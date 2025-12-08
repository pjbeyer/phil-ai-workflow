---
name: workflow
description: Orchestrate work tracking with issues, branches, and tasks across profiles. Use when managing work context, creating branches, tracking progress, or switching between tasks.
---

# Workflow Orchestration

This skill provides four operations for managing work context across issue trackers, git branches, and task managers:

- **start**: Create issue, branch, and task to begin new work
- **finish**: Close issue, cleanup branches, update task when work complete
- **status**: Show active work across all profiles
- **resume**: Restore context for specific work item

## Architecture

**Commands invoke this skill**:
- `/work-start` → reads `start.md`
- `/work-finish` → reads `finish.md`
- `/work-status` → reads `status.md`
- `/work-resume` → reads `resume.md`

**Skill provides**:
- Shared utility functions (this file)
- Operation-specific orchestration (operation files)
- Reference implementations (for new users)

## Scope and Limitations

**Profile-based operations**: Workflow commands operate on repositories within profile directories (`~/Projects/{work,pjbeyer,play,home}/*`).

**Root-level infrastructure**: Repositories at `~/Projects/.workflow`, `~/Projects/dotfiles`, etc. are NOT searched by `/work-resume` or `/work-status`. These must be navigated to manually via `cd`.

## Working Directory Confirmation

**IMPORTANT**: Workflow operations should confirm and establish the working directory context before executing any scripts or commands.

**Why this matters**:
- Users often start Claude from `~/Projects` or profile directories to leverage optimized settings
- The actual work may be in a subdirectory or plugin cache directory
- Silent assumptions about working directory can lead to operations affecting the wrong repository

**Required behavior for all workflow operations**:

1. **Display current context**:
   ```
   Current directory: /Users/pjbeyer/Projects
   Detected profile: pjbeyer
   ```

2. **For /work-start**: Confirm target directory
   - If in a git repository: "Start work in this repository?"
   - If not in git repo but in plugin/project dir: "Navigate to correct directory first"
   - Allow user to specify different directory if needed

3. **For /work-status**: Display where status is being checked
   - Show all active work across profiles
   - Indicate which directories were searched
   - Allow filtering by profile or directory

4. **For /work-resume**: Confirm which repository to work in
   - Show available work items with their directories
   - Change to selected directory before restoring context
   - Verify directory exists before switching

5. **For /work-finish**: Confirm correct repository
   - Display current branch and repository
   - Verify this matches work being finished
   - Prevent finishing work in wrong directory

**Implementation approach**:
- Use `pwd` at start of each operation
- Display to user for confirmation
- Use AskUserQuestion if ambiguity exists
- Change directory explicitly before running git/gh commands
- Use absolute paths in all script calls

## Utility Scripts

All operations use standalone executable scripts located in `${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/`.

**Design Principles:**
- Scripts write results to stdout, errors to stderr
- Exit 0 if script executes successfully (even if result is "unknown" or empty)
- Exit 1+ only for execution failures (missing file, syntax error, etc.)
- Operations contain logic to interpret results

**Deprecated:** Legacy `workflow-utils.sh` at `~/Projects/.workflow/scripts/` is no longer used.

### Profile Detection

Detect which profile the user is working in. Supports three detection modes:

1. **Plugin cache directories**: `~/.claude/plugins/cache/*` (via mapping file)
2. **Projects root infrastructure**: `~/Projects/*` (non-profile subdirectories → pjbeyer)
3. **Profile subdirectories**: `~/Projects/{work,pjbeyer,play,home}/*`

```bash
profile=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/detect-profile.sh)
# Returns: "work", "pjbeyer", "play", "home", or "unknown"

if [[ "$profile" == "unknown" ]]; then
    cwd=$(pwd)

    # Check if we're in a plugin directory
    if [[ "$cwd" == */.claude/plugins/cache/* ]]; then
        plugin_name=$(echo "$cwd" | sed -n 's|.*/.claude/plugins/cache/\([^/]*\).*|\1|p')

        echo "❌ Error: Plugin '$plugin_name' not mapped to a profile"
        echo ""
        echo "To use workflow commands in plugin directories, add a mapping:"
        echo ""
        echo "1. Create/edit: ~/.config/workflow/plugin-profiles.yaml"
        echo "2. Add mapping:"
        echo "   plugin_mappings:"
        echo "     $plugin_name: work  # or pjbeyer, play, home"
        echo ""
        echo "Then try again."
        exit 1
    else
        echo "❌ Error: Not in a known profile or plugin directory"
        echo "Expected: ~/Projects/{work,pjbeyer,play,home}/"
        echo "      or: ~/.claude/plugins/cache/*/"
        exit 1
    fi
fi
```

**Plugin Mapping File** (`~/.config/workflow/plugin-profiles.yaml`):
```yaml
plugin_mappings:
  infra-security-plugin: work
  agents-learning-system: pjbeyer
  superpowers: pjbeyer
```

### Git Repository Functions

**Check if in git repository**:
```bash
in_repo=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/in-git-repo.sh)
if [[ "$in_repo" == "false" ]]; then
    echo "Error: Not in a git repository"
    exit 1
fi
```

**Get current branch**:
```bash
current=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/current-branch.sh)
# Returns: branch name like "feature/123-description" or empty string
```

**Get repository root**:
```bash
repo=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/repo-root.sh)
# Returns: /Users/pjbeyer/Projects/profile/project or empty string
```

### Configuration Loading

Load profile-specific configuration from `{profile}/.workflow/overrides.yaml`:

```bash
issue_tracker=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" issue_tracker)
# Returns: "github", "jira", "none", or empty string

branch_prefix_issue=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" branch_prefix_issue)
[[ -z "$branch_prefix_issue" ]] && branch_prefix_issue="false"
# Returns: "true" or "false"

auto_create_task=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" auto_create_omnifocus_task)
[[ -z "$auto_create_task" ]] && auto_create_task="false"
# Returns: "true" or "false"
```

**Configuration file structure** (`{profile}/.workflow/overrides.yaml`):
```yaml
profile_overrides:
  issue_tracker: github  # or: jira, none
  branch_prefix_issue: true
  auto_create_omnifocus_task: true
```

### GitHub Integration

**Check authentication**:
```bash
authenticated=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/gh-authenticated.sh)
if [[ "$authenticated" == "false" ]]; then
    echo "Error: gh CLI not authenticated"
    echo "Run: gh auth login"
    exit 1
fi
```

**Get repository name**:
```bash
repo=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-github-repo.sh)
# Returns: "owner/repo-name" or empty string

if [[ -z "$repo" ]]; then
    echo "Error: Could not detect GitHub repo"
    exit 1
fi
```

**Extract issue from branch name**:
```bash
issue=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/extract-issue-from-branch.sh "$branch_name")
# Returns: "123" from "feature/123-description"
# Returns: "PROJ-123" from "feature/PROJ-123-description"
# Returns: empty string if no issue found
```

### Date/Time Formatting

**For metrics and logs**:
```bash
date=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/format-date.sh)
# Returns: "2025-11-15"

datetime=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/format-datetime.sh)
# Returns: "2025-11-15 08:30:45"
```

### Superpowers Detection

**Purpose**: Detect if superpowers plugin is available for skill orchestration.

Check if superpowers plugin exists:

```bash
has_superpowers() {
    if [[ -d ~/.claude/plugins/cache/superpowers ]]; then
        return 0
    else
        return 1
    fi
}
```

**Suggest superpowers skill** when appropriate:

```bash
suggest_superpowers_skill() {
    local skill_name=$1
    local context=$2

    if ! has_superpowers; then
        return 0
    fi

    echo ""
    echo "💡 Superpowers skill available: $skill_name"
    echo "   Context: $context"
    echo "   Invoke: Use the Skill tool with 'superpowers:$skill_name'"
    echo ""
}
```

**Usage examples**:

```bash
# Check if superpowers available
if has_superpowers; then
    echo "Superpowers plugin detected"
fi

# Suggest TDD for feature work
if has_superpowers; then
    suggest_superpowers_skill "test-driven-development" \
        "Write tests before implementation to ensure correctness"
fi

# Suggest systematic debugging for bug fixes
if has_superpowers; then
    suggest_superpowers_skill "systematic-debugging" \
        "Root cause investigation before proposing fixes"
fi
```

**Integration points**:
- `/work-start`: Suggest TDD for feature/refactor work
- `/work-start`: Suggest systematic-debugging for bug fixes
- `/work-finish`: Invoke code-review for code changes
- `/work-finish`: Invoke finishing-a-development-branch after review

**Graceful degradation**: If superpowers not available, workflow commands work normally without skill suggestions.

## Issue Tracker Integration

### GitHub (profiles: pjbeyer, play)

**Create issue**:
```bash
issue_url=$(gh issue create \
    --repo "$repo" \
    --title "${type}: ${title}" \
    --body "$body" \
    --label "${type}" \
    | grep -o 'https://.*')

issue_number=$(echo "$issue_url" | grep -oE '[0-9]+$')
```

**Close issue**:
```bash
gh issue close "$issue_number" --repo "$repo" --comment "Completed via /work-finish"
```

### Jira (profile: work)

**Create issue** (manual via AskUserQuestion):
- Prompt user to create Jira task manually in their project board
- Ask for Jira issue key (format: PROJ-123)
- Validate format: `[A-Z]+-[0-9]+`
- Construct URL: `https://your-jira.atlassian.net/browse/$jira_key`

**Close issue** (manual):
- Prompt user to manually transition Jira task to "Done"
- Provide link to issue for convenience

### None (profile: home)

```bash
issue_number="none"
issue_url=""
echo "✓ No issue tracker configured"
```

## Branch Naming Conventions

### Pattern

Based on `.workflow/core/branch-strategy.md` (or fallback to `reference/branch-strategy.md`):

**With issue prefix** (when `branch_prefix_issue: true`):
```
{type}/{issue}-{sanitized-description}
# Examples:
# feature/123-add-user-auth
# fix/456-broken-login
# refactor/PROJ-789-cleanup-api
```

**Without issue prefix** (when `branch_prefix_issue: false` or `issue_number: "none"`):
```
{type}/{sanitized-description}
# Examples:
# feature/add-user-auth
# fix/broken-login
# docs/update-readme
```

### Sanitization

```bash
# Convert to lowercase, replace spaces with hyphens, remove special chars
branch_desc=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-50)
```

## OmniFocus Integration

### When Enabled

Check profile config:
```bash
auto_create_task=$(get_profile_config "$profile" auto_create_omnifocus_task || echo "false")
```

### Create Task

```bash
task_note="Issue: $issue_url
Branch: $branch_name
Repository: $(repo_root)

Started: $(format_datetime)"

osascript <<EOF
tell application "OmniFocus"
    tell default document
        set newTask to make new inbox task with properties {name:"${type}: ${title}", note:"${task_note}"}
    end tell
end tell
EOF
```

### Complete Task

Find task by name pattern and mark complete:
```bash
osascript <<EOF
tell application "OmniFocus"
    tell default document
        set matchingTasks to flattened tasks whose name contains "${title}"
        repeat with aTask in matchingTasks
            set completed of aTask to true
        end repeat
    end tell
end tell
EOF
```

### Error Handling

If OmniFocus not running or AppleScript fails:
- Show warning message
- Continue workflow (task creation is optional)

## Metrics Capture

### Location

```bash
metrics_dir="/Users/pjbeyer/Projects/.workflow/metrics"
metrics_file="$metrics_dir/$profile-$(date +%Y-%m).json"
```

### Format

JSON Lines format (one event per line):

**work_started event**:
```json
{
  "event": "work_started",
  "profile": "work",
  "date": "2025-11-15 08:30:45",
  "issue": "123",
  "branch": "feature/123-description",
  "type": "feature"
}
```

**work_finished event**:
```json
{
  "event": "work_finished",
  "profile": "work",
  "date": "2025-11-15 10:45:12",
  "issue": "123",
  "branch": "feature/123-description",
  "duration_minutes": 135
}
```

### Recording

```bash
mkdir -p "$metrics_dir"
echo "$json_event" >> "$metrics_file"
```

## Interactive Prompts

Use **AskUserQuestion tool**, not bash `read` commands.

### Work Type Selection

```
Header: "Type"
Question: "What type of work is this?"
Options:
  - feature: "New functionality"
  - fix: "Bug fix"
  - refactor: "Code restructuring"
  - docs: "Documentation only"
  - test: "Test improvements"
  - chore: "Maintenance tasks"
```

### Uncommitted Changes Warning

If `git status --porcelain` shows changes:
```
Question: "You have uncommitted changes. Stash them before starting new work?"
Options:
  - Yes: Run `git stash push -m "WIP: before starting new work"`
  - No: Continue with uncommitted changes
```

### Base Branch Selection

If not on main/master:
```
Question: "Currently on: {current_branch}. Switch to main before creating feature branch?"
Options:
  - Yes: `git checkout main` (or master)
  - No: Create branch from current
```

## Error Handling

### Git Errors

```bash
if [[ $? -ne 0 ]]; then
    echo "✗ Git command failed"
    echo "Output: $(git status 2>&1)"
    exit 1
fi
```

### gh CLI Errors

```bash
if ! gh_authenticated; then
    echo "Error: gh CLI not authenticated"
    echo "Run: gh auth login"
    echo "Or set issue_tracker: none in profile config"
    exit 1
fi
```

### Config Errors

```bash
if [[ ! -f "/Users/pjbeyer/Projects/$profile/.workflow/overrides.yaml" ]]; then
    echo "Warning: No config file for $profile profile"
    echo "Using defaults or falling back to reference implementation"
fi
```

## Fallback to Reference Implementations

If user doesn't have `.workflow/core/` specs:

```bash
if [[ ! -f "/Users/pjbeyer/Projects/.workflow/core/branch-strategy.md" ]]; then
    echo "ℹ️  Using reference branch strategy"
    echo "To customize: Copy ${CLAUDE_PLUGIN_ROOT}/skills/workflow/reference/branch-strategy.md"
    echo "           to ~/Projects/.workflow/core/branch-strategy.md"
fi
```

## Common Patterns

### Start of Operation

```bash
# Detect profile
profile=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/detect-profile.sh)
if [[ "$profile" == "unknown" ]]; then
    echo "Error: Not in a known profile directory"
    exit 1
fi

# Verify git repo
in_repo=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/in-git-repo.sh)
if [[ "$in_repo" == "false" ]]; then
    echo "Error: Not in a git repository"
    exit 1
fi
```

### End of Operation

```bash
# Record metrics
mkdir -p "/Users/pjbeyer/Projects/.workflow/metrics"
echo "$json_event" >> "/Users/pjbeyer/Projects/.workflow/metrics/$profile-$(date +%Y-%m).json"

# Display summary
echo "✅ Operation Complete"
echo "Profile: $profile"
# ... additional summary info ...
```

## Profile Configurations

### Expected overrides.yaml Structure

```yaml
# {profile}/.workflow/overrides.yaml
profile_overrides:
  # Issue tracking: "github", "jira", or "none"
  issue_tracker: github

  # Branch naming: include issue number in branch name?
  branch_prefix_issue: true

  # Task management: auto-create OmniFocus tasks?
  auto_create_omnifocus_task: true

  # Documentation: auto-create doc issues on work completion?
  auto_create_doc_issues: false
```

### Default Behavior (if key missing)

- `issue_tracker`: Check reference implementation, default to "none"
- `branch_prefix_issue`: false
- `auto_create_omnifocus_task`: false
- `auto_create_doc_issues`: false (prompt user instead)

## Operations

For specific operation instructions:
- **start.md**: Create issue, branch, and task
- **finish.md**: Close issue, cleanup, mark complete
- **status.md**: Show active work across profiles
- **resume.md**: Restore context for specific work

Commands will reference these files explicitly.
