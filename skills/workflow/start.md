# Start Work Operation

Orchestrate starting new work with full context tracking across issue tracker, git branch, and task manager.

**Invoked by:** `/work-start [description]` command

**See:** SKILL.md for shared utilities documentation

---

## Step 1: Initialize and Detect Context

Detect profile:

```bash
profile=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/detect-profile.sh)

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

echo "Profile: $profile"
```

Display current context:

```bash
echo ""
echo "Current directory: $(pwd)"
echo "Detected profile: $profile"
echo ""
```

Verify git repository:

```bash
in_repo=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/in-git-repo.sh)
if [[ "$in_repo" == "false" ]]; then
    echo "Error: Not in a git repository"
    echo "Hint: cd to a project directory with git initialized"
    exit 1
fi
repo_root=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/repo-root.sh)
echo "Repository: $repo_root"
```

Confirm working directory (use AskUserQuestion):
- Question: "Start work in this repository?"
- Options:
  - "Yes - Start here" (proceed with current directory)
  - "No - Navigate first" (ask for directory path, cd to it, verify git repo)
- If user selects "No", prompt for directory path and cd before continuing

Check working directory status:

```bash
if [[ -n $(git status --porcelain) ]]; then
    echo "⚠️  Warning: You have uncommitted changes"
    git status --short
fi
```

If uncommitted changes exist, use AskUserQuestion:
- Question: "Stash changes before starting new work?"
- Options: Yes (stash) / No (continue)
- If yes: `git stash push -m "WIP: before starting new work"`

## Step 2: Get Work Description

If description provided as argument to `/work-start`, use it. Otherwise use AskUserQuestion:

**Question 1: Work Type**
```
Header: "Type"
Question: "What type of work is this?"
Options:
  - feature: "New functionality"
  - fix: "Bug fix"
  - refactor: "Code restructuring without behavior change"
  - docs: "Documentation only"
  - test: "Test improvements"
  - chore: "Maintenance tasks"
```

**Question 2: Description**
```
Ask: "What are you working on?" (free-form text)
```

**Question 3: Acceptance Criteria** (optional)
```
Ask: "What are the acceptance criteria? (Separate with semicolons or press Enter for none)"
Parse and format as checklist for issue body.
```

## Step 3: Create Issue

Determine issue tracker from profile config:

```bash
issue_tracker=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" issue_tracker)
echo "Issue tracker: $issue_tracker"
```

### For GitHub (pjbeyer/play profiles)

```bash
# Check authentication
authenticated=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/gh-authenticated.sh)
if [[ "$authenticated" == "false" ]]; then
    echo "Error: gh CLI not authenticated"
    echo "Run: gh auth login"
    exit 1
fi

# Get repo name
repo=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-github-repo.sh)
if [[ -z "$repo" ]]; then
    echo "Error: Could not detect GitHub repo"
    echo "Hint: Ensure origin remote is set"
    exit 1
fi

# Format issue body
issue_body="## Description

${description}

## Acceptance Criteria

${formatted_criteria}

## Technical Notes

_Add technical notes here as needed_
"

# Create issue (without label to avoid errors on new repos)
issue_url=$(gh issue create \
    --repo "$repo" \
    --title "${work_type}: ${title}" \
    --body "$issue_body" \
    2>&1 | grep -o 'https://[^ ]*')

issue_number=$(echo "$issue_url" | grep -oE '[0-9]+$')

# Optionally add label if it exists (don't fail if it doesn't)
if gh label list --repo "$repo" | grep -q "^${work_type}"; then
    gh issue edit "$issue_number" --repo "$repo" --add-label "${work_type}" 2>/dev/null || true
    echo "✓ Created issue #$issue_number with label: $issue_url"
else
    echo "✓ Created issue #$issue_number (label '${work_type}' not found, skipped): $issue_url"
fi
```

### For Jira (work profile)

Use AskUserQuestion:
```
Message: "Create Jira task manually in your project board, then enter the issue key:"
Get Jira issue key (format: PROJ-123)
Validate format matches [A-Z]+-[0-9]+
Construct URL: https://your-jira.atlassian.net/browse/$jira_issue
```

### For none (home profile)

```bash
issue_number="none"
issue_url=""
echo "✓ No issue tracker configured (home profile)"
```

## Step 4: Create Branch

Generate branch name:

```bash
branch_prefix_issue=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" branch_prefix_issue)
[[ -z "$branch_prefix_issue" ]] && branch_prefix_issue="false"

# Sanitize description
branch_desc=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-50)

if [[ "$branch_prefix_issue" == "true" ]] && [[ "$issue_number" != "none" ]]; then
    branch_name="${work_type}/${issue_number}-${branch_desc}"
else
    branch_name="${work_type}/${branch_desc}"
fi

echo "Branch name: $branch_name"
```

Check if on main/master:

```bash
current=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/current-branch.sh)
if [[ "$current" != "main" ]] && [[ "$current" != "master" ]]; then
    echo "⚠️  Currently on: $current (not main/master)"
fi
```

If not on main/master, use AskUserQuestion:
- Question: "Switch to main before creating feature branch?"
- Options: Yes (checkout main) / No (create from current)
- If yes: `git checkout main` or `git checkout master`

Create and checkout branch:

```bash
git checkout -b "$branch_name"

if [[ $? -eq 0 ]]; then
    echo "✓ Created and checked out branch: $branch_name"
else
    echo "✗ Failed to create branch"
    exit 1
fi
```

## Step 5: Create OmniFocus Task (Optional)

Check if enabled:

```bash
auto_create_task=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" auto_create_omnifocus_task)
[[ -z "$auto_create_task" ]] && auto_create_task="false"
```

If enabled, create task:

```bash
task_note="Issue: $issue_url
Branch: $branch_name
Repository: $(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/repo-root.sh)

Started: $(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/format-datetime.sh)"

osascript <<EOF
tell application "OmniFocus"
    tell default document
        set newTask to make new inbox task with properties {name:"${work_type}: ${title}", note:"${task_note}"}
    end tell
end tell
EOF

echo "✓ Created OmniFocus task"
```

If creation fails or OmniFocus not running, show warning but continue.

If disabled:
```bash
echo "ℹ️  OmniFocus task creation disabled for $profile profile"
```

## Step 6: Record Metrics

```bash
metrics_dir="/Users/pjbeyer/Projects/.workflow/metrics"
mkdir -p "$metrics_dir"

metrics_file="$metrics_dir/$profile-$(date +%Y-%m).json"

# Append event (JSON lines format)
echo "{\"event\":\"work_started\",\"profile\":\"$profile\",\"date\":\"$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/format-datetime.sh)\",\"issue\":\"$issue_number\",\"branch\":\"$branch_name\",\"type\":\"$work_type\"}" >> "$metrics_file"

echo "ℹ️  Metrics recorded"
```

## Step 7: Display Summary

```
✅ Work Started Successfully

Profile: $profile
Issue: $issue_url
Branch: $branch_name
Repository: $(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/repo-root.sh)

Next steps:
1. Make changes in your working directory
2. Commit frequently using conventional commits
3. When ready for review: gh pr create
4. When complete: /work-finish
```

## Step 8: Suggest Superpowers Skills (if available)

Based on work type and superpowers availability, suggest relevant skills:

```bash
# Load superpowers detection from SKILL.md
# (has_superpowers and suggest_superpowers_skill functions)

if has_superpowers; then
    # Determine work type from issue title or user input
    # Common patterns: "feature", "fix", "refactor", "docs", "test"

    case "$type" in
        feature|refactor)
            suggest_superpowers_skill "test-driven-development" \
                "Write tests before implementation to ensure correctness"
            ;;
        fix)
            suggest_superpowers_skill "systematic-debugging" \
                "Root cause investigation before proposing fixes"
            ;;
    esac
fi
```

**What this does**:
- Detects if superpowers plugin is installed
- Suggests TDD for feature/refactor work (write tests first)
- Suggests systematic-debugging for bug fixes (find root cause)
- Suggestions are informational only - workflow continues normally

**Benefits**:
- Encourages best practices at the right time
- Makes users aware of available skills
- No blocking - suggestions can be ignored

## Error Handling

- **Git failures:** Show git output, explain issue
- **gh CLI failures:** Verify authentication with `gh auth status`
- **GitHub label failures:** Skip label creation if label doesn't exist (new repos may not have labels)
- **Issue URL extraction:** Use `2>&1 | grep` to handle stderr output from gh CLI
- **OmniFocus failures:** Warn but continue (task creation optional)
- **Config failures:** Check profile override file exists

## Implementation Notes

- Use AskUserQuestion tool, not bash `read` commands
- Reference SKILL.md for shared utility functions
- Check profile config before making assumptions
- Graceful degradation if OmniFocus fails
- Validate issue tracker format (GitHub #, Jira KEY-123)
