#!/usr/bin/env bash
# Get GitHub repository name (owner/repo)
# Returns: "owner/repo" or empty string

remote_url=$(git remote get-url origin 2>/dev/null || echo "")

if [[ -z "$remote_url" ]]; then
    echo ""
    exit 0
fi

# Extract owner/repo from various URL formats
if [[ "$remote_url" =~ github.com[:/](.+/.+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}" | sed 's/\.git$//'
else
    echo ""
fi
