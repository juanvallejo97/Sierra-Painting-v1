/**
 * Unit tests for HTTP Client
 */

 

import { httpClient } from '../httpClient';
import fetch from 'node-fetch';

// Mock node-fetch
jest.mock('node-fetch');
const mockFetch = fetch as jest.MockedFunction<typeof fetch>;

// Mock tracing
jest.mock('../tracing', () => ({
  startChildSpan: jest.fn(() => ({
    setAttribute: jest.fn(),
    recordException: jest.fn(),
    end: jest.fn(),
  })),
}));

// Mock logger
jest.mock('../logger', () => ({
  log: {
    warn: jest.fn(),
  },
}));

describe('HTTP Client', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('get()', () => {
    it('should make successful GET request', async () => {
      const mockResponse = {
        status: 200,
        statusText: 'OK',
        headers: new Map([['content-type', 'application/json']]),
        text: jest.fn().mockResolvedValue('{"success":true}'),
      };
      
      mockFetch.mockResolvedValue(mockResponse as any);

      const response = await httpClient.get('https://api.example.com/test');
      
      expect(response.status).toBe(200);
      expect(response.body).toBe('{"success":true}');
      expect(response.json()).toEqual({ success: true });
    });
  });

  describe('post()', () => {
    it('should make successful POST request', async () => {
      const mockResponse = {
        status: 201,
        statusText: 'Created',
        headers: new Map([['content-type', 'application/json']]),
        text: jest.fn().mockResolvedValue('{"id":"123"}'),
      };
      
      mockFetch.mockResolvedValue(mockResponse as any);

      const response = await httpClient.post('https://api.example.com/create', {
        body: JSON.stringify({ name: 'test' }),
        headers: { 'Content-Type': 'application/json' },
      });
      
      expect(response.status).toBe(201);
      expect(response.json()).toEqual({ id: '123' });
    });
  });

  describe('retry logic', () => {
    it('should retry on 500 status code', async () => {
      const mockErrorResponse = {
        status: 500,
        statusText: 'Internal Server Error',
        headers: new Map(),
        text: jest.fn().mockResolvedValue('Error'),
      };
      
      const mockSuccessResponse = {
        status: 200,
        statusText: 'OK',
        headers: new Map(),
        text: jest.fn().mockResolvedValue('{"success":true}'),
      };
      
      mockFetch
        .mockResolvedValueOnce(mockErrorResponse as any)
        .mockResolvedValueOnce(mockSuccessResponse as any);

      const response = await httpClient.get('https://api.example.com/test', {
        retries: 1,
      });
      
      expect(response.status).toBe(200);
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('should retry on 429 status code', async () => {
      const mockErrorResponse = {
        status: 429,
        statusText: 'Too Many Requests',
        headers: new Map(),
        text: jest.fn().mockResolvedValue('Rate limited'),
      };
      
      const mockSuccessResponse = {
        status: 200,
        statusText: 'OK',
        headers: new Map(),
        text: jest.fn().mockResolvedValue('{"success":true}'),
      };
      
      mockFetch
        .mockResolvedValueOnce(mockErrorResponse as any)
        .mockResolvedValueOnce(mockSuccessResponse as any);

      const response = await httpClient.get('https://api.example.com/test', {
        retries: 1,
      });
      
      expect(response.status).toBe(200);
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('should not retry on 404 status code', async () => {
      const mockResponse = {
        status: 404,
        statusText: 'Not Found',
        headers: new Map(),
        text: jest.fn().mockResolvedValue('Not found'),
      };
      
      mockFetch.mockResolvedValue(mockResponse as any);

      const response = await httpClient.get('https://api.example.com/test', {
        retries: 3,
      });
      
      expect(response.status).toBe(404);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });

    it('should throw error after max retries', async () => {
      const mockErrorResponse = {
        status: 500,
        statusText: 'Internal Server Error',
        headers: new Map(),
        text: jest.fn().mockResolvedValue('Error'),
      };
      
      mockFetch.mockResolvedValue(mockErrorResponse as any);

      const response = await httpClient.get('https://api.example.com/test', {
        retries: 2,
      });
      
      // Should still return the error response after retries
      expect(response.status).toBe(500);
      expect(mockFetch).toHaveBeenCalledTimes(3); // Initial + 2 retries
    });

    it('should retry on network errors', async () => {
      const mockError = new Error('ECONNRESET');
      const mockSuccessResponse = {
        status: 200,
        statusText: 'OK',
        headers: new Map(),
        text: jest.fn().mockResolvedValue('{"success":true}'),
      };
      
      mockFetch
        .mockRejectedValueOnce(mockError)
        .mockResolvedValueOnce(mockSuccessResponse as any);

      const response = await httpClient.get('https://api.example.com/test', {
        retries: 1,
      });
      
      expect(response.status).toBe(200);
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });
  });

  describe('timeout', () => {
    it('should timeout after specified duration', async () => {
      const mockError = new Error('AbortError');
      mockError.name = 'AbortError';
      
      mockFetch.mockRejectedValue(mockError);

      await expect(
        httpClient.get('https://api.example.com/slow', {
          timeout: 100,
          retries: 0,
        })
      ).rejects.toThrow();
      
      expect(mockFetch).toHaveBeenCalled();
    });
  });

  describe('methods', () => {
    it('should support PUT requests', async () => {
      const mockResponse = {
        status: 200,
        statusText: 'OK',
        headers: new Map(),
        text: jest.fn().mockResolvedValue('{"success":true}'),
      };
      
      mockFetch.mockResolvedValue(mockResponse as any);

      await httpClient.put('https://api.example.com/update');
      
      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.example.com/update',
        expect.objectContaining({
          method: 'PUT',
        })
      );
    });

    it('should support DELETE requests', async () => {
      const mockResponse = {
        status: 204,
        statusText: 'No Content',
        headers: new Map(),
        text: jest.fn().mockResolvedValue(''),
      };
      
      mockFetch.mockResolvedValue(mockResponse as any);

      await httpClient.delete('https://api.example.com/delete');
      
      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.example.com/delete',
        expect.objectContaining({
          method: 'DELETE',
        })
      );
    });
  });
});
