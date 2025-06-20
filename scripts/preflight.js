#!/usr/bin/env node

/**
 * Gather context data for Claude analysis
 * Robust Node.js replacement for preflight.sh
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('📊 Gathering context data...');

// Ensure .watchdog directory exists
const watchdogDir = '.watchdog';
if (!fs.existsSync(watchdogDir)) {
  fs.mkdirSync(watchdogDir, { recursive: true });
}

// Helper function to execute shell commands safely
function execCommand(command, silent = false) {
  try {
    const result = execSync(command, { 
      encoding: 'utf8',
      stdio: silent ? 'pipe' : ['pipe', 'pipe', 'pipe']
    });
    return result.trim();
  } catch (error) {
    if (!silent) {
      console.warn(`⚠️ Command failed: ${command}`);
      console.warn(`Error: ${error.message}`);
    }
    return null;
  }
}

// Helper function to safely call GitHub API
function callGitHubAPI(endpoint, jqFilter = '.') {
  try {
    const command = `gh api ${endpoint} --jq '${jqFilter}'`;
    const result = execCommand(command, true);
    if (result) {
      return JSON.parse(result);
    }
  } catch (error) {
    console.warn(`⚠️ GitHub API call failed for ${endpoint}:`, error.message);
  }
  return null;
}

// Helper function to write JSON file safely
function writeJsonFile(fileName, data) {
  const filePath = path.join(watchdogDir, fileName);
  try {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
    return true;
  } catch (error) {
    console.warn(`⚠️ Failed to write ${fileName}:`, error.message);
    return false;
  }
}

// Get environment variables
const env = {
  safeMode: process.env.SAFE_MODE === 'true',
  testResultsPath: process.env.TEST_RESULTS_PATH,
  githubWorkflow: process.env.GITHUB_WORKFLOW || 'unknown',
  githubRepository: process.env.GITHUB_REPOSITORY || 'unknown',
  githubRunId: process.env.GITHUB_RUN_ID || 'unknown',
  githubRunAttempt: process.env.GITHUB_RUN_ATTEMPT || 'unknown',
  githubRef: process.env.GITHUB_REF || 'unknown',
  githubSha: process.env.GITHUB_SHA || 'unknown',
  githubActor: process.env.GITHUB_ACTOR || 'unknown',
  githubEventName: process.env.GITHUB_EVENT_NAME || 'unknown'
};

// Check permissions first
console.log('🔍 Checking permissions...');
const permissions = {
  can_create_branches: false,
  can_create_issues: false,
  can_create_prs: false,
  create_fixes_enabled: false,
  validation_warnings: 'none'
};

// Try to check repository permissions
const repoInfo = callGitHubAPI(`repos/${env.githubRepository}`);
if (repoInfo && repoInfo.permissions) {
  permissions.can_create_branches = repoInfo.permissions.push === true;
  permissions.can_create_issues = repoInfo.permissions.push === true;
  permissions.can_create_prs = repoInfo.permissions.push === true;
  permissions.create_fixes_enabled = permissions.can_create_branches && permissions.can_create_issues;
}

writeJsonFile('permissions.json', permissions);

// Check if we have limited access
const hasLimitedAccess = !execCommand('gh auth status', true);
if (hasLimitedAccess) {
  console.log('⚠️ Limited GitHub access - creating minimal context');
  writeJsonFile('existing-issues.json', []);
  writeJsonFile('existing-prs.json', []);
  writeJsonFile('recent-runs.json', []);
  writeJsonFile('recent-commits.json', []);
  fs.writeFileSync(path.join(watchdogDir, 'test-files.txt'), '');
  
  const contextSummary = {
    workflow: env.githubWorkflow,
    run_id: env.githubRunId,
    repository: env.githubRepository,
    existing_issues_count: 0,
    existing_prs_count: 0,
    recent_failures: 0,
    test_files_found: 0,
    timestamp: new Date().toISOString(),
    status: 'limited_context'
  };
  
  writeJsonFile('context-summary.json', contextSummary);
  writeJsonFile('failure-analysis.json', {
    total_runs: 0,
    failed_runs: 0,
    failure_rate_percent: 0,
    pattern: 'unknown'
  });
  
  console.log('⚠️ Context gathering completed with limited data');
  process.exit(0);
}

// Build workflow pattern for search
const workflowPattern = `Watchdog \\\\[${env.githubWorkflow}\\\\]`;

// Gather existing issues and PRs (unless in safe mode)
if (env.safeMode) {
  console.log('🔒 Safe mode enabled - skipping external content');
  writeJsonFile('existing-issues.json', []);
  writeJsonFile('existing-prs.json', []);
  writeJsonFile('recent-commits.json', []);
} else {
  console.log('📋 Gathering existing issues and PRs...');
  
  // Get existing issues
  const existingIssues = callGitHubAPI(
    `repos/${env.githubRepository}/issues`,
    `[.[] | select(.title | test("${workflowPattern}")) | select(.state == "open") | {number, title, created_at, updated_at, labels: [.labels[].name], body}]`
  );
  writeJsonFile('existing-issues.json', existingIssues || []);
  
  // Get existing PRs
  const existingPRs = callGitHubAPI(
    `repos/${env.githubRepository}/pulls`,
    `[.[] | select(.title | test("${workflowPattern}")) | select(.state == "open") | {number, title, created_at, updated_at, head: .head.ref, body}]`
  );
  writeJsonFile('existing-prs.json', existingPRs || []);
  
  // Get recent commits
  const recentCommits = callGitHubAPI(
    `repos/${env.githubRepository}/commits`,
    `[.[] | {sha: .sha[0:8], message: .commit.message, author: .commit.author.name, date: .commit.author.date}]`
  );
  writeJsonFile('recent-commits.json', recentCommits || []);
}

// Gather workflow run history
console.log('📊 Gathering workflow run history...');
const workflowId = callGitHubAPI(
  `repos/${env.githubRepository}/actions/workflows`,
  `[.workflows[] | select(.name == "${env.githubWorkflow}") | .id][0]`
);

if (workflowId) {
  fs.writeFileSync(path.join(watchdogDir, 'workflow-id.txt'), String(workflowId));
  
  const recentRuns = callGitHubAPI(
    `repos/${env.githubRepository}/actions/workflows/${workflowId}/runs`,
    `.workflow_runs[0:20] | map({id, run_number, status, conclusion, created_at, head_sha, head_commit: {message: .head_commit.message, author: .head_commit.author.name}})`
  );
  
  if (recentRuns && Array.isArray(recentRuns)) {
    writeJsonFile('recent-runs.json', recentRuns);
    
    // Calculate failure statistics
    const totalRuns = recentRuns.length;
    const failedRuns = recentRuns.filter(run => run.conclusion === 'failure').length;
    const successRuns = recentRuns.filter(run => run.conclusion === 'success').length;
    const failureRate = totalRuns > 0 ? Math.round((failedRuns * 100) / totalRuns) : 0;
    
    let pattern = 'unknown';
    if (failureRate > 80) pattern = 'chronic';
    else if (failureRate > 50) pattern = 'frequent';
    else if (failureRate > 20) pattern = 'intermittent';
    else pattern = 'isolated';
    
    const failureAnalysis = {
      total_runs: totalRuns,
      failed_runs: failedRuns,
      success_runs: successRuns,
      failure_rate_percent: failureRate,
      pattern: pattern
    };
    
    writeJsonFile('failure-analysis.json', failureAnalysis);
    console.log(`DEBUG: Analysis - Total: ${totalRuns}, Failed: ${failedRuns}, Rate: ${failureRate}%, Pattern: ${pattern}`);
  } else {
    writeJsonFile('recent-runs.json', []);
    writeJsonFile('failure-analysis.json', {
      total_runs: 0,
      failed_runs: 0,
      failure_rate_percent: 0,
      pattern: 'unknown'
    });
  }
} else {
  fs.writeFileSync(path.join(watchdogDir, 'workflow-id.txt'), '');
  writeJsonFile('recent-runs.json', []);
  writeJsonFile('failure-analysis.json', {
    total_runs: 0,
    failed_runs: 0,
    failure_rate_percent: 0,
    pattern: 'unknown'
  });
}

// Find test files (excluding node_modules and .git)
console.log('🔍 Finding test output files...');
const findCommand = `find . -type f \\( -name "*.xml" -o -name "*.json" -o -name "*.log" -o -name "*.tap" -o -name "*.trx" \\) -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.watchdog/*" | grep -E "(test|spec|junit|report|result)" | head -10`;
const testFiles = execCommand(findCommand) || '';
fs.writeFileSync(path.join(watchdogDir, 'test-files.txt'), testFiles);

// Collect test result files
console.log('📊 Gathering test results...');
const testOutputsDir = path.join(watchdogDir, 'test-outputs');
if (!fs.existsSync(testOutputsDir)) {
  fs.mkdirSync(testOutputsDir, { recursive: true });
}

// Clear existing files
const existingFiles = fs.readdirSync(testOutputsDir);
existingFiles.forEach(file => {
  fs.unlinkSync(path.join(testOutputsDir, file));
});

let foundFiles = 0;
if (env.testResultsPath) {
  console.log(`🔍 Looking for test results at: ${env.testResultsPath}`);
  
  // Use shell globbing to expand patterns
  try {
    const expandedFiles = execCommand(`ls ${env.testResultsPath} 2>/dev/null`);
    if (expandedFiles) {
      const files = expandedFiles.split('\n').filter(f => f.trim());
      
      for (const file of files) {
        if (fs.existsSync(file) && fs.statSync(file).isFile()) {
          // Skip node_modules files
          if (file.includes('node_modules')) {
            console.log(`⚠️ Skipping node_modules file: ${file}`);
            continue;
          }
          
          console.log(`📄 Found test result file: ${file}`);
          const safeName = file.replace(/\//g, '_').replace(/^_/, '');
          try {
            fs.copyFileSync(file, path.join(testOutputsDir, safeName));
            foundFiles++;
          } catch (error) {
            console.warn(`⚠️ Could not copy ${file}:`, error.message);
          }
        }
      }
    }
  } catch (error) {
    console.warn('⚠️ Error expanding test results path:', error.message);
  }
  
  if (foundFiles === 0) {
    console.log(`⚠️ No test result files found at pattern: ${env.testResultsPath}`);
    console.log('📁 Available files in current directory:');
    const availableFiles = execCommand('find . -name "*.xml" -o -name "*.json" -o -name "*.log" -o -name "*test*" -o -name "*result*" | head -10');
    if (availableFiles) {
      console.log(availableFiles);
    } else {
      console.log('   No common test files found');
    }
  } else {
    console.log(`✅ Found ${foundFiles} test result files`);
    console.log('📁 Files copied to .watchdog/test-outputs/:');
    try {
      const copiedFiles = fs.readdirSync(testOutputsDir);
      copiedFiles.forEach(file => {
        const stats = fs.statSync(path.join(testOutputsDir, file));
        console.log(`   ${file} (${stats.size} bytes)`);
      });
    } catch (error) {
      console.log('   Directory not accessible');
    }
  }
} else {
  console.log('⚠️ No test results path specified');
}

// Create context summary
console.log('📄 Creating context summary...');
const existingIssues = JSON.parse(fs.readFileSync(path.join(watchdogDir, 'existing-issues.json'), 'utf8') || '[]');
const existingPRs = JSON.parse(fs.readFileSync(path.join(watchdogDir, 'existing-prs.json'), 'utf8') || '[]');
const recentRuns = JSON.parse(fs.readFileSync(path.join(watchdogDir, 'recent-runs.json'), 'utf8') || '[]');
const testFilesList = fs.readFileSync(path.join(watchdogDir, 'test-files.txt'), 'utf8');
const testFileCount = testFilesList.split('\n').filter(line => line.trim()).length;

const contextSummary = {
  workflow: env.githubWorkflow,
  run_id: env.githubRunId,
  run_attempt: env.githubRunAttempt,
  repository: env.githubRepository,
  ref: env.githubRef,
  sha: env.githubSha,
  actor: env.githubActor,
  event_name: env.githubEventName,
  existing_issues_count: existingIssues.length,
  existing_prs_count: existingPRs.length,
  recent_failures: recentRuns.filter(run => run.conclusion === 'failure').length,
  test_files_found: testFileCount,
  test_results_files: foundFiles,
  timestamp: new Date().toISOString()
};

writeJsonFile('context-summary.json', contextSummary);

console.log('✅ Context gathering complete:');
console.log(`   - ${contextSummary.existing_issues_count} existing issues found`);
console.log(`   - ${contextSummary.existing_prs_count} existing PRs found`);
console.log(`   - ${contextSummary.recent_failures} recent failures in last 20 runs`);
console.log(`   - ${contextSummary.test_files_found} test files found`);
console.log(`   - ${contextSummary.test_results_files} test result files collected`);

const failureAnalysis = JSON.parse(fs.readFileSync(path.join(watchdogDir, 'failure-analysis.json'), 'utf8'));
console.log(`   - Failure rate: ${failureAnalysis.failure_rate_percent}% (${failureAnalysis.pattern} pattern)`);