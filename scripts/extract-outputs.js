#!/usr/bin/env node

/**
 * Extract outputs from Claude analysis result
 * Robust Node.js replacement for extract-outputs.sh
 */

const fs = require('fs');
const path = require('path');

console.log('🔧 Extracting outputs from Claude analysis...');
console.log('🔍 Debug info:', process.env.DEBUG_ALL_OUTPUTS || 'No debug info');

let outputs = {
  severity: '',
  action_taken: '',
  issue_number: '',
  pr_number: '',
  tests_passing: ''
};

// Check if Claude created the result file
const resultFile = '.watchdog/analysis-result.json';
if (fs.existsSync(resultFile)) {
  console.log('📄 Found analysis result file');
  
  try {
    const content = fs.readFileSync(resultFile, 'utf8');
    const result = JSON.parse(content);
    
    // Extract exact values from Claude
    outputs.severity = result.severity || '';
    outputs.action_taken = result.action_taken || '';
    outputs.issue_number = result.issue_number && result.issue_number !== 'null' ? String(result.issue_number) : '';
    outputs.pr_number = result.pr_number && result.pr_number !== 'null' ? String(result.pr_number) : '';
    outputs.tests_passing = result.tests_passing && result.tests_passing !== 'null' ? result.tests_passing : '';
    
    console.log('✅ Successfully parsed analysis results');
  } catch (error) {
    console.warn('⚠️ Error parsing analysis result file:', error.message);
  }
} else {
  console.log('⚠️ No analysis result file found');
}

// Try to extract cost data from Claude execution file
let costData = {
  input_tokens: '',
  output_tokens: '', 
  total_cost: '',
  turns_used: ''
};

const claudeExecutionFile = process.env.CLAUDE_EXECUTION_FILE;
console.log(`🔍 Claude execution file path: ${claudeExecutionFile || 'NOT SET'}`);

if (claudeExecutionFile) {
  console.log(`📁 File exists: ${fs.existsSync(claudeExecutionFile)}`);
  if (fs.existsSync(claudeExecutionFile)) {
    console.log(`📊 File size: ${fs.statSync(claudeExecutionFile).size} bytes`);
  }
}

if (claudeExecutionFile && fs.existsSync(claudeExecutionFile)) {
  try {
    console.log('📊 Reading cost data from Claude execution file...');
    const executionContent = fs.readFileSync(claudeExecutionFile, 'utf8');
    const executionData = JSON.parse(executionContent);
    
    // Debug logging
    console.log('🔍 Debug - Execution data structure:');
    console.log(`   - type: ${executionData.type}`);
    console.log(`   - subtype: ${executionData.subtype}`);
    console.log(`   - total_cost_usd: ${executionData.total_cost_usd}`);
    console.log(`   - num_turns: ${executionData.num_turns}`);
    console.log(`   - usage keys: ${executionData.usage ? Object.keys(executionData.usage).join(', ') : 'none'}`);
    
    // Extract cost data with better handling
    if (executionData.total_cost_usd !== undefined && executionData.total_cost_usd !== null) {
      costData.total_cost = `$${executionData.total_cost_usd.toFixed(4)}`;
      console.log(`💰 Cost extracted: ${costData.total_cost}`);
    } else {
      console.log('⚠️ No total_cost_usd found in execution data');
    }
    
    if (executionData.usage) {
      const usage = executionData.usage;
      costData.input_tokens = String(usage.input_tokens || '');
      costData.output_tokens = String(usage.output_tokens || '');
      console.log(`📊 Token usage: ${costData.input_tokens} input, ${costData.output_tokens} output`);
    }
    
    if (executionData.num_turns !== undefined) {
      costData.turns_used = String(executionData.num_turns);
      console.log(`🔄 Turns used: ${costData.turns_used}`);
    }
    
    console.log('✅ Successfully extracted cost data');
  } catch (error) {
    console.warn('⚠️ Could not extract cost data:', error.message);
    console.warn('📄 File content preview:', executionContent ? executionContent.substring(0, 200) + '...' : 'empty');
  }
}

// Write GitHub Action outputs
const githubOutput = process.env.GITHUB_OUTPUT;
if (githubOutput) {
  const outputLines = [
    `severity=${outputs.severity}`,
    `action_taken=${outputs.action_taken}`,
    `issue_number=${outputs.issue_number}`,
    `pr_number=${outputs.pr_number}`,
    `tests_passing=${outputs.tests_passing}`,
    `input_tokens=${costData.input_tokens}`,
    `output_tokens=${costData.output_tokens}`,
    `total_cost=${costData.total_cost}`,
    `turns_used=${costData.turns_used}`
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