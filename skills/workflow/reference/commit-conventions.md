# Commit Conventions

## Format

Follow [Conventional Commits](https://www.conventionalcommits.org/)

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

## Types

- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code change without behavior change
- `docs:` - Documentation only
- `test:` - Test changes
- `chore:` - Maintenance (deps, config, etc.)
- `perf:` - Performance improvement
- `style:` - Formatting, whitespace

## Examples

```
feat(auth): add JWT token validation

Implements token validation middleware with expiry checks.

Closes #123
```

```
fix(api): handle null response from external service

Adds defensive null check and error logging.
```

## Rules

1. Present tense ("add" not "added")
2. No period at end of description
3. Body explains why, not what
4. Reference issues in footer (Closes #123, Refs #45)
5. Keep description under 72 chars

## Profile Variations

- **work:** May include Jira ticket in footer
- **pjbeyer:** Always reference GitHub issue if exists
- **play:** Conventions optional but encouraged
- **home:** Minimal, descriptive messages fine
