/**
 * Jest Tests for Flaky Demo App
 * Designed to demonstrate realistic test failures for Watchdog analysis
 */

const FlakyApp = require('./app');

describe('Flaky Demo Application', () => {
  let app;

  beforeEach(() => {
    app = new FlakyApp();
  });

  describe('User Data Management', () => {
    test('should fetch user data successfully', async () => {
      const userData = await app.fetchUserData(123);
      expect(userData).toBeDefined();
      expect(userData.id).toBe(123);
    }, 10000); // 10 second timeout

    test('should handle invalid user IDs', async () => {
      await expect(app.fetchUserData(-1)).rejects.toThrow();
    });
  });

  describe('Database Operations', () => {
    test('should connect to database', async () => {
      const connected = await app.connectDatabase();
      expect(connected).toBe(true);
    });

    test('should handle database connection failures gracefully', async () => {
      // This test might fail intermittently due to race conditions
      const results = await Promise.allSettled([
        app.connectDatabase(),
        app.connectDatabase(),
        app.connectDatabase()
      ]);
      
      const failures = results.filter(r => r.status === 'rejected');
      expect(failures.length).toBeLessThan(2); // Allow some failures
    });
  });

  describe('Email Validation', () => {
    test('should validate lowercase emails', () => {
      expect(() => app.validateEmail('test@example.com')).not.toThrow();
    });

    test('should validate mixed case emails', () => {
      // This test fails due to inconsistent email validation
      expect(() => app.validateEmail('Test@Example.COM')).not.toThrow();
    });

    test('should reject invalid email formats', () => {
      expect(() => app.validateEmail('invalid-email')).toThrow();
    });
  });

  describe('API Operations', () => {
    test('should make successful API calls', async () => {
      const response = await app.makeApiCall('/api/users');
      expect(response).toBeDefined();
      expect(response.data).toBeDefined();
    }, 5000);

    test('should handle multiple concurrent API calls', async () => {
      // This test often fails due to network simulation
      const promises = [
        app.makeApiCall('/api/users'),
        app.makeApiCall('/api/products'),
        app.makeApiCall('/api/orders')
      ];
      
      const results = await Promise.all(promises);
      expect(results).toHaveLength(3);
      results.forEach(result => {
        expect(result.data).toBeDefined();
      });
    }, 8000);
  });

  describe('Performance Tests', () => {
    test('should not create excessive memory leaks', () => {
      const beforeMemory = process.memoryUsage().heapUsed;
      const leakSize = app.createMemoryLeak();
      const afterMemory = process.memoryUsage().heapUsed;
      
      const memoryIncrease = afterMemory - beforeMemory;
      expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024); // 50MB limit
    });

    test('should complete operations within time limits', async () => {
      const start = Date.now();
      await app.fetchUserData(456);
      const duration = Date.now() - start;
      
      // This test fails on slower systems or high load
      expect(duration).toBeLessThan(400);
    });
  });

  describe('String Operations', () => {
    test('should concatenate strings correctly', () => {
      // This test is designed to fail to demonstrate the watchdog
      const result = app.concatenateStrings('hello', 'world');
      expect(result).toBe('hello world'); // Will fail - app returns 'helloworld'
    });

    test('should handle empty strings', () => {
      const result = app.concatenateStrings('', '');
      expect(result).toBe('');
    });
  });

  describe('Math Operations', () => {
    test('should add numbers correctly', () => {
      expect(app.addNumbers(2, 3)).toBe(5);
    });

    test('should multiply numbers correctly', () => {
      expect(app.multiplyNumbers(4, 5)).toBe(20);
    });

    test('should handle division by zero', () => {
      expect(() => app.divideNumbers(10, 0)).toThrow('Division by zero');
    });
  });
});