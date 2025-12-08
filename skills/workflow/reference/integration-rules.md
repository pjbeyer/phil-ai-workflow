# Integration Rules

## Issue Trackers

### GitHub Issues

**Profiles:** pjbeyer, play

**Setup:**
1. Install gh CLI: `brew install gh`
2. Authenticate: `gh auth login`
3. Set in `{profile}/.workflow/overrides.yaml`: `issue_tracker: github`

**Branch prefix:** Optional (configure with `branch_prefix_issue: true`)

**Example:**
```
feature/gh-123-user-authentication
feature/123-user-authentication  (if branch_prefix_issue: true)
feature/user-authentication      (if branch_prefix_issue: false)
```

### Jira

**Profiles:** work

**Setup:**
1. Manual task creation in Jira board
2. Set in `{profile}/.workflow/overrides.yaml`: `issue_tracker: jira`
3. Provide Jira issue key when prompted (format: PROJ-123)

**Branch prefix:** Common pattern (configure with `branch_prefix_issue: true`)

**Example:**
```
feature/PROJ-123-user-authentication
```

### None

**Profiles:** home (or any profile without issue tracking)

**Setup:**
Set in `{profile}/.workflow/overrides.yaml`: `issue_tracker: none`

**Branch prefix:** No issue number available

**Example:**
```
feature/user-authentication
chore/update-dependencies
```

## Task Managers

### OmniFocus

**Setup:**
1. Install OmniFocus app (macOS)
2. Enable AppleScript access
3. Set in `{profile}/.workflow/overrides.yaml`: `auto_create_omnifocus_task: true`

**Behavior:**
- Creates inbox task on `/work-start`
- Marks task complete on `/work-finish`
- Task note includes issue URL, branch name, repository path
- Graceful fallback if OmniFocus not running

### None

**Setup:**
Set in `{profile}/.workflow/overrides.yaml`: `auto_create_omnifocus_task: false`

**Behavior:**
- Skip task creation
- Workflow continues normally

## Profile Configuration Examples

### work profile (GitHub + OmniFocus)

```yaml
# ~/Projects/work/.workflow/overrides.yaml
profile_overrides:
  issue_tracker: github
  branch_prefix_issue: true
  auto_create_omnifocus_task: true
```

### pjbeyer profile (GitHub, no OmniFocus)

```yaml
# ~/Projects/pjbeyer/.workflow/overrides.yaml
profile_overrides:
  issue_tracker: github
  branch_prefix_issue: false
  auto_create_omnifocus_task: false
```

### play profile (No tracking)

```yaml
# ~/Projects/play/.workflow/overrides.yaml
profile_overrides:
  issue_tracker: none
  branch_prefix_issue: false
  auto_create_omnifocus_task: false
```

### home profile (No tracking)

```yaml
# ~/Projects/home/.workflow/overrides.yaml
profile_overrides:
  issue_tracker: none
  branch_prefix_issue: false
  auto_create_omnifocus_task: false
```

## Metrics Collection

**Always enabled** - metrics captured regardless of profile:

**Location:** `~/Projects/.workflow/metrics/{profile}-{YYYY-MM}.json`

**Format:** JSON Lines (one event per line)

**Events:**
- `work_started`: When `/work-start` completes
- `work_finished`: When `/work-finish` completes

**Future:**
- `/velocity` command to analyze metrics
- `/estimate` command for historical estimation
