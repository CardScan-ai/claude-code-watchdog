#!/bin/bash
# Don't use 'set -e' - we want to handle errors gracefully
set -u  # Error on undefined variables

echo "📝 Preparing enhanced prompt with context data..."

# Create the enhanced prompt with actual context data
cat > .watchdog/claude-prompt.md << 'PROMPT_EOF'
# Test Failure Analysis and Remediation

You are analyzing test failures to help development teams focus on real issues vs. noise.

## Configuration
- Create issues: ${CREATE_ISSUES}
- Create fixes: ${CREATE_FIXES}
- Rerun tests: ${RERUN_TESTS}
- Severity threshold: ${SEVERITY_THRESHOLD}

## Context Data

### Workflow Information
PROMPT_EOF

# Append context summary
if [ -f ".watchdog/context-summary.json" ]; then
  echo "```json" >> .watchdog/claude-prompt.md
  cat .watchdog/context-summary.json >> .watchdog/claude-prompt.md
  echo "```" >> .watchdog/claude-prompt.md
else
  echo "No workflow context available" >> .watchdog/claude-prompt.md
fi

# Append failure analysis
echo "" >> .watchdog/claude-prompt.md
echo "### Failure Pattern Analysis" >> .watchdog/claude-prompt.md
if [ -f ".watchdog/failure-analysis.json" ]; then
  echo "```json" >> .watchdog/claude-prompt.md
  cat .watchdog/failure-analysis.json >> .watchdog/claude-prompt.md
  echo "```" >> .watchdog/claude-prompt.md
else
  echo "No failure pattern data available" >> .watchdog/claude-prompt.md
fi

# Append existing issues
echo "" >> .watchdog/claude-prompt.md
echo "### Existing Related Issues" >> .watchdog/claude-prompt.md
if [ -f ".watchdog/existing-issues.json" ] && [ -s ".watchdog/existing-issues.json" ]; then
  ISSUE_COUNT=$(jq length .watchdog/existing-issues.json 2>/dev/null || echo "0")
  if [ "$ISSUE_COUNT" -gt 0 ]; then
    echo "```json" >> .watchdog/claude-prompt.md
    cat .watchdog/existing-issues.json >> .watchdog/claude-prompt.md  
    echo "```" >> .watchdog/claude-prompt.md
  else
    echo "No existing related issues found" >> .watchdog/claude-prompt.md
  fi
else
  echo "No existing issues data available" >> .watchdog/claude-prompt.md
fi

# Append existing PRs
echo "" >> .watchdog/claude-prompt.md
echo "### Existing Related PRs" >> .watchdog/claude-prompt.md
if [ -f ".watchdog/existing-prs.json" ] && [ -s ".watchdog/existing-prs.json" ]; then
  PR_COUNT=$(jq length .watchdog/existing-prs.json 2>/dev/null || echo "0")
  if [ "$PR_COUNT" -gt 0 ]; then
    echo "```json" >> .watchdog/claude-prompt.md
    cat .watchdog/existing-prs.json >> .watchdog/claude-prompt.md
    echo "```" >> .watchdog/claude-prompt.md
  else
    echo "No existing related PRs found" >> .watchdog/claude-prompt.md
  fi
else
  echo "No existing PRs data available" >> .watchdog/claude-prompt.md
fi

# Append recent commits
echo "" >> .watchdog/claude-prompt.md
echo "### Recent Commits (Potential Causes)" >> .watchdog/claude-prompt.md
if [ -f ".watchdog/recent-commits.json" ] && [ -s ".watchdog/recent-commits.json" ]; then
  echo "```json" >> .watchdog/claude-prompt.md
  head -10 .watchdog/recent-commits.json >> .watchdog/claude-prompt.md  # Limit to first 10 commits
  echo "```" >> .watchdog/claude-prompt.md
else
  echo "No recent commits data available" >> .watchdog/claude-prompt.md
fi

# Append test files list
echo "" >> .watchdog/claude-prompt.md
echo "### Available Test Output Files" >> .watchdog/claude-prompt.md
if [ -f ".watchdog/test-files.txt" ] && [ -s ".watchdog/test-files.txt" ]; then
  echo "```" >> .watchdog/claude-prompt.md
  cat .watchdog/test-files.txt >> .watchdog/claude-prompt.md
  echo "```" >> .watchdog/claude-prompt.md
else
  echo "No test output files found" >> .watchdog/claude-prompt.md
fi

# Add the rest of the prompt
cat >> .watchdog/claude-prompt.md << 'PROMPT_EOF'

## Your Tasks

1. **Analyze the Test Failures**
   - Parse test output files to understand what failed and why
   - Identify error types (timeouts, assertions, network, etc.)
   - Look for patterns in the failure messages

2. **Assess Severity Based on Context**
   - Use failure rate from failure analysis above
   - Chronic (80%+): Upgrade severity by 1-2 levels
   - Frequent (50-79%): Upgrade severity by 1 level  
   - Intermittent (20-49%): Use base severity
   - Isolated (<20%): Consider downgrading unless critical

3. **Manage Issues Intelligently**
   - Check existing issues above to avoid duplicates
   - Update existing issues rather than creating new ones
   - Use consistent naming: "Watchdog [${GITHUB_WORKFLOW}]: [description]"
   - Include failure patterns, recommendations, and context

4. **Implement Fixes (if enabled and appropriate)**
   - Only make changes you're confident about
   - Common fixes: timeouts, retries, selectors, deprecated APIs
   - Create PRs with clear descriptions of changes made
   - Check for existing fix PRs first

5. **Test Verification (if enabled)**
   - Re-run tests after applying fixes to verify they work
   - Set appropriate output values based on results

## Required Outputs
IMPORTANT: You MUST output these GitHub Action outputs using echo commands:

```bash
echo "severity=medium" >> $GITHUB_OUTPUT
echo "action_taken=issue_created" >> $GITHUB_OUTPUT
echo "issue_number=123" >> $GITHUB_OUTPUT
echo "pr_number=456" >> $GITHUB_OUTPUT
echo "tests_passing=true" >> $GITHUB_OUTPUT
```

Required outputs:
- `severity`: ignore|low|medium|high|critical
- `action_taken`: issue_created|issue_updated|pr_created|pr_updated|tests_fixed|none
- `issue_number`: If an issue was created or updated (number only)
- `pr_number`: If a PR was created or updated (number only)
- `tests_passing`: true|false|unknown (if rerun_tests enabled)

## Guidelines
- Be intelligent about severity - use failure patterns, not just error content
- Avoid creating noise - update existing issues when appropriate  
- Provide actionable recommendations in issues
- Only implement fixes you're confident will help
- Use clear, professional communication in issues and PRs

Begin your analysis now.
PROMPT_EOF

echo "✅ Enhanced prompt prepared with actual context data"
echo "📄 Prompt file: .watchdog/claude-prompt.md ($(wc -l < .watchdog/claude-prompt.md) lines)"