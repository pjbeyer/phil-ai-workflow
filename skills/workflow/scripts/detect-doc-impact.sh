#!/opt/homebrew/bin/bash
# detect-doc-impact.sh
# Analyzes git diff to detect if changes require documentation updates

set -euo pipefail

# Usage: detect-doc-impact.sh <base-branch> <feature-branch>
# Returns: 0 if doc impact detected, 1 if no impact

BASE_BRANCH="${1:-main}"
FEATURE_BRANCH="${2:-HEAD}"

detect_new_features() {
    # Check for new public functions, classes, APIs
    git diff "$BASE_BRANCH...$FEATURE_BRANCH" | grep -E '^\+.*\b(def |class |export |public )' &>/dev/null
}

detect_api_changes() {
    # Check for changes to existing APIs
    git diff "$BASE_BRANCH...$FEATURE_BRANCH" | grep -E '^\+.*\b(route|endpoint|@api|@route)' &>/dev/null
}

detect_architecture_changes() {
    # Check for structural changes
    git diff "$BASE_BRANCH...$FEATURE_BRANCH" --stat | grep -E '(src/|lib/|agents/|components/)' | grep -v test | wc -l | grep -v '^0$' &>/dev/null
}

detect_readme_changes() {
    # Check if README was modified
    git diff "$BASE_BRANCH...$FEATURE_BRANCH" --name-only | grep -i 'readme' &>/dev/null
}

main() {
    local doc_impact=false
    local reasons=()

    if detect_new_features; then
        doc_impact=true
        reasons+=("New public APIs or classes detected")
    fi

    if detect_api_changes; then
        doc_impact=true
        reasons+=("API or endpoint changes detected")
    fi

    if detect_architecture_changes; then
        doc_impact=true
        reasons+=("Architectural changes in source files")
    fi

    if detect_readme_changes; then
        # README was updated, less likely to need more docs
        doc_impact=false
    fi

    if [ "$doc_impact" = true ]; then
        echo "DOC_IMPACT_DETECTED"
        for reason in "${reasons[@]}"; do
            echo "  - $reason"
        done
        return 0
    else
        echo "NO_DOC_IMPACT"
        return 1
    fi
}

main "$@"
