/**
 * Unit tests for withValidation middleware
 */

/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable @typescript-eslint/no-unsafe-call */
/* eslint-disable @typescript-eslint/no-unused-vars */
/* eslint-disable @typescript-eslint/require-await */

import { z } from 'zod';
import { withValidation, publicEndpoint, authenticatedEndpoint, adminEndpoint } from '../withValidation';

// Mock firebase-functions
jest.mock('firebase-functions', () => {
  const mockRunWith = jest.fn(() => ({
    https: {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-return
      onCall: jest.fn((handler: any) => handler),
    },
  }));

  return {
    https: {
      HttpsError: class HttpsError extends Error {
        constructor(public code: string, public message: string) {
          super(message);
          this.name = 'HttpsError';
        }
      },
      // eslint-disable-next-line @typescript-eslint/no-unsafe-return
      onCall: jest.fn((handler: any) => handler),
    },
    logger: {
      debug: jest.fn(),
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
    },
    runWith: mockRunWith,
  };
});

// Mock firebase-admin
jest.mock('firebase-admin', () => ({
  firestore: jest.fn(() => ({
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn(),
      })),
    })),
  })),
}));

// Mock ops logger
jest.mock('../../lib/ops', () => ({
  log: {
    child: jest.fn(() => ({
      child: jest.fn(() => ({
        warn: jest.fn(),
        info: jest.fn(),
        error: jest.fn(),
        debug: jest.fn(),
        perf: jest.fn(),
      })),
      warn: jest.fn(),
      info: jest.fn(),
      error: jest.fn(),
      debug: jest.fn(),
      perf: jest.fn(),
    })),
  },
  getOrCreateRequestId: jest.fn(() => 'req_test_123'),
}));

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

describe('withValidation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const TestSchema = z.object({
    name: z.string().min(1),
    value: z.number().positive(),
  }).strict();

  type TestInput = z.infer<typeof TestSchema>;

  describe('Authentication', () => {
    it('should reject unauthenticated requests when requireAuth is true', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { requireAuth: true })(handler);

      const context = {
        auth: undefined,
        app: { token: 'valid' },
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: 'test', value: 42 } as any, context)
      ).rejects.toThrow('User must be authenticated');

      expect(handler).not.toHaveBeenCalled();
    });

    it('should allow authenticated requests', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true, data }));
      const wrappedFn = withValidation(TestSchema, { requireAuth: true })(handler);

      const context = {
        auth: { uid: 'user_123', token: {} },
        app: { token: 'valid' },
        rawRequest: { headers: {} },
      } as any;

      const result = await wrappedFn({ name: 'test', value: 42 } as any, context);

      expect(result).toEqual({ 
        success: true, 
        data: { name: 'test', value: 42 } 
      });
      expect(handler).toHaveBeenCalledWith(
        { name: 'test', value: 42 },
        expect.objectContaining({
          auth: { uid: 'user_123', token: {} },
          requestId: 'req_test_123',
        })
      );
    });

    it('should allow unauthenticated requests when requireAuth is false', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { requireAuth: false })(handler);

      const context = {
        auth: undefined,
        app: { token: 'valid' },
        rawRequest: { headers: {} },
      } as any;

      const result = await wrappedFn({ name: 'test', value: 42 } as any, context);

      expect(result).toEqual({ success: true });
      expect(handler).toHaveBeenCalled();
    });
  });

  describe('App Check', () => {
    it('should reject requests without App Check when requireAppCheck is true', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: true,
        requireAppCheck: true,
      })(handler);

      const context = {
        auth: { uid: 'user_123', token: {} },
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: 'test', value: 42 } as any, context)
      ).rejects.toThrow('App Check validation failed');

      expect(handler).not.toHaveBeenCalled();
    });

    it('should allow requests with valid App Check', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: true,
        requireAppCheck: true,
      })(handler);

      const context = {
        auth: { uid: 'user_123', token: {} },
        app: { token: 'valid_app_check_token' },
        rawRequest: { headers: {} },
      } as any;

      const result = await wrappedFn({ name: 'test', value: 42 } as any, context);

      expect(result).toEqual({ success: true });
      expect(handler).toHaveBeenCalled();
    });

    it('should allow requests without App Check when requireAppCheck is false', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: true,
        requireAppCheck: false,
      })(handler);

      const context = {
        auth: { uid: 'user_123', token: {} },
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      const result = await wrappedFn({ name: 'test', value: 42 } as any, context);

      expect(result).toEqual({ success: true });
      expect(handler).toHaveBeenCalled();
    });
  });

  describe('Input Validation', () => {
    it('should reject invalid input and return detailed error', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: false,
        requireAppCheck: false,
      })(handler);

      const context = {
        auth: undefined,
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: '', value: -1 } as any, context)
      ).rejects.toThrow(/Validation failed/);

      expect(handler).not.toHaveBeenCalled();
    });

    it('should reject unknown fields in strict schema', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: false,
        requireAppCheck: false,
      })(handler);

      const context = {
        auth: undefined,
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: 'test', value: 42, extra: 'field' } as any, context)
      ).rejects.toThrow(/Validation failed/);

      expect(handler).not.toHaveBeenCalled();
    });

    it('should accept valid input', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ 
        success: true, 
        received: data 
      }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: false,
        requireAppCheck: false,
      })(handler);

      const context = {
        auth: undefined,
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      const result = await wrappedFn({ name: 'test', value: 42 } as any, context);

      expect(result).toEqual({ 
        success: true, 
        received: { name: 'test', value: 42 } 
      });
      expect(handler).toHaveBeenCalledWith(
        { name: 'test', value: 42 },
        expect.any(Object)
      );
    });
  });

  describe('Admin Authorization', () => {
    it('should reject non-admin users when requireAdmin is true', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: true,
        requireAdmin: true,
        requireAppCheck: false,
      })(handler);

      // Mock Firestore to return non-admin user
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({ role: 'crew', orgId: 'org_123' }),
      });
      
      (admin.firestore as any).mockReturnValue({
        collection: jest.fn(() => ({
          doc: jest.fn(() => ({
            get: mockGet,
          })),
        })),
      });

      const context = {
        auth: { uid: 'user_123', token: {} },
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: 'test', value: 42 } as any, context)
      ).rejects.toThrow('User must be an admin');

      expect(handler).not.toHaveBeenCalled();
      expect(mockGet).toHaveBeenCalled();
    });

    it('should allow admin users when requireAdmin is true', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: true,
        requireAdmin: true,
        requireAppCheck: false,
      })(handler);

      // Mock Firestore to return admin user
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({ role: 'admin', orgId: 'org_123' }),
      });
      
      (admin.firestore as any).mockReturnValue({
        collection: jest.fn(() => ({
          doc: jest.fn(() => ({
            get: mockGet,
          })),
        })),
      });

      const context = {
        auth: { uid: 'user_admin', token: {} },
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      const result = await wrappedFn({ name: 'test', value: 42 } as any, context);

      expect(result).toEqual({ success: true });
      expect(handler).toHaveBeenCalled();
      expect(mockGet).toHaveBeenCalled();
    });

    it('should reject when user profile not found', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: true,
        requireAdmin: true,
        requireAppCheck: false,
      })(handler);

      // Mock Firestore to return non-existent user
      const mockGet = jest.fn().mockResolvedValue({
        exists: false,
      });
      
      (admin.firestore as any).mockReturnValue({
        collection: jest.fn(() => ({
          doc: jest.fn(() => ({
            get: mockGet,
          })),
        })),
      });

      const context = {
        auth: { uid: 'user_unknown', token: {} },
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: 'test', value: 42 } as any, context)
      ).rejects.toThrow('User profile not found');

      expect(handler).not.toHaveBeenCalled();
    });
  });

  describe('Custom Role Check', () => {
    it('should use custom role check function', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const customRoleCheck = jest.fn((role: string) => role === 'crewLead');
      
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: true,
        requireRole: customRoleCheck,
        requireAppCheck: false,
      })(handler);

      // Mock Firestore to return crew_lead user
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({ role: 'crewLead', orgId: 'org_123' }),
      });
      
      (admin.firestore as any).mockReturnValue({
        collection: jest.fn(() => ({
          doc: jest.fn(() => ({
            get: mockGet,
          })),
        })),
      });

      const context = {
        auth: { uid: 'user_lead', token: {} },
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      const result = await wrappedFn({ name: 'test', value: 42 } as any, context);

      expect(result).toEqual({ success: true });
      expect(customRoleCheck).toHaveBeenCalledWith('crewLead');
      expect(handler).toHaveBeenCalled();
    });

    it('should reject when custom role check fails', async () => {
      const handler = jest.fn(async (data: TestInput) => ({ success: true }));
      const customRoleCheck = jest.fn((role: string) => role === 'admin');
      
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: true,
        requireRole: customRoleCheck,
        requireAppCheck: false,
      })(handler);

      // Mock Firestore to return regular crew user
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({ role: 'crew', orgId: 'org_123' }),
      });
      
      (admin.firestore as any).mockReturnValue({
        collection: jest.fn(() => ({
          doc: jest.fn(() => ({
            get: mockGet,
          })),
        })),
      });

      const context = {
        auth: { uid: 'user_crew', token: {} },
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: 'test', value: 42 } as any, context)
      ).rejects.toThrow('Insufficient permissions');

      expect(customRoleCheck).toHaveBeenCalledWith('crew');
      expect(handler).not.toHaveBeenCalled();
    });
  });

  describe('Error Handling', () => {
    it('should wrap handler errors in HttpsError', async () => {
      const handler = jest.fn(async () => {
        throw new Error('Internal handler error');
      });
      
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: false,
        requireAppCheck: false,
      })(handler);

      const context = {
        auth: undefined,
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: 'test', value: 42 } as any, context)
      ).rejects.toThrow('An internal error occurred');

      expect(handler).toHaveBeenCalled();
    });

    it('should preserve HttpsError from handler', async () => {
      const customError = new functions.https.HttpsError(
        'not-found',
        'Resource not found'
      );
      const handler = jest.fn(async () => {
        throw customError;
      });
      
      const wrappedFn = withValidation(TestSchema, { 
        requireAuth: false,
        requireAppCheck: false,
      })(handler);

      const context = {
        auth: undefined,
        app: undefined,
        rawRequest: { headers: {} },
      } as any;

      await expect(
        wrappedFn({ name: 'test', value: 42 } as any, context)
      ).rejects.toThrow('Resource not found');

      expect(handler).toHaveBeenCalled();
    });
  });

  describe('Preset Configurations', () => {
    it('should configure publicEndpoint preset correctly', () => {
      const options = publicEndpoint();
      expect(options).toEqual({
        requireAuth: false,
        requireAppCheck: true,
      });
    });

    it('should configure authenticatedEndpoint preset correctly', () => {
      const options = authenticatedEndpoint();
      expect(options).toEqual({
        requireAuth: true,
        requireAppCheck: true,
      });
    });

    it('should configure adminEndpoint preset correctly', () => {
      const options = adminEndpoint();
      expect(options).toEqual({
        requireAuth: true,
        requireAppCheck: true,
        requireAdmin: true,
      });
    });

    it('should allow overriding preset options', () => {
      const options = adminEndpoint({ requireAppCheck: false });
      expect(options).toEqual({
        requireAuth: true,
        requireAppCheck: false,
        requireAdmin: true,
      });
    });
  });
});
