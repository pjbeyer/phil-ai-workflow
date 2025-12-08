# Branch Strategy

## Branch Naming Convention

Format: `{type}/{brief-description}`

### Types

- `feature/` - New functionality
- `fix/` - Bug fixes
- `refactor/` - Code restructuring without behavior change
- `docs/` - Documentation only
- `test/` - Test improvements
- `chore/` - Maintenance tasks

### Examples

```
feature/user-authentication
fix/login-validation-error
refactor/extract-config-loading
docs/update-api-reference
```

## Rules

1. One branch per issue/task
2. Branch from main/master
3. Keep branches short-lived (<1 week)
4. Delete after merge
5. Descriptive but concise names (3-5 words max)

## Profile Variations

- **work:** May use Jira ticket prefix (`feature/PROJ-123-user-auth`)
- **pjbeyer:** GitHub issue prefix optional (`feature/gh-45-reporting`)
- **play:** Minimal structure, anything goes
- **home:** Rarely used (optional for scripts)
