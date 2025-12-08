#!/usr/bin/env bash
# Check if in git repository
# Returns: "true" | "false"

if git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "true"
else
    echo "false"
fi
