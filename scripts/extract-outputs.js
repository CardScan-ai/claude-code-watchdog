#!/usr/bin/env node

/**
 * Extract outputs from Claude analysis result
 * Robust Node.js replacement for extract-outputs.sh
 */

const fs = require('fs');
const path = require('path');

console.log('🔧 Extracting outputs from Claude analysis...');

// Default values
const defaults = {
  severity: 'unknown',
  action_taken: 'analysis_failed', 
  issue_number: '',
  pr_number: '',
  tests_passing: 'unknown'
};

let outputs = { ...defaults };

// Check if Claude created the result file
const resultFile = '.watchdog/analysis-result.json';
if (fs.existsSync(resultFile)) {
  console.log('📄 Found analysis result file');
  
  try {
    const content = fs.readFileSync(resultFile, 'utf8');
    const result = JSON.parse(content);
    
    // Extract values with fallbacks
    outputs.severity = result.severity || defaults.severity;
    outputs.action_taken = result.action_taken || 'none';
    outputs.issue_number = result.issue_number && result.issue_number !== 'null' ? String(result.issue_number) : '';
    outputs.pr_number = result.pr_number && result.pr_number !== 'null' ? String(result.pr_number) : '';
    outputs.tests_passing = result.tests_passing && result.tests_passing !== 'null' ? result.tests_passing : defaults.tests_passing;
    
    console.log('✅ Successfully parsed analysis results');
  } catch (error) {
    console.warn('⚠️ Error parsing analysis result file:', error.message);
    console.log('Using fallback values');
  }
} else {
  console.log('⚠️ No analysis result file found - Claude may have failed');
}

// Write GitHub Action outputs
const githubOutput = process.env.GITHUB_OUTPUT;
if (githubOutput) {
  const outputLines = [
    `severity=${outputs.severity}`,
    `action_taken=${outputs.action_taken}`,
    `issue_number=${outputs.issue_number}`,
    `pr_number=${outputs.pr_number}`,
    `tests_passing=${outputs.tests_passing}`
  ];
  
  try {
    fs.appendFileSync(githubOutput, outputLines.join('\n') + '\n');
    console.log(`✅ Outputs set: severity=${outputs.severity}, action_taken=${outputs.action_taken}`);
  } catch (error) {
    console.error('❌ Failed to write GitHub outputs:', error.message);
    process.exit(1);
  }
} else {
  console.error('❌ GITHUB_OUTPUT environment variable not set');
  process.exit(1);
}