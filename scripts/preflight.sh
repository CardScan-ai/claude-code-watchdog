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

# Gather existing issues/PRs with error handling
echo "📋 Gathering existing issues and PRs..."
WORKFLOW_PATTERN="Watchdog \\\\[${GITHUB_WORKFLOW:-unknown}\\\\]"

# Find related open issues
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

# Gather recent workflow history
echo "📊 Gathering workflow run history..."
gh api repos/$GITHUB_REPOSITORY/actions/workflows \
  --jq ".workflows[] | select(.name == \"$GITHUB_WORKFLOW\") | .id" | head -1 > .watchdog/workflow-id.txt

if [ -s .watchdog/workflow-id.txt ]; then
  WORKFLOW_ID=$(cat .watchdog/workflow-id.txt)
  gh api repos/$GITHUB_REPOSITORY/actions/workflows/$WORKFLOW_ID/runs \
    --jq '.workflow_runs[0:20] | .[] | {id, run_number, status, conclusion, created_at, head_sha, head_commit: {message: .head_commit.message, author: .head_commit.author.name}}' \
    > .watchdog/recent-runs.json
  
  # Calculate failure statistics
  TOTAL_RUNS=$(jq length .watchdog/recent-runs.json)
  FAILED_RUNS=$(jq '[.[] | select(.conclusion == "failure")] | length' .watchdog/recent-runs.json)
  SUCCESS_RUNS=$(jq '[.[] | select(.conclusion == "success")] | length' .watchdog/recent-runs.json)
  
  # Calculate failure rate
  if [ "$TOTAL_RUNS" -gt 0 ]; then
    FAILURE_RATE=$(echo "scale=2; $FAILED_RUNS * 100 / $TOTAL_RUNS" | bc -l 2>/dev/null || echo "0")
  else
    FAILURE_RATE="0"
  fi
  
  # Determine pattern
  if (( $(echo "$FAILURE_RATE > 80" | bc -l 2>/dev/null || echo "0") )); then
    PATTERN="chronic"
  elif (( $(echo "$FAILURE_RATE > 50" | bc -l 2>/dev/null || echo "0") )); then
    PATTERN="frequent"
  elif (( $(echo "$FAILURE_RATE > 20" | bc -l 2>/dev/null || echo "0") )); then
    PATTERN="intermittent"
  else
    PATTERN="isolated"
  fi
  
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

# Gather recent commits (potential causes)
echo "📝 Gathering recent commits..."
if ! gh api repos/$GITHUB_REPOSITORY/commits \
  --jq '.[] | {sha: .sha[0:8], message: .commit.message, author: .commit.author.name, date: .commit.author.date}' \
  > .watchdog/recent-commits.json 2>/dev/null; then
  echo "⚠️ Could not fetch recent commits - using empty list"
  echo "[]" > .watchdog/recent-commits.json
fi

# Find and catalog test output files
echo "🔍 Finding test output files..."
find . -type f \( \
  -name "*.xml" -o \
  -name "*.json" -o \
  -name "*.log" -o \
  -name "*.tap" -o \
  -name "*.trx" \
\) | grep -E "(test|spec|junit|report|result)" | head -50 > .watchdog/test-files.txt

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
  "existing_issues_count": $(jq length .watchdog/existing-issues.json),
  "existing_prs_count": $(jq length .watchdog/existing-prs.json),
  "recent_failures": $(jq '[.[] | select(.conclusion == "failure")] | length' .watchdog/recent-runs.json),
  "test_files_found": $(wc -l < .watchdog/test-files.txt | tr -d ' '),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "✅ Context gathering complete:"
echo "   - $(jq -r .existing_issues_count .watchdog/context-summary.json) existing issues found"
echo "   - $(jq -r .existing_prs_count .watchdog/context-summary.json) existing PRs found"  
echo "   - $(jq -r .recent_failures .watchdog/context-summary.json) recent failures in last 20 runs"
echo "   - $(jq -r .test_files_found .watchdog/context-summary.json) test output files found"
echo "   - Failure rate: $(jq -r .failure_rate_percent .watchdog/failure-analysis.json)% ($(jq -r .pattern .watchdog/failure-analysis.json) pattern)"