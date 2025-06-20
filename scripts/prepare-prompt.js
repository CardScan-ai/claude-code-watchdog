#!/usr/bin/env node

/**
 * Prepare context data for Claude analysis
 * This script creates a markdown file with all the context data Claude needs
 */

const fs = require('fs');
const path = require('path');

console.log('📝 Preparing context data for Claude analysis...');

// Ensure .watchdog directory exists
const watchdogDir = '.watchdog';
if (!fs.existsSync(watchdogDir)) {
  fs.mkdirSync(watchdogDir, { recursive: true });
}

// Helper function to safely read JSON file
function readJsonFile(filePath) {
  try {
    if (fs.existsSync(filePath) && fs.statSync(filePath).size > 0) {
      const content = fs.readFileSync(filePath, 'utf8');
      return JSON.parse(content);
    }
  } catch (error) {
    console.warn(`Warning: Could not read ${filePath}:`, error.message);
  }
  return null;
}

// Helper function to safely read text file
function readTextFile(filePath) {
  try {
    if (fs.existsSync(filePath) && fs.statSync(filePath).size > 0) {
      return fs.readFileSync(filePath, 'utf8');
    }
  } catch (error) {
    console.warn(`Warning: Could not read ${filePath}:`, error.message);
  }
  return null;
}

// Helper function to add JSON section to markdown
function addJsonSection(content, title, data) {
  content.push(`### ${title}`);
  if (data && (Array.isArray(data) ? data.length > 0 : Object.keys(data).length > 0)) {
    content.push('```json');
    content.push(JSON.stringify(data, null, 2));
    content.push('```');
  } else {
    content.push(`No ${title.toLowerCase()} available`);
  }
  content.push('');
}

// Helper function to add text section to markdown
function addTextSection(content, title, text) {
  content.push(`### ${title}`);
  if (text) {
    content.push('```');
    content.push(text);
    content.push('```');
  } else {
    content.push(`No ${title.toLowerCase()} available`);
  }
  content.push('');
}

// Start building the markdown content
const content = [];

// Header and configuration
content.push('# Test Failure Analysis Context');
content.push('');
content.push('## Configuration');
content.push(`- Create issues: ${process.env.CREATE_ISSUES || 'unknown'}`);
content.push(`- Create fixes: ${process.env.CREATE_FIXES || 'unknown'}`);
content.push(`- Rerun tests: ${process.env.RERUN_TESTS || 'unknown'}`);
content.push(`- Severity threshold: ${process.env.SEVERITY_THRESHOLD || 'unknown'}`);
content.push(`- Safe mode: ${process.env.SAFE_MODE || 'false'}`);
content.push('');
content.push('## Context Data');
content.push('');

// Add workflow information
const contextSummary = readJsonFile(path.join(watchdogDir, 'context-summary.json'));
addJsonSection(content, 'Workflow Information', contextSummary);

// Add failure analysis
const failureAnalysis = readJsonFile(path.join(watchdogDir, 'failure-analysis.json'));
addJsonSection(content, 'Failure Pattern Analysis', failureAnalysis);

// Add existing issues (if not in safe mode)
const safeMode = process.env.SAFE_MODE === 'true';
if (safeMode) {
  content.push('### Existing Related Issues');
  content.push('Skipped in safe mode (security precaution)');
  content.push('');
} else {
  const existingIssues = readJsonFile(path.join(watchdogDir, 'existing-issues.json'));
  addJsonSection(content, 'Existing Related Issues', existingIssues);
}

// Add existing PRs (if not in safe mode)
if (safeMode) {
  content.push('### Existing Related PRs');
  content.push('Skipped in safe mode (security precaution)');
  content.push('');
} else {
  const existingPRs = readJsonFile(path.join(watchdogDir, 'existing-prs.json'));
  addJsonSection(content, 'Existing Related PRs', existingPRs);
}

// Add recent commits (if not in safe mode)
if (safeMode) {
  content.push('### Recent Commits (Potential Causes)');
  content.push('Skipped in safe mode (security precaution)');
  content.push('');
} else {
  const recentCommits = readJsonFile(path.join(watchdogDir, 'recent-commits.json'));
  // Limit to first 10 commits if it's an array
  const limitedCommits = Array.isArray(recentCommits) ? recentCommits.slice(0, 10) : recentCommits;
  addJsonSection(content, 'Recent Commits (Potential Causes)', limitedCommits);
}

// Add test output content
content.push('### Test Output Content');
const testOutputsDir = path.join(watchdogDir, 'test-outputs');
try {
  if (fs.existsSync(testOutputsDir) && fs.statSync(testOutputsDir).isDirectory()) {
    const outputFiles = fs.readdirSync(testOutputsDir);
    console.log(`📁 Found ${outputFiles.length} files in test-outputs: ${outputFiles.join(', ')}`);
    
    if (outputFiles.length > 0) {
      for (const fileName of outputFiles) {
        const filePath = path.join(testOutputsDir, fileName);
        console.log(`📄 Reading test output content: ${filePath}`);
        
        if (fs.statSync(filePath).isFile()) {
          const fileContent = readTextFile(filePath);
          if (fileContent) {
            content.push('');
            content.push(`#### ${fileName}`);
            content.push('```');
            content.push(fileContent);
            content.push('```');
          }
        }
      }
    } else {
      content.push('No test output content available');
    }
  } else {
    content.push('No test output content available');
  }
} catch (error) {
  console.warn('Warning: Could not read test outputs directory:', error.message);
  content.push('No test output content available');
}
content.push('');

// Add available test files for reference
const testFiles = readTextFile(path.join(watchdogDir, 'test-files.txt'));
addTextSection(content, 'Available Test Files (for reference)', testFiles);

// Write the final markdown file
const outputFile = path.join(watchdogDir, 'context-data.md');
try {
  fs.writeFileSync(outputFile, content.join('\n'), 'utf8');
  console.log('✅ Context data prepared for Claude analysis');
  console.log(`📄 Context file: ${outputFile} (${content.length} lines)`);
} catch (error) {
  console.error('❌ Failed to write context data file:', error.message);
  process.exit(1);
}