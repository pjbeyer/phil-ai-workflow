#!/usr/bin/env bash
# Check if gh CLI is authenticated
# Returns: "true" | "false"
# Note: Uses 1Password CLI plugin wrapper for secure auth token access

if op plugin run -- gh auth status &>/dev/null; then
    echo "true"
else
    echo "false"
fi
