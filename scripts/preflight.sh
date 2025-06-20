#!/bin/bash
# Don't use 'set -e' - we want to handle errors gracefully
set -u  # Error on undefined variables

echo "📊 Gathering context data..."

# Check if we can proceed
if [ -f ".watchdog/permissions.json" ] && grep -q "gh_cli_missing\|gh_auth_missing" .watchdog/permissions.json 2>/dev/null; then
  echo "⚠️ Limited GitHub access - creating minimal context"
  # Create minimal context files
  echo "[]" > .watchdog/existing-issues.json
  echo "[]" > .watchdog/existing-prs.json
  echo "[]" > .watchdog/recent-runs.json
  echo "[]" > .watchdog/recent-commits.json
  echo "" > .watchdog/test-files.txt
  
  cat > .watchdog/context-summary.json << EOF
{
  "workflow": "${GITHUB_WORKFLOW:-unknown}",
  "run_id": "${GITHUB_RUN_ID:-unknown}",
  "repository": "${GITHUB_REPOSITORY:-unknown}",
  "existing_issues_count": 0,
  "existing_prs_count": 0,
  "recent_failures": 0,
  "test_files_found": 0,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "limited_context"
}
EOF
  
  cat > .watchdog/failure-analysis.json << EOF
{
  "total_runs": 0,
  "failed_runs": 0,
  "failure_rate_percent": 0,
  "pattern": "unknown"
}
EOF
  
  echo "⚠️ Context gathering completed with limited data"
  exit 0
fi

# Check if safe mode is enabled
if [ "${SAFE_MODE:-false}" = "true" ]; then
  echo "🔒 Safe mode enabled - skipping external content (issues, PRs, commits)"
  echo "[]" > .watchdog/existing-issues.json
  echo "[]" > .watchdog/existing-prs.json
  echo "[]" > .watchdog/recent-commits.json
  
  # Still gather workflow runs (internal data) and skip to the end
  echo "📊 Gathering workflow run history (safe mode only)..."
  SKIP_EXTERNAL_DATA=true
else
  echo "📋 Gathering existing issues and PRs..."
  SKIP_EXTERNAL_DATA=false
fi

WORKFLOW_PATTERN="Watchdog \\\\[${GITHUB_WORKFLOW:-unknown}\\\\]"

# Find related open issues (unless in safe mode)
if [ "$SKIP_EXTERNAL_DATA" = "false" ]; then
  if ! gh api repos/$GITHUB_REPOSITORY/issues \
    --jq ".[] | select(.title | test(\"$WORKFLOW_PATTERN\")) | select(.state == \"open\") | {number, title, created_at, updated_at, labels: [.labels[].name], body}" \
    > .watchdog/existing-issues.json 2>/dev/null; then
    echo "⚠️ Could not fetch existing issues - using empty list"
    echo "[]" > .watchdog/existing-issues.json
  fi

  # Find related open PRs  
  if ! gh api repos/$GITHUB_REPOSITORY/pulls \
    --jq ".[] | select(.title | test(\"$WORKFLOW_PATTERN\")) | select(.state == \"open\") | {number, title, created_at, updated_at, head: .head.ref, body}" \
    > .watchdog/existing-prs.json 2>/dev/null; then
    echo "⚠️ Could not fetch existing PRs - using empty list"
    echo "[]" > .watchdog/existing-prs.json
  fi
fi

# Gather recent workflow history
echo "📊 Gathering workflow run history..."
if ! gh api repos/$GITHUB_REPOSITORY/actions/workflows \
  --jq ".workflows[] | select(.name == \"$GITHUB_WORKFLOW\") | .id" | head -1 > .watchdog/workflow-id.txt 2>/dev/null; then
  echo "⚠️ Could not fetch workflow ID - creating empty workflow data"
  echo "" > .watchdog/workflow-id.txt
fi

if [ -s .watchdog/workflow-id.txt ]; then
  WORKFLOW_ID=$(cat .watchdog/workflow-id.txt)
  if ! gh api repos/$GITHUB_REPOSITORY/actions/workflows/$WORKFLOW_ID/runs \
    --jq '.workflow_runs[0:20] | map({id, run_number, status, conclusion, created_at, head_sha, head_commit: {message: .head_commit.message, author: .head_commit.author.name}})' \
    > .watchdog/recent-runs.json 2>/dev/null; then
    echo "⚠️ Could not fetch workflow runs - using empty list"
    echo "[]" > .watchdog/recent-runs.json
  fi
  
  # Calculate failure statistics with error handling
  if [ -f ".watchdog/recent-runs.json" ] && jq empty .watchdog/recent-runs.json 2>/dev/null; then
    TOTAL_RUNS=$(jq length .watchdog/recent-runs.json 2>/dev/null || echo "0")
    FAILED_RUNS=$(jq '[.[] | select(.conclusion == "failure")] | length' .watchdog/recent-runs.json 2>/dev/null || echo "0")
    SUCCESS_RUNS=$(jq '[.[] | select(.conclusion == "success")] | length' .watchdog/recent-runs.json 2>/dev/null || echo "0")
  else
    echo "⚠️ Invalid JSON in recent-runs.json - using zero values"
    TOTAL_RUNS=0
    FAILED_RUNS=0
    SUCCESS_RUNS=0
  fi
  
  # Calculate failure rate with safety checks
  if [ "$TOTAL_RUNS" -gt 0 ] 2>/dev/null; then
    # Use arithmetic expansion instead of bc for better compatibility
    FAILURE_RATE=$((FAILED_RUNS * 100 / TOTAL_RUNS))
  else
    FAILURE_RATE=0
  fi
  
  # Determine pattern with safety checks using arithmetic comparison
  if [ "$FAILURE_RATE" -gt 80 ] 2>/dev/null; then
    PATTERN="chronic"
  elif [ "$FAILURE_RATE" -gt 50 ] 2>/dev/null; then
    PATTERN="frequent"
  elif [ "$FAILURE_RATE" -gt 20 ] 2>/dev/null; then
    PATTERN="intermittent"
  else
    PATTERN="isolated"
  fi
  
  # Ensure all variables have valid numeric values and debug
  TOTAL_RUNS=${TOTAL_RUNS:-0}
  FAILED_RUNS=${FAILED_RUNS:-0} 
  SUCCESS_RUNS=${SUCCESS_RUNS:-0}
  FAILURE_RATE=${FAILURE_RATE:-0}
  PATTERN=${PATTERN:-"unknown"}
  
  # Debug output
  echo "DEBUG: TOTAL_RUNS='$TOTAL_RUNS' FAILED_RUNS='$FAILED_RUNS' SUCCESS_RUNS='$SUCCESS_RUNS' FAILURE_RATE='$FAILURE_RATE' PATTERN='$PATTERN'"
  
  # Validate they are actually numbers
  case "$TOTAL_RUNS" in ''|*[!0-9]*) TOTAL_RUNS=0 ;; esac
  case "$FAILED_RUNS" in ''|*[!0-9]*) FAILED_RUNS=0 ;; esac  
  case "$SUCCESS_RUNS" in ''|*[!0-9]*) SUCCESS_RUNS=0 ;; esac
  case "$FAILURE_RATE" in ''|*[!0-9]*) FAILURE_RATE=0 ;; esac
  
  cat > .watchdog/failure-analysis.json << EOF
{
  "total_runs": $TOTAL_RUNS,
  "failed_runs": $FAILED_RUNS,
  "success_runs": $SUCCESS_RUNS,
  "failure_rate_percent": $FAILURE_RATE,
  "pattern": "$PATTERN"
}
EOF
else
  cat > .watchdog/failure-analysis.json << EOF
{
  "total_runs": 0,
  "failed_runs": 0,
  "failure_rate_percent": 0,
  "pattern": "unknown"
}
EOF
fi

# Gather recent commits (potential causes) - skip in safe mode
if [ "$SKIP_EXTERNAL_DATA" = "false" ]; then
  echo "📝 Gathering recent commits..."
  if ! gh api repos/$GITHUB_REPOSITORY/commits \
    --jq '.[] | {sha: .sha[0:8], message: .commit.message, author: .commit.author.name, date: .commit.author.date}' \
    > .watchdog/recent-commits.json 2>/dev/null; then
    echo "⚠️ Could not fetch recent commits - using empty list"
    echo "[]" > .watchdog/recent-commits.json
  fi
fi

# Find and read test output files (exclude .git and node_modules)
echo "🔍 Finding test output files..."
find . -type f \( \
  -name "*.xml" -o \
  -name "*.json" -o \
  -name "*.log" -o \
  -name "*.tap" -o \
  -name "*.trx" \
\) -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.watchdog/*" \
| grep -E "(test|spec|junit|report|result)" | head -10 > .watchdog/test-files.txt

# Read actual test output content (limited to avoid token waste)
echo "📄 Reading test output content..."
mkdir -p .watchdog/test-outputs
TEST_COUNT=0
while IFS= read -r file && [ $TEST_COUNT -lt 5 ]; do
  if [ -f "$file" ] && [ -s "$file" ]; then
    echo "Reading: $file"
    # Copy file with size limit to avoid massive files
    head -100 "$file" > ".watchdog/test-outputs/$(basename "$file")"
    TEST_COUNT=$((TEST_COUNT + 1))
  fi
done < .watchdog/test-files.txt

# Gather test results from specified path
echo "📊 Gathering test results..."
mkdir -p .watchdog/test-outputs
# Clear any existing test result files
find .watchdog/test-outputs -type f -delete 2>/dev/null || true

if [ -n "${TEST_RESULTS_PATH:-}" ]; then
  echo "🔍 Looking for test results at: $TEST_RESULTS_PATH"
  
  # Use find with glob patterns to locate test result files
  # Support both direct paths and glob patterns
  FOUND_FILES=0
  
  # Use a much simpler and safer approach
  # Just use shell globbing directly but be very specific
  echo "🔍 Expanding pattern: $TEST_RESULTS_PATH"
  
  # Disable globbing temporarily, then re-enable to control expansion
  set -f
  IFS=' ' read -ra PATTERNS <<< "$TEST_RESULTS_PATH"
  set +f
  
  for pattern in "${PATTERNS[@]}"; do
    echo "📋 Processing pattern: $pattern"
    
    # Use shell globbing but validate paths
    for file in $pattern; do
      # Only process if file exists and is not in node_modules
      if [ -f "$file" ] && [[ ! "$file" =~ node_modules ]]; then
        echo "📄 Found test result file: $file"
        SAFE_NAME=$(echo "$file" | sed 's|/|_|g' | sed 's|^_||')
        cp "$file" ".watchdog/test-outputs/$SAFE_NAME" 2>/dev/null || {
          echo "⚠️ Could not copy $file"
        }
        FOUND_FILES=$((FOUND_FILES + 1))
      elif [ -f "$file" ] && [[ "$file" =~ node_modules ]]; then
        echo "⚠️ Skipping node_modules file: $file"
      fi
    done
  done
  
  if [ "$FOUND_FILES" -eq 0 ]; then
    echo "⚠️ No test result files found at pattern: $TEST_RESULTS_PATH"
    echo "📁 Available files in current directory:"
    find . -name "*.xml" -o -name "*.json" -o -name "*.log" -o -name "*test*" -o -name "*result*" | head -10 || echo "   No common test files found"
  else
    echo "✅ Found $FOUND_FILES test result files"
    echo "📁 Files copied to .watchdog/test-outputs/:"
    ls -la .watchdog/test-outputs/ 2>/dev/null || echo "   Directory not accessible"
  fi
else
  echo "⚠️ No test results path specified"
fi

# Create context summary
echo "📄 Creating context summary..."
cat > .watchdog/context-summary.json << EOF
{
  "workflow": "$GITHUB_WORKFLOW",
  "run_id": "$GITHUB_RUN_ID",
  "run_attempt": "$GITHUB_RUN_ATTEMPT",
  "repository": "$GITHUB_REPOSITORY",
  "ref": "$GITHUB_REF",
  "sha": "$GITHUB_SHA",
  "actor": "$GITHUB_ACTOR",
  "event_name": "$GITHUB_EVENT_NAME",
  "existing_issues_count": $(jq length .watchdog/existing-issues.json 2>/dev/null || echo "0"),
  "existing_prs_count": $(jq length .watchdog/existing-prs.json 2>/dev/null || echo "0"),
  "recent_failures": $(jq '[.[] | select(.conclusion == "failure")] | length' .watchdog/recent-runs.json 2>/dev/null || echo "0"),
  "test_files_found": $(wc -l < .watchdog/test-files.txt 2>/dev/null | tr -d ' ' || echo "0"),
  "test_results_files": $(find .watchdog/test-outputs -type f 2>/dev/null | wc -l | tr -d ' ' || echo "0"),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "✅ Context gathering complete:"
echo "   - $(jq -r .existing_issues_count .watchdog/context-summary.json 2>/dev/null || echo "0") existing issues found"
echo "   - $(jq -r .existing_prs_count .watchdog/context-summary.json 2>/dev/null || echo "0") existing PRs found"  
echo "   - $(jq -r .recent_failures .watchdog/context-summary.json 2>/dev/null || echo "0") recent failures in last 20 runs"
echo "   - $(jq -r .test_files_found .watchdog/context-summary.json 2>/dev/null || echo "0") test files found"
echo "   - $(jq -r .test_results_files .watchdog/context-summary.json 2>/dev/null || echo "0") test result files collected"
echo "   - Failure rate: $(jq -r .failure_rate_percent .watchdog/failure-analysis.json 2>/dev/null || echo "0")% ($(jq -r .pattern .watchdog/failure-analysis.json 2>/dev/null || echo "unknown") pattern)"