#!/usr/bin/env bash
# Get profile config value
# Usage: get-profile-config.sh <profile> <key>
# Returns: config value or empty string

if [[ $# -ne 2 ]]; then
    echo "Usage: get-profile-config.sh <profile> <key>" >&2
    exit 1
fi

profile=$1
key=$2
config_file="/Users/pjbeyer/Projects/$profile/.workflow/overrides.yaml"

if [[ ! -f "$config_file" ]]; then
    echo ""
    exit 0
fi

# Simple YAML parsing (assumes key: value format)
grep "^  $key:" "$config_file" | sed 's/.*: //' | tr -d '"' || echo ""
