# Status Operation

Scan all git repositories across all profiles to find and display active feature branches, highlighting stale work.

**Invoked by:** `/work-status` command

**See:** SKILL.md for shared utilities documentation

---

## Overview

This operation uses bash 4+ features (associative arrays). Execute with Homebrew bash via heredoc.

## Implementation

```bash
/opt/homebrew/bin/bash <<'SCRIPT'
set -euo pipefail

# Source utilities


# Step 1: Find All Git Repositories
profiles=("work" "pjbeyer" "play" "home")
declare -A repos=()

echo ""
echo "Searching for active work across profiles..."
echo "Directories being scanned:"
for profile in "${profiles[@]}"; do
    echo "  - ~/Projects/$profile/"
done
echo ""

for profile in "${profiles[@]}"; do
    profile_dir="/Users/pjbeyer/Projects/$profile"

    if [[ ! -d "$profile_dir" ]]; then
        continue
    fi

    # Find all .git directories (repositories)
    while IFS= read -r git_dir; do
        repo_root=$(dirname "$git_dir")
        repos["$profile:$repo_root"]="$profile"
    done < <(find "$profile_dir" -name ".git" -type d -not -path "*/node_modules/*" -not -path "*/.cache/*" 2>/dev/null)
done

echo "Found ${#repos[@]} repositories across profiles"
echo ""

# Step 2: Check Each Repository for Active Work
declare -A active_work=()

for repo_key in "${!repos[@]}"; do
    IFS=':' read -r profile repo_path <<< "$repo_key"

    cd "$repo_path" || continue

    # Get current branch
    current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    if [[ -z "$current" ]]; then
        continue
    fi

    # Check if on feature branch (not main/master)
    if [[ "$current" != "main" ]] && [[ "$current" != "master" ]]; then
        # Get last commit info
        last_commit_date=$(git log -1 --format="%ar" 2>/dev/null || echo "unknown")
        last_commit_ts=$(git log -1 --format="%ct" 2>/dev/null || echo "0")

        # Calculate days since last commit
        if [[ "$last_commit_ts" != "0" ]]; then
            now=$(date +%s)
            # NOTE: Bash arithmetic - no $ needed inside (( ))
            days_since=$(( (now - last_commit_ts) / 86400 ))
        else
            days_since=0
        fi

        # Extract issue if possible
        issue=$(~/.claude/plugins/cache/phil-ai-workflow/skills/workflow/scripts/extract-issue-from-branch.sh "$current" 2>/dev/null || echo "")

        # Determine staleness
        stale=""
        if [[ $days_since -gt 7 ]]; then
            stale="⚠️  STALE"
        fi

        # Get repo basename for display
        repo_name=$(basename "$repo_path")

        # Record active work
        active_work["$profile:$repo_path"]="$current|$last_commit_date|$days_since|$issue|$stale|$repo_name"
    fi
done

# Step 3: Format and Display Output
echo ""
echo "================================"
echo "Active Work Across Profiles"
echo "================================"
echo ""

if [[ ${#active_work[@]} -eq 0 ]]; then
    echo "No active work found across any profile."
    echo ""
    echo "Use /work-start to begin new work."
    exit 0
fi

for profile in "${profiles[@]}"; do
    profile_has_work=false
    profile_count=0

    # Count active work for this profile
    for key in "${!active_work[@]}"; do
        if [[ "$key" == "$profile:"* ]]; then
            profile_has_work=true
            ((profile_count++))
        fi
    done

    if [[ "$profile_has_work" == false ]]; then
        continue
    fi

    echo "📁 $profile profile ($profile_count active)"
    echo ""

    for key in "${!active_work[@]}"; do
        if [[ "$key" != "$profile:"* ]]; then
            continue
        fi

        repo_path="${key#$profile:}"
        IFS='|' read -r branch last_commit days_since issue stale repo_name <<< "${active_work[$key]}"

        # Format issue display
        issue_display=""
        if [[ -n "$issue" ]]; then
            issue_display="[#$issue] "
        fi

        # Format stale warning
        stale_display=""
        if [[ -n "$stale" ]]; then
            stale_display=" $stale"
        fi

        echo "  ${issue_display}${branch}${stale_display}"
        echo "    Last commit: $last_commit"
        echo "    Repository: $repo_name"
        echo "    Path: $repo_path"
        echo ""
    done
done

# Summary
total_active=${#active_work[@]}
stale_count=0

for key in "${!active_work[@]}"; do
    IFS='|' read -r branch last_commit days_since issue stale repo_name <<< "${active_work[$key]}"
    if [[ -n "$stale" ]]; then
        ((stale_count++))
    fi
done

echo "================================"
echo "Summary: $total_active active, $stale_count stale (>7 days)"
echo "================================"
echo ""

if [[ $stale_count -gt 0 ]]; then
    echo "💡 Tip: Review stale work. Consider:"
    echo "   - Resume and complete: /work-resume [branch-name]"
    echo "   - Abandon and cleanup: Switch to branch, then /work-finish"
    echo ""
fi
SCRIPT
```

## Output Format Example

```
================================
Active Work Across Profiles
================================

📁 work profile (2 active)

  [#PROJ-456] feature/PROJ-456-api-refactor
    Last commit: 3 days ago
    Repository: backend-service
    Path: /Users/pjbeyer/Projects/work/backend-service

  [#GH-12] fix/login-bug ⚠️  STALE
    Last commit: 10 days ago
    Repository: auth-service
    Path: /Users/pjbeyer/Projects/work/auth-service

📁 pjbeyer profile (1 active)

  feature/csv-export
    Last commit: 2 hours ago
    Repository: workflow
    Path: /Users/pjbeyer/Projects/pjbeyer/workflow

================================
Summary: 3 active, 1 stale (>7 days)
================================

💡 Tip: Review stale work. Consider:
   - Resume and complete: /work-resume [branch-name]
   - Abandon and cleanup: Switch to branch, then /work-finish
```

## Error Handling

- **No git repositories found**: Show message, suggest checking profiles
- **Git command failures**: Skip repository, continue scanning
- **No active work**: Display helpful message with /work-start suggestion

## Implementation Notes

- **Shell Compatibility**: Uses `/opt/homebrew/bin/bash` via heredoc for bash 4+ features
- **Performance**: Finds .git directories efficiently, excludes node_modules
- **Cross-profile**: Scans all 4 profiles in one pass
- **Staleness**: 7-day threshold for warning
- **Issue extraction**: Uses utility function from workflow-utils.sh
- **Bash arithmetic**: Inside `(( ))`, use variable names without `$` prefix
