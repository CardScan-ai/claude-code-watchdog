#!/usr/bin/env node

/**
 * Calculate dynamic max_turns based on enabled features
 */

console.log('🔧 Calculating dynamic max_turns based on features...');

// Base turns for analysis only
let maxTurns = 12;

// Feature-based turn allocation
const createIssues = process.env.CREATE_ISSUES === 'true';
const createFixes = process.env.CREATE_FIXES === 'true';
const rerunTests = process.env.RERUN_TESTS === 'true';

if (createIssues) {
  maxTurns += 10; // Issue creation/update operations
}

if (createFixes) {
  maxTurns += 18; // Fix implementation and PR creation
}

if (rerunTests) {
  maxTurns += 8;  // Test verification
}

// Set environment variable for GitHub Actions
const fs = require('fs');
const githubEnv = process.env.GITHUB_ENV;

if (githubEnv) {
  fs.appendFileSync(githubEnv, `DYNAMIC_MAX_TURNS=${maxTurns}\n`);
}

console.log(`✅ Dynamic max_turns: ${maxTurns}`);
console.log(`   - Base analysis: 12`);
console.log(`   - Issues: ${createIssues ? '+10' : '+0'}`);
console.log(`   - Fixes: ${createFixes ? '+18' : '+0'}`);
console.log(`   - Rerun tests: ${rerunTests ? '+8' : '+0'}`);