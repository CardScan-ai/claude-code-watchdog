/**
 * Flaky Demo App - Intentionally unreliable for testing Claude Code Watchdog
 */

class FlakyApp {
  constructor() {
    this.server = null;
    this.database = { connected: false, users: [] };
  }

  // Flaky method: fails ~50% due to timeout issues
  async fetchUserData(userId) {
    const delay = Math.random() * 1000;
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        if (delay > 500) {  // 50% chance of "timeout"
          reject(new Error(`Request timeout after ${delay}ms for user ${userId}`));
        } else {
          resolve({ id: userId, name: `User ${userId}`, delay: delay });
        }
      }, delay);
    });
  }

  // Race condition: sometimes fails due to async timing
  async connectDatabase() {
    const connectTime = Math.random() * 200;
    
    // Fix: Properly wait for the connection to complete
    await new Promise(resolve => {
      setTimeout(() => {
        this.database.connected = true;
        resolve();
      }, connectTime);
    });
    
    // Now safe to check connection status
    if (!this.database.connected) {
      throw new Error('Database connection failed - timing issue');
    }
    
    return true;
  }

  // Flaky validation: strict but inconsistent
  validateEmail(email) {
    if (!email || typeof email !== 'string') {
      throw new Error('Email is required and must be a string');
    }
    
    // Sometimes case-sensitive, sometimes not
    const strictMode = Math.random() > 0.5;
    const emailRegex = strictMode 
      ? /^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/  // lowercase only
      : /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/; // any case
    
    if (!emailRegex.test(email)) {
      throw new Error(`Invalid email format: ${email} (strict mode: ${strictMode})`);
    }
    
    return true;
  }

  // Network simulation: fails randomly
  async makeApiCall(endpoint) {
    const networkDelay = Math.random() * 2000;
    const shouldFail = Math.random() > 0.7; // 30% failure rate
    
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        if (shouldFail) {
          const errors = [
            'Network timeout',
            'Connection refused',
            'DNS resolution failed',
            '500 Internal Server Error',
            'Rate limit exceeded'
          ];
          reject(new Error(errors[Math.floor(Math.random() * errors.length)]));
        } else {
          resolve({ endpoint, data: 'success', delay: networkDelay });
        }
      }, networkDelay);
    });
  }

  // Memory leak simulation (for demonstration)
  createMemoryLeak() {
    const leak = [];
    for (let i = 0; i < 100000; i++) {
      leak.push(`memory_${i}_${Math.random()}`);
    }
    // Intentionally not cleaning up
    return leak.length;
  }

  // String operations (with intentional bug)
  concatenateStrings(str1, str2) {
    // FIX: Add space between strings for proper concatenation
    return str1 + ' ' + str2;
  }

  // Math operations
  addNumbers(a, b) {
    return a + b;
  }

  multiplyNumbers(a, b) {
    return a * b;
  }

  divideNumbers(a, b) {
    if (b === 0) {
      throw new Error('Division by zero');
    }
    return a / b;
  }
}

module.exports = FlakyApp;