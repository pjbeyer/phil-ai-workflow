#!/usr/bin/env bash
# Detect current profile from working directory
# Returns: "work" | "pjbeyer" | "play" | "home" | "unknown"

cwd=$(pwd)

# 1. Check if we're in a plugin cache directory
if [[ "$cwd" == */.claude/plugins/cache/* ]]; then
    plugin_name=$(echo "$cwd" | sed -n 's|.*/.claude/plugins/cache/\([^/]*\).*|\1|p')

    if [[ -n "$plugin_name" ]]; then
        mapping_file="$HOME/.config/workflow/plugin-profiles.yaml"

        if [[ -f "$mapping_file" ]]; then
            profile=$(grep "^  $plugin_name:" "$mapping_file" | sed 's/.*: //' | tr -d ' "')

            if [[ -n "$profile" ]]; then
                echo "$profile"
                exit 0
            fi
        fi

        echo "unknown"
        exit 0
    fi
fi

# 2. Check if we're in Projects root (cross-profile infrastructure)
if [[ "$cwd" == "$HOME/Projects" ]]; then
    echo "pjbeyer"
    exit 0
fi

# Check if in root subdirectory (not a profile directory)
if [[ "$cwd" == "$HOME/Projects/"* ]]; then
    case "$cwd" in
        "$HOME/Projects/work"|"$HOME/Projects/work/"*)
            # Let fall through to case statement below
            ;;
        "$HOME/Projects/pjbeyer"|"$HOME/Projects/pjbeyer/"*)
            # Let fall through to case statement below
            ;;
        "$HOME/Projects/play"|"$HOME/Projects/play/"*)
            # Let fall through to case statement below
            ;;
        "$HOME/Projects/home"|"$HOME/Projects/home/"*)
            # Let fall through to case statement below
            ;;
        *)
            # Not a profile directory - must be root infrastructure
            echo "pjbeyer"
            exit 0
            ;;
    esac
fi

# 3. Fall back to original Projects profile subdirectory detection
case "$cwd" in
    */Projects/work*)
        echo "work"
        ;;
    */Projects/pjbeyer*)
        echo "pjbeyer"
        ;;
    */Projects/play*)
        echo "play"
        ;;
    */Projects/home*)
        echo "home"
        ;;
    *)
        echo "unknown"
        ;;
esac
