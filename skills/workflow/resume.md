# Resume Operation

Find a branch across all profiles, display full context (issue, commits, status), check it out, and suggest next actions.

**Invoked by:** `/work-resume [issue-id or branch-name]` command

**See:** SKILL.md for shared utilities documentation

---

## Overview

This operation uses bash 4+ features (associative arrays). Execute with Homebrew bash via heredoc.

## Input Processing

Accept issue ID or branch name as input from `/work-resume` command argument. If no argument provided, use AskUserQuestion to prompt for input.

Pass input via `INPUT_SEARCH` environment variable to the bash script.

## Implementation

```bash
# Get input from command argument or AskUserQuestion
# Store in INPUT_SEARCH environment variable

export INPUT_SEARCH="$input_value"

/opt/homebrew/bin/bash <<'SCRIPT'
set -euo pipefail

# Source utilities


# Get input from environment
input="${INPUT_SEARCH:-}"

if [[ -z "$input" ]]; then
    echo "Error: Missing argument"
    echo "Usage: /work-resume [issue-id or branch-name]"
    exit 1
fi

echo "Searching for: $input"

# Step 1: Find Matching Branch
profiles=("work" "pjbeyer" "play" "home")
declare -A matches=()

for profile in "${profiles[@]}"; do
    profile_dir="/Users/pjbeyer/Projects/$profile"

    if [[ ! -d "$profile_dir" ]]; then
        continue
    fi

    # Find repositories with matching branch
    while IFS= read -r git_dir; do
        repo_root=$(dirname "$git_dir")
        cd "$repo_root" || continue

        # Check if branch exists locally with exact match
        if git show-ref --verify --quiet "refs/heads/$input" 2>/dev/null; then
            matches["$profile:$repo_root"]="$input"
            continue
        fi

        # Try substring match on branch names
        while IFS= read -r branch; do
            branch=$(echo "$branch" | sed 's/^[* ] //')  # Remove git branch markers
            if [[ "$branch" == *"$input"* ]] && [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
                matches["$profile:$repo_root"]="$branch"
                break
            fi
        done < <(git branch --format='%(refname:short)' 2>/dev/null)

    done < <(find "$profile_dir" -name ".git" -type d -not -path "*/node_modules/*" -not -path "*/.cache/*" 2>/dev/null)
done

# Step 2: Handle Match Results
if [[ ${#matches[@]} -eq 0 ]]; then
    echo "Error: No matching branch found for: $input"
    echo ""
    echo "Tip: Use /work-status to see all active work"
    exit 1
fi

# If multiple matches, list them
if [[ ${#matches[@]} -gt 1 ]]; then
    echo ""
    echo "Multiple matches found:"
    for key in "${!matches[@]}"; do
        IFS=':' read -r profile repo_path <<< "$key"
        branch="${matches[$key]}"
        echo "  - Profile: $profile"
        echo "    Directory: $repo_path"
        echo "    Branch: $branch"
        echo ""
    done
    echo "Note: Use AskUserQuestion to prompt for selection"
    echo "For now, using first match..."
    echo ""
fi

# Get first (or only) match
for key in "${!matches[@]}"; do
    IFS=':' read -r profile repo_path <<< "$key"
    branch="${matches[$key]}"
    break
done

repo_name=$(basename "$repo_path")
echo "Selected: $profile / $repo_name / $branch"
echo ""

# Step 3: Navigate to Repository
cd "$repo_path" || exit 1
echo "Repository: $repo_path"
echo ""

# Step 4: Display Issue Context
issue=$(~/.claude/plugins/cache/phil-ai-workflow/skills/workflow/scripts/extract-issue-from-branch.sh "$branch" 2>/dev/null || echo "")

if [[ -n "$issue" ]]; then
    issue_tracker=$(~/.claude/plugins/cache/phil-ai-workflow/skills/workflow/scripts/get-profile-config.sh "$profile" issue_tracker 2>/dev/null || echo "")

    if [[ "$issue_tracker" == "github" ]]; then
        repo=$(~/.claude/plugins/cache/phil-ai-workflow/skills/workflow/scripts/get-github-repo.sh)

        if [[ -n "$repo" ]] && ~/.claude/plugins/cache/phil-ai-workflow/skills/workflow/scripts/gh-authenticated.sh; then
            echo "================================"
            echo "Issue Context"
            echo "================================"
            echo ""

            # Fetch and display issue details
            gh issue view "$issue" --repo "$repo" 2>/dev/null || echo "Could not fetch issue #$issue"

            echo ""
        fi
    elif [[ "$issue_tracker" == "jira" ]]; then
        echo "================================"
        echo "Issue Context"
        echo "================================"
        echo ""
        echo "Jira Issue: $issue"
        echo "View at: https://your-jira.atlassian.net/browse/$issue"
        echo ""
    fi
else
    echo "ℹ️  No issue number found in branch name"
    echo ""
fi

# Step 5: Show Recent Commits
echo "================================"
echo "Recent Commits on Branch"
echo "================================"
echo ""

# Get commits on this branch not on main
if git rev-parse main >/dev/null 2>&1; then
    git log --oneline --graph main.."$branch" 2>/dev/null
elif git rev-parse master >/dev/null 2>&1; then
    git log --oneline --graph master.."$branch" 2>/dev/null
else
    git log --oneline --graph -10 "$branch" 2>/dev/null
fi

echo ""

# Step 6: Show Working Directory Status
echo "================================"
echo "Working Directory Status"
echo "================================"
echo ""

git status

echo ""

# Step 7: Check Out Branch
current=$(~/.claude/plugins/cache/phil-ai-workflow/skills/workflow/scripts/current-branch.sh)

if [[ "$current" != "$branch" ]]; then
    echo "Checking out branch: $branch"
    git checkout "$branch"

    if [[ $? -eq 0 ]]; then
        echo "✓ Checked out: $branch"
    else
        echo "✗ Failed to checkout branch"
        exit 1
    fi
else
    echo "✓ Already on branch: $branch"
fi

echo ""

# Step 8: Check Remote Sync Status
if git rev-parse --verify "origin/$branch" &>/dev/null 2>&1; then
    ahead=$(git rev-list --count "origin/$branch..$branch" 2>/dev/null || echo "0")
    behind=$(git rev-list --count "$branch..origin/$branch" 2>/dev/null || echo "0")

    if [[ $ahead -gt 0 ]]; then
        echo "⚠️  You are $ahead commit(s) ahead of origin"
        echo "    Push when ready: git push"
        echo ""
    fi

    if [[ $behind -gt 0 ]]; then
        echo "⚠️  You are $behind commit(s) behind origin"
        echo "    Pull to sync: git pull"
        echo ""
    fi

    if [[ $ahead -eq 0 ]] && [[ $behind -eq 0 ]]; then
        echo "✓ Branch is in sync with origin"
        echo ""
    fi
fi

# Step 9: Suggest Next Actions
echo "================================"
echo "Next Actions"
echo "================================"
echo ""

branch_age=$(git log -1 --format="%ar" "$branch" 2>/dev/null || echo "unknown")
echo "Branch age: Last commit $branch_age"
echo ""

echo "Continue your work:"
echo "  1. Review the issue description above"
echo "  2. Check acceptance criteria"
echo "  3. Review recent commits to see progress"
echo "  4. Make changes and commit"
echo "  5. When ready for review: gh pr create"
echo "  6. When complete: /work-finish"
echo ""
SCRIPT
```

## Output Format Example

```
Searching for: GH-123

Selected: pjbeyer / workflow / feature/gh-123-user-auth

Repository: /Users/pjbeyer/Projects/pjbeyer/workflow

================================
Issue Context
================================

Add user authentication #123
Open • pjbeyer opened 5 days ago • 0 comments

## Description
Implement JWT-based authentication for API endpoints.

## Acceptance Criteria
- [ ] Login endpoint returns JWT token
- [ ] Protected routes validate JWT
- [ ] Refresh token mechanism
- [ ] Tests for auth flow

View this issue on GitHub: https://github.com/pjbeyer/workflow/issues/123

================================
Recent Commits on Branch
================================

* abc1234 feat(auth): add JWT token generation
* def5678 feat(auth): add login endpoint
* ghi9012 test(auth): add login tests

================================
Working Directory Status
================================

On branch feature/gh-123-user-auth
Your branch is up to date with 'origin/feature/gh-123-user-auth'.

nothing to commit, working tree clean

✓ Already on branch: feature/gh-123-user-auth

✓ Branch is in sync with origin

================================
Next Actions
================================

Branch age: Last commit 2 hours ago

Continue your work:
  1. Review the issue description above
  2. Check acceptance criteria
  3. Review recent commits to see progress
  4. Make changes and commit
  5. When ready for review: gh pr create
  6. When complete: /work-finish
```

## Error Handling

- **No matches found**: Display error, suggest /work-status command
- **Multiple matches**: Present selection menu via AskUserQuestion
- **Git checkout fails**: Show error, suggest checking working directory
- **Issue fetch fails**: Continue anyway, show branch context only
- **Remote branch doesn't exist**: Skip sync status, continue

## Implementation Notes

- **Shell Compatibility**: Uses `/opt/homebrew/bin/bash` via heredoc for bash 4+ features
- **Cross-profile search**: Scans all 4 profiles
- **Fuzzy matching**: Supports partial branch names
- **Issue context**: Fetches from GitHub/Jira when available
- **Sync detection**: Checks ahead/behind status vs origin
- **Graceful degradation**: If issue fetch fails, still show commits and status
- **Input handling**: Command argument passed via INPUT_SEARCH environment variable
- **Multiple matches**: Use AskUserQuestion to let user select from list

## Known Limitations

### Root-Level and Plugin Cache Repositories Not Searched

**Issue**: `/work-resume` only searches within profile directories (`~/Projects/{work,pjbeyer,play,home}/*`) and does not search:
- Root-level infrastructure repositories like `~/Projects/.workflow`
- Plugin cache directories like `~/.claude/plugins/cache/*`

**Why**: The resume operation iterates through profile directories and finds git repositories within them. Root-level and plugin cache directories are excluded from the search scope.

**Impact**: If you start work in `~/Projects/.workflow`, `~/.claude/plugins/cache/agents-context-system`, or other non-profile repos, `/work-resume` will not find those branches.

**Recommended Workflow**: When `/work-resume` fails to find a branch:

1. **Use `/work-status` first** - Check all active work in profile directories
2. **If not found**, check plugin cache directories manually:
   ```bash
   # Find work in plugin cache
   find ~/.claude/plugins/cache -name ".git" -type d | while read git_dir; do
       repo_root=$(dirname "$git_dir")
       cd "$repo_root"
       current=$(git rev-parse --abbrev-ref HEAD)
       if [[ "$current" != "main" ]] && [[ "$current" != "master" ]]; then
           echo "Plugin: $(basename $repo_root) - Branch: $current"
       fi
   done
   ```
3. **Navigate manually** to the repository and resume work:
   ```bash
   cd ~/.claude/plugins/cache/agents-context-system
   git checkout feature/your-branch
   git log --oneline main..HEAD
   git status
   ```

**Future Enhancement**: Consider adding plugin cache repository search to the resume operation, or extend the plugin-profiles.yaml mapping to include workflow commands.

**Last Updated**: 2025-11-21 - Added plugin cache limitation and graceful fallback workflow
