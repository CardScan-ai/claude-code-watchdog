#!/bin/bash

# Extract and ensure outputs are set from Claude execution

echo "🔧 Extracting outputs from Claude execution..."

# Initialize default values
SEVERITY="unknown"
ACTION_TAKEN="analysis_failed"
ISSUE_NUMBER=""
PR_NUMBER=""
TESTS_PASSING=""

# Check if Claude execution succeeded and extract outputs
if [ "$CLAUDE_CONCLUSION" = "success" ] && [ -f "$CLAUDE_EXECUTION_FILE" ]; then
  echo "📄 Parsing Claude execution log..."
  
  # Extract outputs from execution log using jq
  if command -v jq >/dev/null 2>&1; then
    echo "🔍 Searching for outputs in execution log..."
    
    # Debug: show what we're working with
    echo "📄 Execution file exists: $(ls -la "$CLAUDE_EXECUTION_FILE" 2>/dev/null || echo 'NOT FOUND')"
    
    # Look for GitHub Action outputs in the execution log - try multiple patterns
    EXEC_FILE="$CLAUDE_EXECUTION_FILE"
    
    # Method 1: Look for explicit output commands
    SEVERITY=$(grep -o 'severity=[a-z]*' "$EXEC_FILE" 2>/dev/null | tail -1 | cut -d= -f2 || echo "")
    ACTION_TAKEN=$(grep -o 'action_taken=[a-z_]*' "$EXEC_FILE" 2>/dev/null | tail -1 | cut -d= -f2 || echo "")
    ISSUE_NUMBER=$(grep -o 'issue_number=[0-9]*' "$EXEC_FILE" 2>/dev/null | tail -1 | cut -d= -f2 || echo "")
    PR_NUMBER=$(grep -o 'pr_number=[0-9]*' "$EXEC_FILE" 2>/dev/null | tail -1 | cut -d= -f2 || echo "")
    TESTS_PASSING=$(grep -o 'tests_passing=[a-z]*' "$EXEC_FILE" 2>/dev/null | tail -1 | cut -d= -f2 || echo "")
    
    # Method 2: If grep didn't find outputs, try jq parsing
    if [ -z "$SEVERITY" ]; then
      SEVERITY=$(jq -r '.[] | select(.role == "assistant") | .content' "$EXEC_FILE" 2>/dev/null | grep -o 'severity=[a-z]*' | tail -1 | cut -d= -f2 || echo "")
    fi
    
    echo "🔍 Found outputs: severity='$SEVERITY', action_taken='$ACTION_TAKEN'"
  fi
  
  # Clean up empty values
  [ "$SEVERITY" = "" ] && SEVERITY="unknown"
  [ "$ACTION_TAKEN" = "" ] && ACTION_TAKEN="none"
else
  echo "⚠️ Claude analysis failed or no execution file - using fallback values"
fi

# Set outputs
echo "severity=$SEVERITY" >> $GITHUB_OUTPUT
echo "action_taken=$ACTION_TAKEN" >> $GITHUB_OUTPUT
echo "issue_number=$ISSUE_NUMBER" >> $GITHUB_OUTPUT
echo "pr_number=$PR_NUMBER" >> $GITHUB_OUTPUT
echo "tests_passing=$TESTS_PASSING" >> $GITHUB_OUTPUT

echo "✅ Outputs set: severity=$SEVERITY, action_taken=$ACTION_TAKEN"