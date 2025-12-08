# Finish Work Operation

Orchestrate completing work: close issues, delete branches, update tasks, and execute profile-specific post-merge actions.

**Invoked by:** `/work-finish` command

**See:** SKILL.md for shared utilities documentation

---

## Step 1: Initialize and Detect Context

Load utilities and detect profile:

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

in_repo=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/in-git-repo.sh)
if [[ "$in_repo" == "false" ]]; then
    echo "Error: Not in a git repository"
    exit 1
fi

repo_root=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/repo-root.sh)
current=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/current-branch.sh)

# Display current context
echo ""
echo "Current directory: $(pwd)"
echo "Repository: $repo_root"
echo "Current branch: $current"
echo "Detected profile: $profile"
echo ""

# Check if on feature branch (not main/master)
if [[ "$current" == "main" ]] || [[ "$current" == "master" ]]; then
    echo "Error: Cannot finish work on main/master branch"
    echo "Hint: Switch to feature branch first"
    exit 1
fi
```

Confirm correct work (use AskUserQuestion):
- Question: "Is this the correct work to finish?"
- Options:
  - "Yes - Finish this work" (proceed)
  - "No - Wrong directory/branch" (exit and let user navigate)

```bash
echo "Finishing work on branch: $current"
```

## Step 2: Extract Issue Information

```bash
issue_number=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/extract-issue-from-branch.sh "$current" || echo "")

if [[ -z "$issue_number" ]]; then
    echo "⚠️  Warning: Could not extract issue number from branch name"
    echo "Branch: $current"
fi
```

If no issue number found, use AskUserQuestion:
- Question: "Enter issue number manually (or type 'skip' if no issue):"
- If user enters "skip", set `issue_number=""`

## Step 3: Check PR and Merge Status

Get issue tracker config:

```bash
issue_tracker=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" issue_tracker)
repo=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-github-repo.sh)
```

**Check for PR** (if GitHub):

```bash
if [[ -n "$repo" ]] && ${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/gh-authenticated.sh && [[ "$issue_tracker" == "github" ]]; then
    pr_info=$(gh pr list --repo "$repo" --head "$current" --json state,number 2>/dev/null)

    if [[ -n "$pr_info" ]] && [[ "$pr_info" != "[]" ]]; then
        pr_number=$(echo "$pr_info" | jq -r '.[0].number')
        pr_state=$(echo "$pr_info" | jq -r '.[0].state')

        echo "Pull Request #$pr_number: $pr_state"

        if [[ "$pr_state" != "MERGED" ]]; then
            echo "⚠️  Warning: PR is not merged yet (state: $pr_state)"
        fi
    else
        echo "ℹ️  No pull request found for this branch"
    fi
fi
```

**Check if branch is already merged** (critical safety check):

```bash
# Determine main branch name
if git show-ref --verify --quiet refs/heads/main; then
    main_branch="main"
elif git show-ref --verify --quiet refs/heads/master; then
    main_branch="master"
else
    echo "Error: Could not find main or master branch"
    exit 1
fi

# Check if current branch is already merged
if git merge-base --is-ancestor "$current" "$main_branch"; then
    echo "✓ Branch is already merged into $main_branch"
    branch_merged=true
else
    echo "⚠️  Warning: Branch is NOT merged into $main_branch yet"
    branch_merged=false
fi
```

If PR is not merged or doesn't exist AND branch is not merged, use AskUserQuestion:
- Question: "Work may not be merged yet. Continue with finish-work anyway?"
- Options:
  - yes: "Continue cleanup"
  - no: "Abort (merge PR first)"
- If user selects "no", exit with: "Aborted. Merge PR first, then run /work-finish again."

If branch is already merged (`branch_merged=true`), skip question and proceed.

## Step 3.5: Code Review (if superpowers available)

If superpowers is available and changes include code files, invoke code review:

```bash
# Load superpowers detection from SKILL.md
# (has_superpowers function)

if has_superpowers; then
    # Check if changes include code files
    code_changed=false
    while IFS= read -r file; do
        # Check for common code file extensions
        if [[ "$file" =~ \.(ts|js|py|go|rs|java|rb|php|c|cpp|h|hpp|swift|kt)$ ]]; then
            code_changed=true
            break
        fi
    done < <(git diff --name-only "$main_branch"..HEAD 2>/dev/null)

    if [[ "$code_changed" == "true" ]]; then
        echo ""
        echo "🔍 Code changes detected - invoking code review"
        echo ""

        # Invoke superpowers:requesting-code-review skill
        # This skill will:
        # - Review implementation against requirements
        # - Check code quality and standards
        # - Identify potential issues
        # - Provide feedback

        echo "Use the Skill tool: superpowers:requesting-code-review"
        echo ""
        echo "After code review completes, invoke finishing-branch:"
        echo "Use the Skill tool: superpowers:finishing-a-development-branch"
        echo ""

        # Wait for user to complete review process
        # This is informational - user can choose to skip
    else
        echo "ℹ️  No code changes detected - skipping code review"
    fi
fi
```

**What this does**:
- Detects code file changes in the branch
- Suggests invoking code review if changes found
- Ensures quality checks before merging/closing
- Gracefully skips if no code changes or superpowers unavailable

**Benefits**:
- Catches issues before they're merged
- Validates against requirements
- Maintains code quality standards
- Optional - doesn't block workflow

## Step 4: Close Issue

```bash
if [[ -n "$issue_number" ]] && [[ "$issue_tracker" == "github" ]]; then
    issue_state=$(gh issue view "$issue_number" --repo "$repo" --json state --jq '.state' 2>/dev/null)

    if [[ "$issue_state" == "CLOSED" ]]; then
        echo "✓ Issue #$issue_number is already closed"
    else
        echo "Issue #$issue_number is open"
    fi
fi
```

If issue is open, use AskUserQuestion:
- Question: "Close issue #$issue_number?"
- Options: yes / no
- If yes:
  ```bash
  gh issue close "$issue_number" --repo "$repo" --comment "Completed in branch $current"
  echo "✓ Closed issue #$issue_number"
  ```

**For Jira (work profile):**

Display message:
```
Jira Issue $issue_number:
Please close the issue in Jira manually, then press Enter to continue.
```

Use AskUserQuestion to wait for confirmation.

## Step 4.5: Check Documentation Impact

After issue is closed, check if changes require documentation updates:

```bash
echo ""
echo "Checking for documentation impact..."

detection_script="$HOME/.claude/skills/workflow/scripts/detect-doc-impact.sh"

if [ ! -f "$detection_script" ]; then
    echo "ℹ️  Doc detection script not found, skipping check"
else
    # Run detection
    impact_output=""
    if impact_output=$("$detection_script" "$main_branch" "$current" 2>&1); then
        # Doc impact detected
        echo "$impact_output"
        echo ""

        # Get profile config for enforcement
        auto_create=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" "auto_create_doc_issues" || echo "false")

        if [[ "$auto_create" == "true" ]]; then
            # Auto-create issue
            echo "Auto-creating documentation issue..."

            # Get issue title if we have an issue number
            if [[ -n "$issue_number" ]] && [[ "$issue_tracker" == "github" ]]; then
                issue_title=$(gh issue view "$issue_number" --repo "$repo" --json title --jq '.title' 2>/dev/null || echo "")
            else
                issue_title="Changes in $current"
            fi

            # Extract feature name from branch
            feature_name=$(echo "$current" | sed 's|^feature/||' | sed 's|^fix/||' | sed 's|^docs/||' | sed 's|^refactor/||' | sed 's|^test/||' | sed 's|^chore/||')

            # Format reasons for template
            reasons=$(echo "$impact_output" | grep "^  -" | tr '\n' ';' | sed 's/;$//')

            # Create doc issue
            create_script="$HOME/.claude/skills/workflow/scripts/create-doc-issue.sh"
            if [ -f "$create_script" ]; then
                "$create_script" "$feature_name" "${issue_number:-none}" "$issue_title" "$current" "$reasons" "$main_branch" || echo "⚠️  Failed to create doc issue"
            fi
        else
            # Prompt user
            echo "⚠️  Documentation may need updating."
        fi
    else
        echo "No documentation impact detected"
    fi
fi
```

If `auto_create` is false and doc impact detected, use AskUserQuestion:
- Question: "Create documentation issue for these changes?"
- Options:
  - yes: "Create issue now"
  - no: "Skip (handle manually)"
- If yes, run the same issue creation logic as auto-create

## Step 5: Switch to Main Branch

```bash
echo "Switching to $main_branch..."
git checkout "$main_branch"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to switch to $main_branch"
    exit 1
fi

echo "✓ Switched to $main_branch"
```

## Step 6: Delete Local Branch

```bash
echo "Deleting local branch: $current"
git branch -d "$current"

if [[ $? -ne 0 ]]; then
    echo "⚠️  Warning: Could not delete branch with -d (may have unmerged changes)"
fi
```

If deletion with `-d` fails, use AskUserQuestion:
- Question: "Force delete branch with -D?"
- Options:
  - yes: "Force delete (unmerged changes will be lost)"
  - no: "Keep branch (manual cleanup required)"
- If yes:
  ```bash
  git branch -D "$current"
  echo "✓ Force deleted local branch: $current"
  ```

## Step 7: Delete Remote Branch

```bash
if git ls-remote --exit-code --heads origin "$current" &>/dev/null; then
    echo "Remote branch exists: origin/$current"

    auto_delete=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" auto_delete_branch || echo "true")

    if [[ "$auto_delete" != "true" ]]; then
        # Ask user
        delete_remote=""
    else
        delete_remote="yes"
    fi
fi
```

If `auto_delete` is not true, use AskUserQuestion:
- Question: "Delete remote branch origin/$current?"
- Options: yes / no

If yes:
```bash
git push origin --delete "$current"
echo "✓ Deleted remote branch: origin/$current"
```

## Step 8: Update OmniFocus Task

```bash
auto_create_task=$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/get-profile-config.sh "$profile" auto_create_omnifocus_task || echo "false")

if [[ "$auto_create_task" == "true" ]]; then
    echo "Updating OmniFocus task..."

    osascript <<EOF 2>/dev/null
tell application "OmniFocus"
    tell default document
        set matchingTasks to {}

        -- Search for task with branch name in note
        repeat with taskItem in flattened tasks
            if note of taskItem contains "$current" then
                set end of matchingTasks to taskItem
            end if
        end repeat

        -- Complete first matching task
        if (count of matchingTasks) > 0 then
            set completed of item 1 of matchingTasks to true
            return "Completed task"
        else
            return "No matching task found"
        end if
    end tell
end tell
EOF

    echo "✓ OmniFocus task updated"
else
    echo "ℹ️  OmniFocus update skipped for $profile profile"
fi
```

## Step 9: Execute Profile-Specific Post-Merge Actions

**For work profile:**

Display checklist:
```
Work profile post-merge tasks:
- [ ] Update Jira ticket status
- [ ] Create release notes if customer-facing
- [ ] Notify team in Slack

Press Enter when complete.
```

Use AskUserQuestion to wait for confirmation.

**For pjbeyer profile:**

Use AskUserQuestion:
- Question: "Any client updates needed for this work?"
- Options: yes / no
- If yes, ask for update notes (free text), then display:
  ```
  ℹ️  Remember to send client update: [notes]
  ```

## Step 10: Record Metrics

```bash
metrics_dir="/Users/pjbeyer/Projects/.workflow/metrics"
metrics_file="$metrics_dir/$profile-$(date +%Y-%m).json"

# Record completion event
echo "{\"event\":\"work_finished\",\"profile\":\"$profile\",\"date\":\"$(${CLAUDE_PLUGIN_ROOT}/skills/workflow/scripts/format-datetime.sh)\",\"issue\":\"$issue_number\",\"branch\":\"$current\"}" >> "$metrics_file"

echo "ℹ️  Metrics recorded"
```

## Step 11: Display Summary

```
✅ Work Finished Successfully

Profile: $profile
Issue: $issue_number (closed)
Branch: $current (deleted)
Current branch: $(current_branch)

Great job! 🎉
```

## Error Handling

- **Not on feature branch:** Error message, suggest switching
- **PR not merged:** Warning, ask to continue or abort
- **Branch delete fails:** Offer force delete option
- **OmniFocus task not found:** Continue anyway (optional)
- **Git command failures:** Show git output, explain issue

## Implementation Notes

- Use AskUserQuestion tool, not bash `read` commands
- Graceful degradation if OmniFocus fails
- Safety check: verify not on main/master
- Profile-aware post-merge actions
- Always record metrics for velocity tracking
- Smart merge detection using `git merge-base --is-ancestor`
