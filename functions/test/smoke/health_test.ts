/**
 * Health endpoint smoke tests
 * 
 * PURPOSE:
 * Verify the /health endpoint returns correct response and dependencies status
 * 
 * SETUP:
 * Run with: npm test -- health_test.ts
 * 
 * SUCCESS CRITERIA:
 * - Health endpoint returns 200 status
 * - Response includes version, timestamp, and status
 * - Response time < 50ms (local) or < 200ms (deployed)
 */

import * as admin from 'firebase-admin';
import * as test from 'firebase-functions-test';

// Initialize test environment
const testEnv = test();

describe('Health Check Function', () => {
  let healthCheckFunction: any;

  beforeAll(() => {
    // Import the function after test environment is initialized
    const functions = require('../../src/index');
    healthCheckFunction = functions.healthCheck;
  });

  afterAll(() => {
    testEnv.cleanup();
  });

  it('should return 200 status with correct response structure', async () => {
    // Mock request and response
    const req = {
      method: 'GET',
      headers: {},
      query: {},
    } as any;

    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
    } as any;

    // Call the function
    await healthCheckFunction(req, res);

    // Verify response
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'ok',
        timestamp: expect.any(String),
        version: expect.any(String),
      })
    );
  });

  it('should return a valid ISO timestamp', async () => {
    const req = { method: 'GET', headers: {}, query: {} } as any;
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn((data: any) => {
        // Verify timestamp is valid ISO string
        expect(() => new Date(data.timestamp)).not.toThrow();
        expect(new Date(data.timestamp).toISOString()).toBe(data.timestamp);
        return res;
      }),
    } as any;

    await healthCheckFunction(req, res);
  });

  it('should include version information', async () => {
    const req = { method: 'GET', headers: {}, query: {} } as any;
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn((data: any) => {
        expect(data.version).toBeDefined();
        expect(typeof data.version).toBe('string');
        expect(data.version.length).toBeGreaterThan(0);
        return res;
      }),
    } as any;

    await healthCheckFunction(req, res);
  });

  it('should respond within performance budget', async () => {
    const req = { method: 'GET', headers: {}, query: {} } as any;
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    } as any;

    const startTime = Date.now();
    await healthCheckFunction(req, res);
    const duration = Date.now() - startTime;

    // Performance budget: 50ms for health check
    // Allow 200ms in test environment
    expect(duration).toBeLessThan(200);
    console.log(`PERFORMANCE_METRIC: health_check_ms=${duration}`);
  });
});
