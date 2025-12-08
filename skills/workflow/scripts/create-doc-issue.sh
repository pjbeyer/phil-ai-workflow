#!/opt/homebrew/bin/bash
# create-doc-issue.sh
# Creates a GitHub issue for documentation updates

set -euo pipefail

# Required arguments
FEATURE_NAME="$1"
ISSUE_NUMBER="$2"
ISSUE_TITLE="$3"
FEATURE_BRANCH="$4"
DOC_IMPACT_REASONS="$5"
BASE_BRANCH="${6:-main}"

# Get commit range
COMMIT_RANGE="$BASE_BRANCH..$FEATURE_BRANCH"

# Current date
DATE=$(date +"%Y-%m-%d")

# Load template
TEMPLATE_PATH="$HOME/.claude/skills/workflow/templates/doc-issue.md"

if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "Error: Template not found at $TEMPLATE_PATH"
    exit 1
fi

# Read template and substitute variables
ISSUE_BODY=$(cat "$TEMPLATE_PATH" | \
    sed "s/{FEATURE_NAME}/$FEATURE_NAME/g" | \
    sed "s/{ISSUE_NUMBER}/$ISSUE_NUMBER/g" | \
    sed "s|{ISSUE_TITLE}|$ISSUE_TITLE|g" | \
    sed "s|{FEATURE_BRANCH}|$FEATURE_BRANCH|g" | \
    sed "s|{DOC_IMPACT_REASONS}|$DOC_IMPACT_REASONS|g" | \
    sed "s|{COMMIT_RANGE}|$COMMIT_RANGE|g" | \
    sed "s/{DATE}/$DATE/g")

# Create GitHub issue
ISSUE_TITLE_TEXT="Documentation Update: $FEATURE_NAME"

if command -v op &>/dev/null; then
    # Use 1Password wrapper if available
    NEW_ISSUE=$(op plugin run -- gh issue create \
        --title "$ISSUE_TITLE_TEXT" \
        --body "$ISSUE_BODY" \
        --label "documentation" \
        --label "auto-generated")
else
    NEW_ISSUE=$(gh issue create \
        --title "$ISSUE_TITLE_TEXT" \
        --body "$ISSUE_BODY" \
        --label "documentation" \
        --label "auto-generated")
fi

echo "Created documentation issue: $NEW_ISSUE"
echo "$NEW_ISSUE"
