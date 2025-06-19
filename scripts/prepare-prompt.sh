#!/bin/bash

# Prepare context data for Claude analysis
# This script creates a markdown file with all the context data Claude needs

set -u  # Error on undefined variables

echo "📝 Preparing context data for Claude analysis..."

# Ensure .watchdog directory exists
mkdir -p .watchdog

# Start with the basic structure
{
  echo "# Test Failure Analysis Context"
  echo ""
  echo "## Configuration"
  echo "- Create issues: ${CREATE_ISSUES:-unknown}"
  echo "- Create fixes: ${CREATE_FIXES:-unknown}"  
  echo "- Rerun tests: ${RERUN_TESTS:-unknown}"
  echo "- Severity threshold: ${SEVERITY_THRESHOLD:-unknown}"
  echo "- Safe mode: ${SAFE_MODE:-false}"
  echo ""
  echo "## Context Data"
  echo ""
} > .watchdog/context-data.md

# Add workflow information
echo "### Workflow Information" >> .watchdog/context-data.md
if [ -f ".watchdog/context-summary.json" ]; then
  echo '```json' >> .watchdog/context-data.md
  cat .watchdog/context-summary.json >> .watchdog/context-data.md
  echo '```' >> .watchdog/context-data.md
else
  echo "No workflow context available" >> .watchdog/context-data.md
fi
echo "" >> .watchdog/context-data.md

# Add failure analysis
echo "### Failure Pattern Analysis" >> .watchdog/context-data.md
if [ -f ".watchdog/failure-analysis.json" ]; then
  echo '```json' >> .watchdog/context-data.md
  cat .watchdog/failure-analysis.json >> .watchdog/context-data.md
  echo '```' >> .watchdog/context-data.md
else
  echo "No failure pattern data available" >> .watchdog/context-data.md
fi
echo "" >> .watchdog/context-data.md

# Add existing issues (if not in safe mode)
echo "### Existing Related Issues" >> .watchdog/context-data.md
if [ "${SAFE_MODE:-false}" = "true" ]; then
  echo "Skipped in safe mode (security precaution)" >> .watchdog/context-data.md
elif [ -f ".watchdog/existing-issues.json" ] && [ -s ".watchdog/existing-issues.json" ]; then
  ISSUE_COUNT=$(jq length .watchdog/existing-issues.json 2>/dev/null || echo "0")
  if [ "$ISSUE_COUNT" -gt 0 ]; then
    echo '```json' >> .watchdog/context-data.md
    cat .watchdog/existing-issues.json >> .watchdog/context-data.md
    echo '```' >> .watchdog/context-data.md
  else
    echo "No existing related issues found" >> .watchdog/context-data.md
  fi
else
  echo "No existing issues data available" >> .watchdog/context-data.md
fi
echo "" >> .watchdog/context-data.md

# Add existing PRs (if not in safe mode)
echo "### Existing Related PRs" >> .watchdog/context-data.md
if [ "${SAFE_MODE:-false}" = "true" ]; then
  echo "Skipped in safe mode (security precaution)" >> .watchdog/context-data.md
elif [ -f ".watchdog/existing-prs.json" ] && [ -s ".watchdog/existing-prs.json" ]; then
  PR_COUNT=$(jq length .watchdog/existing-prs.json 2>/dev/null || echo "0")
  if [ "$PR_COUNT" -gt 0 ]; then
    echo '```json' >> .watchdog/context-data.md
    cat .watchdog/existing-prs.json >> .watchdog/context-data.md
    echo '```' >> .watchdog/context-data.md
  else
    echo "No existing related PRs found" >> .watchdog/context-data.md
  fi
else
  echo "No existing PRs data available" >> .watchdog/context-data.md
fi
echo "" >> .watchdog/context-data.md

# Add recent commits (if not in safe mode)
echo "### Recent Commits (Potential Causes)" >> .watchdog/context-data.md
if [ "${SAFE_MODE:-false}" = "true" ]; then
  echo "Skipped in safe mode (security precaution)" >> .watchdog/context-data.md
elif [ -f ".watchdog/recent-commits.json" ] && [ -s ".watchdog/recent-commits.json" ]; then
  echo '```json' >> .watchdog/context-data.md
  head -10 .watchdog/recent-commits.json >> .watchdog/context-data.md
  echo '```' >> .watchdog/context-data.md
else
  echo "No recent commits data available" >> .watchdog/context-data.md
fi
echo "" >> .watchdog/context-data.md

# Add test output content
echo "### Test Output Content" >> .watchdog/context-data.md
if [ -d ".watchdog/test-outputs" ] && [ "$(ls -A .watchdog/test-outputs 2>/dev/null)" ]; then
  for output_file in .watchdog/test-outputs/*; do
    if [ -f "$output_file" ]; then
      echo "" >> .watchdog/context-data.md
      echo "#### $(basename "$output_file")" >> .watchdog/context-data.md
      echo '```' >> .watchdog/context-data.md
      cat "$output_file" >> .watchdog/context-data.md
      echo '```' >> .watchdog/context-data.md
    fi
  done
else
  echo "No test output content available" >> .watchdog/context-data.md
fi
echo "" >> .watchdog/context-data.md

# Add available test files for reference
echo "### Available Test Files (for reference)" >> .watchdog/context-data.md
if [ -f ".watchdog/test-files.txt" ] && [ -s ".watchdog/test-files.txt" ]; then
  echo '```' >> .watchdog/context-data.md
  cat .watchdog/test-files.txt >> .watchdog/context-data.md
  echo '```' >> .watchdog/context-data.md
else
  echo "No test files found" >> .watchdog/context-data.md
fi

echo "✅ Context data prepared for Claude analysis"
echo "📄 Context file: .watchdog/context-data.md ($(wc -l < .watchdog/context-data.md) lines)"