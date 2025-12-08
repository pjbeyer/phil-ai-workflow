#!/usr/bin/env bash
# Get current branch name
# Returns: branch name or empty string

git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
