#!/bin/bash

# Simple output extraction - just read the JSON file Claude created

echo "🔧 Extracting outputs from Claude analysis..."

# Default values
SEVERITY="unknown"
ACTION_TAKEN="analysis_failed"
ISSUE_NUMBER=""
PR_NUMBER=""
TESTS_PASSING=""

# Check if Claude created the result file
if [ -f ".watchdog/analysis-result.json" ]; then
  echo "📄 Found analysis result file"
  
  if command -v jq >/dev/null 2>&1; then
    # Parse with jq
    SEVERITY=$(jq -r '.severity // "unknown"' .watchdog/analysis-result.json 2>/dev/null || echo "unknown")
    ACTION_TAKEN=$(jq -r '.action_taken // "none"' .watchdog/analysis-result.json 2>/dev/null || echo "none")
    ISSUE_NUMBER=$(jq -r '.issue_number // empty' .watchdog/analysis-result.json 2>/dev/null || echo "")
    PR_NUMBER=$(jq -r '.pr_number // empty' .watchdog/analysis-result.json 2>/dev/null || echo "")
    TESTS_PASSING=$(jq -r '.tests_passing // "unknown"' .watchdog/analysis-result.json 2>/dev/null || echo "unknown")
    
    # Clean up null values
    [ "$ISSUE_NUMBER" = "null" ] && ISSUE_NUMBER=""
    [ "$PR_NUMBER" = "null" ] && PR_NUMBER=""
    [ "$TESTS_PASSING" = "null" ] && TESTS_PASSING="unknown"
    
    echo "✅ Successfully parsed analysis results"
  else
    echo "⚠️ jq not available, using fallback"
    SEVERITY="medium"
    ACTION_TAKEN="analysis_completed"
  fi
else
  echo "⚠️ No analysis result file found - Claude may have failed"
fi

# Set GitHub Action outputs
echo "severity=$SEVERITY" >> $GITHUB_OUTPUT
echo "action_taken=$ACTION_TAKEN" >> $GITHUB_OUTPUT
echo "issue_number=$ISSUE_NUMBER" >> $GITHUB_OUTPUT
echo "pr_number=$PR_NUMBER" >> $GITHUB_OUTPUT
echo "tests_passing=$TESTS_PASSING" >> $GITHUB_OUTPUT

echo "✅ Outputs set: severity=$SEVERITY, action_taken=$ACTION_TAKEN"