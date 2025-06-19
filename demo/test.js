/**
 * Flaky Tests - Designed to fail intermittently for Watchdog analysis
 */

const FlakyApp = require('./app');
const app = new FlakyApp();

// Simple test runner
class TestRunner {
  constructor() {
    this.passed = 0;
    this.failed = 0;
    this.tests = [];
  }

  async test(name, testFn) {
    try {
      console.log(`⏳ Running: ${name}`);
      await testFn();
      console.log(`✅ PASSED: ${name}`);
      this.passed++;
    } catch (error) {
      console.log(`❌ FAILED: ${name}`);
      console.log(`   Error: ${error.message}`);
      this.failed++;
    }
  }

  summary() {
    const total = this.passed + this.failed;
    console.log(`\n📊 Test Results: ${this.passed}/${total} passed`);
    
    if (this.failed > 0) {
      console.log(`❌ ${this.failed} tests failed`);
      process.exit(1);
    } else {
      console.log(`✅ All tests passed!`);
      process.exit(0);
    }
  }
}

const runner = new TestRunner();

// Test Suite
async function runTests() {
  console.log('🐕 Running Flaky Demo Tests...\n');

  // Test 1: User data fetching (flaky due to timeouts)
  await runner.test('User data fetching', async () => {
    const userData = await app.fetchUserData(123);
    if (!userData.id || userData.id !== 123) {
      throw new Error('Invalid user data returned');
    }
  });

  // Test 2: Database connection (race condition)
  await runner.test('Database connection', async () => {
    const connected = await app.connectDatabase();
    if (!connected) {
      throw new Error('Database connection failed');
    }
  });

  // Test 3: Email validation (inconsistent behavior)
  await runner.test('Email validation - lowercase', async () => {
    app.validateEmail('test@example.com');
  });

  await runner.test('Email validation - mixed case', async () => {
    app.validateEmail('Test@Example.COM');
  });

  // Test 4: API calls (network failures)
  await runner.test('API endpoint call', async () => {
    const response = await app.makeApiCall('/api/users');
    if (!response.data) {
      throw new Error('No data received from API');
    }
  });

  // Test 5: Multiple API calls (increases failure probability)
  await runner.test('Multiple API calls', async () => {
    const promises = [
      app.makeApiCall('/api/users'),
      app.makeApiCall('/api/products'),
      app.makeApiCall('/api/orders')
    ];
    
    const results = await Promise.all(promises);
    if (results.length !== 3) {
      throw new Error('Not all API calls completed');
    }
  });

  // Test 6: Memory usage (demonstration of resource issues)
  await runner.test('Memory usage check', async () => {
    const beforeMemory = process.memoryUsage().heapUsed;
    const leakSize = app.createMemoryLeak();
    const afterMemory = process.memoryUsage().heapUsed;
    
    const memoryIncrease = afterMemory - beforeMemory;
    if (memoryIncrease > 50 * 1024 * 1024) { // 50MB threshold
      throw new Error(`Memory usage increased by ${Math.round(memoryIncrease / 1024 / 1024)}MB`);
    }
  });

  // Test 7: Timing-sensitive test (fails on slow systems)
  await runner.test('Performance timing', async () => {
    const start = Date.now();
    await app.fetchUserData(456);
    const duration = Date.now() - start;
    
    if (duration > 400) {
      throw new Error(`Operation took ${duration}ms, expected < 400ms`);
    }
  });

  runner.summary();
}

// Run the tests
runTests().catch(error => {
  console.error('💥 Test suite crashed:', error.message);
  process.exit(1);
});