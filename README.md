# Claude Code Watchdog

> AI-powered test failure analysis and automated remediation for GitHub Actions

![Artemis the Watchdog](./artemis-shark.png)

*Meet Artemis, your CI watchdog*

## Overview

Claude Code Watchdog automatically analyzes test failures in your CI/CD pipeline, providing intelligent insights and automated fixes. Instead of getting overwhelmed by flaky test notifications, get actionable analysis that helps you focus on real issues.

**Key capabilities:**
- **Intelligent Analysis**: AI-powered test failure analysis with pattern recognition
- **Failure Classification**: Distinguishes chronic issues from flaky tests based on failure rates
- **Automated Issues**: Creates detailed GitHub issues with context and actionable recommendations  
- **Self-Healing**: Implements fixes for common problems automatically
- **Smart Notifications**: Provides severity-based alerts to reduce noise

## Quick Start

Add this step to your workflow after your tests:

```yaml
- name: Test failure analysis
  if: failure()
  uses: cardscan-ai/claude-code-watchdog@v0.2
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    test_results_path: 'test-results/**/*.xml'  # Adjust to your test output location
```

When tests fail, the action will:
1. Analyze test outputs and failure patterns
2. Determine severity based on failure frequency  
3. Create or update GitHub issues with detailed analysis
4. Optionally implement automated fixes via pull requests

## Features

### Smart Failure Analysis
- **Pattern Recognition**: Distinguishes between chronic failures (80%+ fail rate) vs isolated incidents
- **Root Cause Detection**: Correlates failures with recent commits and changes
- **Test Output Parsing**: Understands JUnit XML, JSON reports, and log files
- **Historical Context**: Analyzes the last 20 workflow runs for trends

### Intelligent Issue Management
- **No Duplicates**: Updates existing issues instead of creating spam
- **Consistent Naming**: `Watchdog [Workflow Name]: Description` for easy filtering
- **Rich Context**: Includes failure patterns, recent commits, and actionable recommendations
- **Smart Labels**: Automatically tags with severity and failure type

### Automatic Fixes (Optional)
- **Safe Fixes**: Only implements changes it's confident about
- **Common Patterns**: Fixes timeouts, flaky selectors, deprecated APIs
- **PR Creation**: Creates branches and PRs with clear descriptions
- **Test Verification**: Can re-run tests to verify fixes work

### Failure Rate Intelligence
| Pattern | Failure Rate | Artemis Response |
|---------|--------------|------------------|
| 🔴 Chronic | 80%+ | Upgrades severity, immediate attention |
| 🟡 Frequent | 50-79% | Creates high-priority issues |
| 🟠 Intermittent | 20-49% | Standard monitoring and analysis |
| 🟢 Isolated | <20% | May downgrade severity, likely flaky |

## Usage Examples

### Basic Integration
Perfect for most CI workflows:

```yaml
name: CI with Watchdog

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: write      # For creating fix PRs
      issues: write        # For creating issues
      pull-requests: write # For creating PRs
    
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '18'
    
    - name: Install and test
      run: |
        npm ci
        npm test
      continue-on-error: true  # Let Artemis analyze failures
    
    - name: Artemis failure analysis
      if: failure()
      id: watchdog
      uses: cardscan-ai/claude-code-watchdog@v0.2
      with:
        anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
        test_results_path: 'test-results/**/*.xml'
    
    - name: Notify team on critical failures
      if: failure() && steps.watchdog.outputs.severity == 'critical'
      uses: 8398a7/action-slack@v3
      with:
        status: failure
        channel: '#critical-alerts'
        title: '🚨 Critical Test Failure'
        message: |
          Severity: ${{ steps.watchdog.outputs.severity }}
          Action: ${{ steps.watchdog.outputs.action_taken }}
          Issue: #${{ steps.watchdog.outputs.issue_number }}
        mention: 'channel'
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Scheduled API Monitoring
Perfect for health checks and integration tests:

```yaml
name: API Health Check

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours

jobs:
  health-check:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Run API tests
      run: |
        # Your API tests (Postman, curl, etc.)
        newman run api-tests.json --reporters json --reporter-json-export results.json
      continue-on-error: true
    
    - name: Artemis analysis
      if: failure()
      uses: cardscan-ai/claude-code-watchdog@v0.2
      with:
        anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
        test_results_path: 'results.json'  # Newman output file
        create_fixes: 'false'  # Just analysis for API tests
        severity_threshold: 'low'  # Monitor everything
```

### Full Auto-Healing
Maximum automation - Artemis tries to fix and verify:

```yaml
- name: Full auto-healing
  if: failure()
  uses: cardscan-ai/claude-code-watchdog@v0.2
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    test_results_path: 'test-results/**/*.xml'
    create_fixes: 'true'     # Try to implement fixes
    rerun_tests: 'true'      # Verify fixes work
    severity_threshold: 'low' # Handle all failures

- name: Auto-merge if fixed
  if: steps.watchdog.outputs.tests_passing == 'true'
  run: gh pr merge ${{ steps.watchdog.outputs.pr_number }} --squash
```

## Configuration

| Input | Description | Default |
|-------|-------------|---------|
| `anthropic_api_key` | Anthropic API key for Claude | Required |
| `test_results_path` | Path or glob pattern to test result files (e.g., "test-results/**/*.xml", "cypress/reports/*.json") | Required |
| `severity_threshold` | Minimum severity to process (ignore/low/medium/high/critical) | `medium` |
| `create_issues` | Create GitHub issues for failures | `true` |
| `create_fixes` | Attempt to implement fixes automatically | `true` |
| `rerun_tests` | Re-run tests to verify fixes work | `false` |
| `debug_mode` | Upload debugging artifacts and detailed logs | `false` |
| `safe_mode` | Skip potentially risky external content (GitHub issues, PRs, commit messages) | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `severity` | Failure severity (ignore/low/medium/high/critical) |
| `action_taken` | What Artemis did (issue_created/issue_updated/pr_created/etc.) |
| `issue_number` | GitHub issue number if created/updated |
| `pr_number` | PR number if fixes were created |
| `tests_passing` | true if re-run tests passed after fixes |

## Smart Notifications

Use the severity output to control notifications:

```yaml
- name: Critical failure alerts
  if: failure() && steps.watchdog.outputs.severity == 'critical'
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    channel: '#critical-alerts'
    title: '🚨 Critical Test Failure'
    message: |
      Severity: ${{ steps.watchdog.outputs.severity }}
      Action: ${{ steps.watchdog.outputs.action_taken }}
      Issue: #${{ steps.watchdog.outputs.issue_number }}
    mention: 'channel'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

- name: Auto-fix success notifications
  if: steps.watchdog.outputs.tests_passing == 'true'
  uses: 8398a7/action-slack@v3
  with:
    status: success
    title: '✅ Tests Auto-Fixed'
    message: 'Watchdog automatically resolved test failures'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Required Permissions

### For Analysis Only (create_fixes: false)
```yaml
permissions:
  contents: read
  issues: write
```

### For Auto-Fixing (create_fixes: true)
```yaml
permissions:
  contents: write      # Create branches and commits
  issues: write        # Create/update issues
  pull-requests: write # Create PRs with fixes
```

The action gracefully falls back to analysis-only mode if permissions aren't available.

## Setup Instructions

### 1. Get Your Anthropic API Key
1. Sign up at [console.anthropic.com](https://console.anthropic.com)
2. **IMPORTANT**: Set up spending limits and budget alerts for your account
3. Create an API key with appropriate usage limits
4. Add it to your repository secrets as `ANTHROPIC_API_KEY`

### 2. Add Repository Secrets
Go to your repository → Settings → Secrets and variables → Actions:
- **Name**: `ANTHROPIC_API_KEY`
- **Value**: Your Anthropic API key (starts with `sk-ant-`)

### 3. Add the Workflow Step
Add the watchdog step to your existing test workflows (see examples above).

### 4. Set Permissions
Add the required permissions to your workflow (see permissions section).

You're all set!

## How It Works

### Pre-flight Intelligence Gathering
Before calling Claude, the action automatically gathers:
- **Repository permissions** - What actions can be taken
- **Existing issues/PRs** - Avoid duplicates and update existing items
- **Workflow run history** - Calculate failure rates and patterns
- **Recent commits** - Identify potential causes
- **Test output files** - Find JUnit XML, JSON reports, logs

### Claude Analysis
Claude then:
- **Parses test outputs** intelligently across multiple formats
- **Correlates failures** with recent changes and patterns
- **Determines severity** based on failure rate and impact
- **Makes decisions** about issues, fixes, and notifications
- **Implements fixes** safely when confident
- **Verifies fixes** by re-running tests if requested

### Smart Actions
Based on the analysis:
- **Updates existing issues** instead of creating duplicates
- **Creates PRs with fixes** for automatable problems
- **Provides detailed context** for human investigation
- **Sets appropriate severity** for intelligent notifications

## Common Use Cases

### API Integration Testing
- **Scheduled health checks** every few hours
- **Contract testing** between services
- **Authentication timeout** detection and fixing
- **Network failure** vs **code bug** differentiation

### End-to-End Testing
- **Flaky selector** detection and updating
- **Timing issue** identification and retry logic
- **Environment drift** detection
- **Test data** management issues

### Unit Test Maintenance
- **Deprecated API** usage updates
- **Assertion modernization**
- **Test isolation** improvements
- **Performance regression** tracking

### CI/CD Pipeline Health
- **Build failure** pattern analysis
- **Deployment gate** reliability monitoring
- **Cross-platform** test consistency
- **Security scan** failure investigation

## Advanced Configuration

### Custom Severity Thresholds
```yaml
# Only handle serious issues
- uses: cardscan-ai/claude-code-watchdog@v0.2
  with:
    severity_threshold: 'high'  # Ignore low/medium failures
```

### Read-Only Analysis
```yaml
# Conservative approach - just create issues
- uses: cardscan-ai/claude-code-watchdog@v0.2
  with:
    create_fixes: 'false'
    rerun_tests: 'false'
```

### Full Automation
```yaml
# Maximum automation
- uses: cardscan-ai/claude-code-watchdog@v0.2
  with:
    create_fixes: 'true'
    rerun_tests: 'true'
    severity_threshold: 'low'  # Handle everything
```

## Example Issue Output

```markdown
# Watchdog [API Tests]: Authentication timeout in user service

**Workflow:** API Tests
**Run:** [#1234](https://github.com/org/repo/actions/runs/1234)
**Severity:** High
**Pattern:** Frequent (67% failure rate over last 20 runs)

## 🔍 Failure Analysis
The user authentication endpoint is consistently timing out after 5 seconds. This started happening 2 days ago after commit abc123 which updated the auth service dependencies.

## 📊 Pattern Analysis
- **Total runs analyzed:** 20
- **Failed runs:** 13
- **Failure rate:** 67%
- **Pattern:** Frequent

This represents a significant reliability issue that's blocking multiple workflows.

## 🔧 Recommendations
- [ ] Investigate auth service performance after recent dependency updates
- [ ] Consider increasing timeout from 5s to 10s as temporary fix
- [ ] Check database connection pool settings
- [ ] Review auth service logs for commit abc123 timeframe

## 📝 Context
- **Commit:** abc123456
- **Actor:** developer-name
- **Event:** schedule

---
*Auto-generated by Claude Code Watchdog*
```

## Analysis Reports and Debugging

### Automatic Reports
Every run generates a detailed analysis report uploaded as a GitHub artifact:

```
watchdog-report-{run-id}/
└── final-report.md    # Comprehensive analysis summary
```

The report includes:
- Analysis results (severity, actions taken)
- Failure patterns and context
- Issue/PR numbers created
- Historical data summary

### Debug Mode
Enable debug mode for detailed troubleshooting:

```yaml
- uses: cardscan-ai/claude-code-watchdog@v0.2
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    debug_mode: 'true'  # Upload all analysis data
```

Debug artifacts include:
```
watchdog-debug-{run-id}/
├── .watchdog/
│   ├── context-summary.json      # Run context
│   ├── failure-analysis.json     # Failure patterns  
│   ├── existing-issues.json      # Related issues
│   ├── recent-runs.json          # Workflow history
│   └── test-files.txt            # Test files found
├── test-results.json             # Your test outputs
├── junit-results.xml             # JUnit files
└── *.log                         # Test logs
```

Perfect for:
- Understanding why Claude made specific decisions
- Debugging pattern recognition
- Seeing exactly what test data was analyzed
- Troubleshooting action behavior

## Cost Estimation

> ⚠️ **IMPORTANT DISCLAIMER**: Cost estimates are approximate and may vary significantly based on your specific use case, test output size, and complexity. CardScan.ai provides NO warranty or guarantee regarding actual costs incurred. Usage costs are your responsibility.
>
> 🚨 **STRONGLY RECOMMENDED**: Set up API key spending limits and budgets you are comfortable with before using this action. Monitor your Anthropic API usage regularly.

Claude Code Watchdog uses the Anthropic API, so each run incurs a cost based on token usage.

### Typical Costs Per Run

| Configuration | Input Tokens | Output Tokens | Estimated Cost |
|---------------|--------------|---------------|----------------|
| Analysis only | ~2-3k | ~500-1k | ~$0.20-$0.40 |
| Analysis + Issue creation | ~3-4k | ~1-2k | ~$0.40-$0.60 |
| Analysis + Fixes + PR | ~4-6k | ~2-4k | ~$0.60-$1.20 |
| Complex fixes + Re-run | ~6-8k | ~3-5k | ~$1.00-$1.80 |

### Cost Factors

**Input tokens** (what Claude reads):
- Context data (runs, commits, issues): ~1-2k tokens
- Test output files: ~1-3k tokens (varies by test size)
- Configuration and prompts: ~500 tokens

**Output tokens** (what Claude generates):
- Analysis and recommendations: ~500-1k tokens
- Issue/PR descriptions: ~500-1k tokens  
- Code fixes: ~500-2k tokens (varies by complexity)
- Multiple fix attempts: Can increase cost

### Cost Optimization Tips

1. **Start conservative**: Use `create_fixes: false` initially
2. **Limit scope**: Use `severity_threshold` to avoid low-priority runs
3. **Monitor usage**: Check cost estimates in analysis reports and your Anthropic dashboard
4. **Schedule wisely**: Monthly demos instead of daily
5. **Debug selectively**: Only enable `debug_mode` when needed
6. **Set spending limits**: Configure budget alerts in your Anthropic account
7. **Test cautiously**: Start with non-critical workflows to understand actual costs

### Monthly Budget Examples

> ⚠️ **These are rough estimates only - your actual costs may be significantly higher or lower**

- **Light usage** (5 failures/month, analysis only): ~$2-3/month
- **Regular usage** (15 failures/month, fixes enabled): ~$8-12/month  
- **Heavy usage** (30 failures/month, full automation): ~$20-30/month

**IMPORTANT**: These estimates assume typical test output sizes. Large test suites, verbose logs, or complex codebases can significantly increase token usage and costs.

The action shows actual costs (when available) in console output and detailed breakdowns in analysis reports. **Always monitor your Anthropic API usage dashboard for real spending.**

## Troubleshooting

### Common Issues

**❌ "GitHub CLI not authenticated"**
- Ensure your workflow has a valid `GITHUB_TOKEN`
- Default `GITHUB_TOKEN` is automatically available in most cases

**❌ "Anthropic API key required"**
- Add your API key to repository secrets as `ANTHROPIC_API_KEY`
- Verify the secret name matches exactly

**❌ "No push permissions - cannot create PRs"**
- Add `contents: write` and `pull-requests: write` to your workflow permissions
- Or set `create_fixes: false` for analysis-only mode

**❌ "No test output files found"**
- Ensure your tests output JUnit XML, JSON reports, or log files
- Check that test files match the patterns: `*test*.xml`, `*test*.json`, etc.

### Getting Help

1. **Check the workflow logs** - Artemis provides detailed output about what it's doing
2. **Review permissions** - Many issues are permission-related
3. **Validate test outputs** - Ensure your tests create parseable output files
4. **Start simple** - Begin with `create_fixes: false` and add features gradually
5. **Use debug mode** - Enable `debug_mode: true` to see exactly what data Claude analyzed

## Contributing

We love contributions! Here's how to help:

### Reporting Bugs
- Use the issue template
- Include workflow logs
- Describe expected vs actual behavior

### Feature Requests
- Describe your use case
- Explain how it would help your team
- Consider if it fits Artemis's core mission

### Code Contributions
- Fork the repository
- Create a feature branch
- Add tests for new functionality
- Ensure all tests pass
- Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## About CardScan.ai

This project is maintained by [CardScan.ai](https://cardscan.ai), makers of AI-powered insurance card scanning and eligibility verification tools.

We built this tool because we run scheduled API tests, WebSocket monitoring, and cross-platform SDK validation that can fail for various reasons. We got tired of waking up to notification storms about flaky tests while real issues got buried in the noise.

Claude Code Watchdog helps us focus on what matters: real bugs and breaking changes, not environment hiccups and timing issues.

## Authorship & Development Costs

This entire project was developed using Claude Code, demonstrating the power of AI-assisted software development. **No human coding work was required** for the construction of this project.

**Development Statistics:**
```
> /cost
  ⎿  Total cost:            $21.27
     Total duration (API):  1h 38m 6.7s
     Total duration (wall): 8h 52m 56.3s
     Total code changes:    2064 lines added, 696 lines removed
     Token usage by model:
         claude-3-5-haiku:  650.1k input, 20.0k output, 0 cache read, 0 cache write
            claude-sonnet:  1.4k input, 127.6k output, 35.0m cache read, 2.2m cache write
```

This represents a complete GitHub Action with:
- Complex GitHub Actions workflow orchestration
- Node.js scripts for data processing and validation
- Intelligent duplicate detection and search algorithms
- Cost monitoring and reporting systems
- Comprehensive documentation and examples
- Full error handling and fallback mechanisms

All accomplished through natural language conversations with Claude Code at a cost of $21.27.