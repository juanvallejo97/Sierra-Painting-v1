/**
 * Unit tests for Logger
 */

 

import { Logger, log, getOrCreateRequestId } from '../logger';

// Mock firebase-functions logger
jest.mock('firebase-functions', () => ({
  logger: {
    debug: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

import * as functions from 'firebase-functions';

describe('Logger', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('child()', () => {
    it('should create child logger with merged context', () => {
      const parent = new Logger({ requestId: 'req_123' });
      const child = parent.child({ userId: 'user_456' });
      
      child.info('test_event', { extra: 'data' });
      
      expect(functions.logger.info).toHaveBeenCalledWith(
        'test_event',
        expect.objectContaining({
          context: {
            requestId: 'req_123',
            userId: 'user_456',
          },
          extra: 'data',
        })
      );
    });
  });

  describe('info()', () => {
    it('should log at INFO level with structured data', () => {
      const logger = new Logger({ requestId: 'req_123' });
      
      logger.info('payment_created', { invoiceId: 'inv_456', amount: 15000 });
      
      expect(functions.logger.info).toHaveBeenCalledWith(
        'payment_created',
        expect.objectContaining({
          severity: 'INFO',
          message: 'payment_created',
          context: { requestId: 'req_123' },
          invoiceId: 'inv_456',
          amount: 15000,
        })
      );
    });
  });

  describe('error()', () => {
    it('should log Error objects with stack trace', () => {
      const logger = new Logger({ requestId: 'req_123' });
      const error = new Error('Test error');
      
      logger.error('operation_failed', error);
      
      expect(functions.logger.error).toHaveBeenCalledWith(
        'operation_failed',
        expect.objectContaining({
          severity: 'ERROR',
          message: 'operation_failed',
          error: 'Test error',
          stack: expect.any(String),
        })
      );
    });

    it('should log plain objects', () => {
      const logger = new Logger({ requestId: 'req_123' });
      
      logger.error('operation_failed', { reason: 'timeout' });
      
      expect(functions.logger.error).toHaveBeenCalledWith(
        'operation_failed',
        expect.objectContaining({
          severity: 'ERROR',
          message: 'operation_failed',
          reason: 'timeout',
        })
      );
    });
  });

  describe('perf()', () => {
    it('should log performance metrics', () => {
      const logger = new Logger({ requestId: 'req_123' });
      
      logger.perf('processPayment', 245, {
        firestoreReads: 5,
        firestoreWrites: 2,
      });
      
      expect(functions.logger.info).toHaveBeenCalledWith(
        'processPayment_performance',
        expect.objectContaining({
          severity: 'INFO',
          message: 'processPayment_performance',
          operation: 'processPayment',
          latencyMs: 245,
          firestoreReads: 5,
          firestoreWrites: 2,
        })
      );
    });
  });

  describe('default logger', () => {
    it('should provide default logger instance', () => {
      log.info('test_event');
      
      expect(functions.logger.info).toHaveBeenCalledWith(
        'test_event',
        expect.objectContaining({
          severity: 'INFO',
          message: 'test_event',
        })
      );
    });
  });
});

describe('getOrCreateRequestId', () => {
  it('should extract existing request ID from headers', () => {
    const headers = {
      'x-request-id': 'existing_req_123',
      'content-type': 'application/json',
    };
    
    const requestId = getOrCreateRequestId(headers);
    
    expect(requestId).toBe('existing_req_123');
  });

  it('should extract request ID from X-Request-ID header', () => {
    const headers = {
      'X-Request-ID': 'existing_req_456',
    };
    
    const requestId = getOrCreateRequestId(headers);
    
    expect(requestId).toBe('existing_req_456');
  });

  it('should generate new request ID when headers missing', () => {
    const requestId = getOrCreateRequestId(undefined);
    
    expect(requestId).toMatch(/^req_\d+_[a-z0-9]+$/);
  });

  it('should generate new request ID when no x-request-id header', () => {
    const headers = {
      'content-type': 'application/json',
    };
    
    const requestId = getOrCreateRequestId(headers);
    
    expect(requestId).toMatch(/^req_\d+_[a-z0-9]+$/);
  });

  it('should handle array values in headers', () => {
    const headers = {
      'x-request-id': ['req_first', 'req_second'],
    };
    
    const requestId = getOrCreateRequestId(headers);
    
    expect(requestId).toBe('req_first');
  });
});
