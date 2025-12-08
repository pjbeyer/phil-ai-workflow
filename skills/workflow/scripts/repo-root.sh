#!/usr/bin/env bash
# Get repository root path
# Returns: absolute path or empty string

git rev-parse --show-toplevel 2>/dev/null || echo ""
