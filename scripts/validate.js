#!/usr/bin/env node

/**
 * Validation checks for Claude Code Watchdog
 * Node.js replacement for validate.sh
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🔍 Running validation checks...');

// Helper function to execute commands safely
function execCommand(command, silent = true) {
  try {
    const result = execSync(command, { 
      encoding: 'utf8',
      stdio: silent ? 'pipe' : 'inherit'
    });
    return { success: true, output: result.trim() };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Helper function to set GitHub environment variable
function setGitHubEnv(key, value) {
  const githubEnv = process.env.GITHUB_ENV;
  if (githubEnv) {
    fs.appendFileSync(githubEnv, `${key}=${value}\n`);
  }
}

let validationWarnings = '';

// Check GitHub CLI
console.log('🔧 Checking GitHub CLI...');
const ghCheck = execCommand('which gh');
if (!ghCheck.success) {
  console.log('⚠️ GitHub CLI not found - some features may be limited');
  validationWarnings = 'gh_cli_missing';
} else {
  const authCheck = execCommand('gh auth status');
  if (!authCheck.success) {
    console.log('⚠️ GitHub CLI not authenticated - will use limited permissions');
    validationWarnings = 'gh_auth_missing';
  }
}

if (validationWarnings) {
  setGitHubEnv('VALIDATION_WARNINGS', validationWarnings);
}

// Check Anthropic API key
console.log('🔑 Checking API key...');
const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
if (!anthropicApiKey || anthropicApiKey.trim() === '') {
  console.error('❌ Anthropic API key required - cannot proceed with analysis');
  console.error('Please add ANTHROPIC_API_KEY to your repository secrets');
  setGitHubEnv('VALIDATION_FAILED', 'api_key_missing');
  process.exit(1);
}

// Permission checks
console.log('🔐 Checking permissions...');
let pushPermission = false;
let issuesPermission = false;

if (!validationWarnings) {
  try {
    const repoInfo = execCommand(`gh api repos/${process.env.GITHUB_REPOSITORY} --jq '{push: .permissions.push, admin: .permissions.admin}'`);
    if (repoInfo.success) {
      const permissions = JSON.parse(repoInfo.output);
      pushPermission = permissions.push === true;
      issuesPermission = permissions.admin === true || permissions.push === true;
    }
  } catch (error) {
    console.warn('⚠️ Could not check repository permissions:', error.message);
  }
} else {
  console.log('⚠️ Skipping permission checks due to GitHub CLI issues');
}

console.log('✅ Validation complete:');
console.log(`   - GitHub CLI: ${validationWarnings ? 'warning' : 'authenticated'}`);
console.log('   - API key: provided');
console.log(`   - Push permission: ${pushPermission}`);
console.log(`   - Issues permission: ${issuesPermission}`);

// Create working directory
const watchdogDir = '.watchdog';
try {
  if (!fs.existsSync(watchdogDir)) {
    fs.mkdirSync(watchdogDir, { recursive: true });
  }
} catch (error) {
  console.warn('⚠️ Could not create .watchdog directory - using /tmp');
  try {
    const tmpDir = '/tmp/watchdog';
    fs.mkdirSync(tmpDir, { recursive: true });
    fs.symlinkSync(tmpDir, watchdogDir);
  } catch (linkError) {
    console.error('❌ Could not create working directory:', linkError.message);
    process.exit(1);
  }
}

// Store permissions for later use
const createFixesEnabled = process.env.CREATE_FIXES === 'true' && pushPermission;
const permissions = {
  can_create_branches: pushPermission,
  can_create_issues: issuesPermission,
  can_create_prs: pushPermission,
  create_fixes_enabled: createFixesEnabled,
  validation_warnings: validationWarnings || 'none'
};

try {
  fs.writeFileSync(
    path.join(watchdogDir, 'permissions.json'),
    JSON.stringify(permissions, null, 2)
  );
} catch (error) {
  console.error('❌ Could not write permissions file:', error.message);
  process.exit(1);
}