#!/usr/bin/env bash
# Extract issue ID from branch name
# Usage: extract-issue-from-branch.sh <branch>
# Returns: issue ID or empty string

if [[ $# -ne 1 ]]; then
    echo "Usage: extract-issue-from-branch.sh <branch>" >&2
    exit 1
fi

branch=$1

# Try various patterns
# GitHub: feature/gh-123-description or feature/123-description
if [[ "$branch" =~ .*gh-([0-9]+).* ]] || [[ "$branch" =~ .*/([0-9]+)-.* ]]; then
    echo "${BASH_REMATCH[1]}"
    exit 0
fi

# Jira: feature/PROJ-123-description
if [[ "$branch" =~ .*([A-Z]+-[0-9]+).* ]]; then
    echo "${BASH_REMATCH[1]}"
    exit 0
fi

echo ""
