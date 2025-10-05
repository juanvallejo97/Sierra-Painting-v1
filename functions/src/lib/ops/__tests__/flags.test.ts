/**
 * Unit tests for Feature Flags
 */

 

import { getFlag, clearFlagCache, initializeFlags } from '../flags';

// Mock firebase-admin
const mockFirestore = {
  collection: jest.fn(),
};

jest.mock('firebase-admin', () => ({
  firestore: () => mockFirestore,
}));

// Mock logger
jest.mock('../logger', () => ({
  log: {
    debug: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    error: jest.fn(),
  },
}));

describe('Feature Flags', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    clearFlagCache();
  });

  describe('getFlag()', () => {
    it('should return default value when flag not found', async () => {
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({}),
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
        }),
      });

      const result = await getFlag('nonexistent.flag', false);
      
      expect(result).toBe(false);
    });

    it('should return default value when flag is disabled', async () => {
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          'test.flag': {
            enabled: false,
            type: 'boolean',
          },
        }),
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
        }),
      });

      const result = await getFlag('test.flag', false);
      
      expect(result).toBe(false);
    });

    it('should return enabled status for boolean flags', async () => {
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          'cache.localHotset': {
            enabled: true,
            type: 'boolean',
          },
        }),
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
        }),
      });

      const result = await getFlag('cache.localHotset', false);
      
      expect(result).toBe(true);
    });

    it('should return value for numeric flags', async () => {
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          'tracing.sample': {
            enabled: true,
            value: 0.5,
            type: 'number',
          },
        }),
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
        }),
      });

      const result = await getFlag('tracing.sample', 1.0);
      
      expect(result).toBe(0.5);
    });

    it('should return value for string flags', async () => {
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          'feature.mode': {
            enabled: true,
            value: 'canary',
            type: 'string',
          },
        }),
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
        }),
      });

      const result = await getFlag('feature.mode', 'default');
      
      expect(result).toBe('canary');
    });

    it('should cache flag values', async () => {
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
        data: () => ({
          'test.flag': {
            enabled: true,
            type: 'boolean',
          },
        }),
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
        }),
      });

      // First call
      await getFlag('test.flag', false);
      
      // Second call - should use cache
      await getFlag('test.flag', false);
      
      // Firestore should only be called once
      expect(mockGet).toHaveBeenCalledTimes(1);
    });

    it('should initialize default flags when document does not exist', async () => {
      const mockSet = jest.fn().mockResolvedValue(undefined);
      const mockGet = jest.fn().mockResolvedValue({
        exists: false,
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
          set: mockSet,
        }),
      });

      await getFlag('cache.localHotset', false);
      
      expect(mockSet).toHaveBeenCalledWith(
        expect.objectContaining({
          'cache.localHotset': expect.any(Object),
          'bundles.enable': expect.any(Object),
          'tracing.sample': expect.any(Object),
        })
      );
    });

    it('should return default value on error', async () => {
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: jest.fn().mockRejectedValue(new Error('Firestore error')),
        }),
      });

      const result = await getFlag('test.flag', false);
      
      expect(result).toBe(false);
    });
  });

  describe('initializeFlags()', () => {
    it('should create flags document if it does not exist', async () => {
      const mockSet = jest.fn().mockResolvedValue(undefined);
      const mockGet = jest.fn().mockResolvedValue({
        exists: false,
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
          set: mockSet,
        }),
      });

      await initializeFlags();
      
      expect(mockSet).toHaveBeenCalledWith(
        expect.objectContaining({
          'cache.localHotset': expect.any(Object),
        })
      );
    });

    it('should not overwrite existing flags document', async () => {
      const mockSet = jest.fn();
      const mockGet = jest.fn().mockResolvedValue({
        exists: true,
      });
      
      mockFirestore.collection.mockReturnValue({
        doc: jest.fn().mockReturnValue({
          get: mockGet,
          set: mockSet,
        }),
      });

      await initializeFlags();
      
      expect(mockSet).not.toHaveBeenCalled();
    });
  });
});
