#!/bin/bash

# Extract and ensure outputs are set from Claude execution
# This script parses JSON output from Claude instead of echo commands

echo "🔧 Extracting outputs from Claude execution..."

# Initialize default values
SEVERITY="unknown"
ACTION_TAKEN="analysis_failed"
ISSUE_NUMBER=""
PR_NUMBER=""
TESTS_PASSING=""

# Check if Claude execution succeeded and extract outputs
if [ "$CLAUDE_CONCLUSION" = "success" ] && [ -f "$CLAUDE_EXECUTION_FILE" ]; then
  echo "📄 Parsing Claude execution log for JSON output..."
  
  if command -v jq >/dev/null 2>&1; then
    echo "🔍 Searching for JSON output in execution log..."
    
    # Extract the last JSON block from Claude's response
    # Look for JSON in assistant messages
    JSON_OUTPUT=$(jq -r '.[] | select(.role == "assistant") | .content' "$CLAUDE_EXECUTION_FILE" 2>/dev/null | \
      grep -o '{[^}]*"severity"[^}]*}' | tail -1 2>/dev/null || echo "")
    
    if [ -n "$JSON_OUTPUT" ]; then
      echo "📋 Found JSON output: $JSON_OUTPUT"
      
      # Parse each field from the JSON with error handling
      SEVERITY=$(echo "$JSON_OUTPUT" | jq -r '.severity // "unknown"' 2>/dev/null || echo "unknown")
      ACTION_TAKEN=$(echo "$JSON_OUTPUT" | jq -r '.action_taken // "none"' 2>/dev/null || echo "none") 
      ISSUE_NUMBER=$(echo "$JSON_OUTPUT" | jq -r '.issue_number // empty' 2>/dev/null || echo "")
      PR_NUMBER=$(echo "$JSON_OUTPUT" | jq -r '.pr_number // empty' 2>/dev/null || echo "")
      TESTS_PASSING=$(echo "$JSON_OUTPUT" | jq -r '.tests_passing // "unknown"' 2>/dev/null || echo "unknown")
      
      # Handle null values properly
      [ "$ISSUE_NUMBER" = "null" ] && ISSUE_NUMBER=""
      [ "$PR_NUMBER" = "null" ] && PR_NUMBER=""
      [ "$TESTS_PASSING" = "null" ] && TESTS_PASSING="unknown"
      
      echo "✅ Parsed JSON successfully:"
      echo "   - Severity: $SEVERITY"
      echo "   - Action taken: $ACTION_TAKEN"  
      echo "   - Issue number: ${ISSUE_NUMBER:-'(none)'}"
      echo "   - PR number: ${PR_NUMBER:-'(none)'}"
      echo "   - Tests passing: $TESTS_PASSING"
      
    else
      echo "⚠️ No valid JSON output found in Claude response"
      echo "🔍 Searching for fallback patterns..."
      
      # Fallback: try to find any severity mention in the text
      CONTENT=$(jq -r '.[] | select(.role == "assistant") | .content' "$CLAUDE_EXECUTION_FILE" 2>/dev/null || echo "")
      if echo "$CONTENT" | grep -qi "severity.*high"; then
        SEVERITY="high"
      elif echo "$CONTENT" | grep -qi "severity.*medium"; then
        SEVERITY="medium"
      elif echo "$CONTENT" | grep -qi "severity.*low"; then
        SEVERITY="low"
      elif echo "$CONTENT" | grep -qi "severity.*critical"; then
        SEVERITY="critical"
      fi
      
      # Set reasonable defaults if we found any analysis
      if [ "$SEVERITY" != "unknown" ]; then
        ACTION_TAKEN="analysis_completed"
      fi
    fi
  else
    echo "⚠️ jq not available - using basic text parsing"
    
    # Basic fallback without jq
    if [ -f "$CLAUDE_EXECUTION_FILE" ]; then
      CONTENT=$(cat "$CLAUDE_EXECUTION_FILE" 2>/dev/null || echo "")
      if echo "$CONTENT" | grep -qi "severity.*medium"; then
        SEVERITY="medium"
        ACTION_TAKEN="analysis_completed"
      fi
    fi
  fi
else
  echo "⚠️ Claude analysis failed or no execution file - using fallback values"
  echo "   Claude conclusion: ${CLAUDE_CONCLUSION:-'unknown'}"
  echo "   Execution file exists: $([ -f "$CLAUDE_EXECUTION_FILE" ] && echo 'yes' || echo 'no')"
fi

# Validate severity values
case "$SEVERITY" in
  ignore|low|medium|high|critical) ;;
  *) SEVERITY="unknown" ;;
esac

# Validate action_taken values  
case "$ACTION_TAKEN" in
  issue_created|issue_updated|pr_created|pr_updated|tests_fixed|none|analysis_completed|analysis_failed) ;;
  *) ACTION_TAKEN="none" ;;
esac

# Set outputs
echo "severity=$SEVERITY" >> $GITHUB_OUTPUT
echo "action_taken=$ACTION_TAKEN" >> $GITHUB_OUTPUT
echo "issue_number=$ISSUE_NUMBER" >> $GITHUB_OUTPUT
echo "pr_number=$PR_NUMBER" >> $GITHUB_OUTPUT
echo "tests_passing=$TESTS_PASSING" >> $GITHUB_OUTPUT

echo "✅ GitHub Action outputs set:"
echo "   - severity=$SEVERITY"
echo "   - action_taken=$ACTION_TAKEN"
echo "   - issue_number=${ISSUE_NUMBER:-'(empty)'}"
echo "   - pr_number=${PR_NUMBER:-'(empty)'}"
echo "   - tests_passing=$TESTS_PASSING"