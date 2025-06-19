#!/bin/bash
# Don't use 'set -e' - we want to handle errors gracefully
set -u  # Error on undefined variables

echo "🔍 Running validation checks..."

# Basic validation with graceful fallbacks
if ! command -v gh >/dev/null 2>&1; then
  echo "⚠️ GitHub CLI not found - some features may be limited"
  echo "VALIDATION_WARNINGS=gh_cli_missing" >> $GITHUB_ENV
elif ! gh auth status >/dev/null 2>&1; then
  echo "⚠️ GitHub CLI not authenticated - will use limited permissions"
  echo "VALIDATION_WARNINGS=gh_auth_missing" >> $GITHUB_ENV
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "❌ Anthropic API key required - cannot proceed with analysis"
  echo "Please add ANTHROPIC_API_KEY to your repository secrets"
  echo "VALIDATION_FAILED=api_key_missing" >> $GITHUB_ENV
  exit 1
fi

# Permission checks with error handling
echo "🔐 Checking permissions..."
if [ -z "${VALIDATION_WARNINGS:-}" ]; then
  PUSH_PERMISSION=$(gh api repos/$GITHUB_REPOSITORY --jq '.permissions.push // false' 2>/dev/null || echo "false")
  ISSUES_PERMISSION=$(gh api repos/$GITHUB_REPOSITORY --jq '.permissions.admin // .permissions.push // false' 2>/dev/null || echo "false")
else
  echo "⚠️ Skipping permission checks due to GitHub CLI issues"
  PUSH_PERMISSION="false"
  ISSUES_PERMISSION="false"
fi

echo "✅ Validation complete:"
echo "   - GitHub CLI: $([ -z "${VALIDATION_WARNINGS:-}" ] && echo "authenticated" || echo "warning")"
echo "   - API key: provided"
echo "   - Push permission: $PUSH_PERMISSION"
echo "   - Issues permission: $ISSUES_PERMISSION"

# Create working directory
mkdir -p .watchdog || {
  echo "⚠️ Could not create .watchdog directory - using /tmp"
  mkdir -p /tmp/watchdog
  ln -sf /tmp/watchdog .watchdog
}

# Store permissions for later use
cat > .watchdog/permissions.json << EOF
{
  "can_create_branches": $PUSH_PERMISSION,
  "can_create_issues": $ISSUES_PERMISSION,
  "can_create_prs": $PUSH_PERMISSION,
  "create_fixes_enabled": $([ "${CREATE_FIXES:-false}" == "true" ] && [ "$PUSH_PERMISSION" == "true" ] && echo "true" || echo "false"),
  "validation_warnings": "${VALIDATION_WARNINGS:-none}"
}
EOF