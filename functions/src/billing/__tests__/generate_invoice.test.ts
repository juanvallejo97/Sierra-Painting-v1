/**
 * Tests for generate_invoice.ts
 *
 * Test Coverage:
 * - Authentication: Unauthenticated requests rejected
 * - Authorization: Only admin/manager roles allowed
 * - Company isolation: Cannot invoice another company's time entries
 * - Validation: Request schema validation (Zod)
 * - Business logic: Hour calculation, line item generation, invoice creation
 * - Idempotency: Cannot invoice same time entry twice
 * - Status checks: Only approved, clocked-out entries can be invoiced
 * - Batch updates: Time entries marked with invoiceId
 */

import * as admin from 'firebase-admin';
import { CallableRequest, HttpsError } from 'firebase-functions/v2/https';

// Mock Firebase Admin before importing the function
jest.mock('firebase-admin', () => {
  const mockBatch = {
    update: jest.fn(),
    commit: jest.fn().mockResolvedValue(undefined),
  };

  const mockFirestore = {
    collection: jest.fn(),
    batch: jest.fn(() => mockBatch),
  };

  const firestoreFunction: any = jest.fn(() => mockFirestore);

  // Add static properties to the firestore function
  firestoreFunction.FieldPath = {
    documentId: jest.fn(() => '__name__'),
  };
  firestoreFunction.Timestamp = {
    fromDate: jest.fn((date: Date) => ({ toDate: () => date })),
  };
  firestoreFunction.FieldValue = {
    serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP'),
  };

  return {
    firestore: firestoreFunction,
  };
});

// Mock the helper functions
jest.mock('../calculate_hours', () => ({
  calculateHours: jest.fn((entries: any[]) => {
    // Simple mock: 1 hour per entry
    return entries.length * 1.0;
  }),
  groupEntriesByJob: jest.fn((entries: any[]) => {
    const grouped: Record<string, any[]> = {};
    for (const entry of entries) {
      if (!grouped[entry.jobId]) grouped[entry.jobId] = [];
      grouped[entry.jobId].push(entry);
    }
    return grouped;
  }),
}));

// Import after mocking
import { generateInvoiceHandler } from '../generate_invoice';
import { calculateHours } from '../calculate_hours';

describe('generateInvoice', () => {
  let mockDb: any;
  let mockRequest: any;
  let mockTimeEntriesSnapshot: any;
  let mockCompanyDoc: any;
  let mockJobsSnapshot: any;
  let mockInvoiceRef: any;
  let mockBatch: any;

  beforeEach(() => {
    jest.clearAllMocks();

    // Setup mock Firestore
    mockDb = admin.firestore();
    mockBatch = mockDb.batch();

    // Default valid request (admin user)
    mockRequest = {
      data: {},
      auth: {
        uid: 'user-123',
        token: {
          role: 'admin',
          company_id: 'company-1',
        } as any,
      },
      rawRequest: {} as any,
      acceptsStreaming: false,
      instanceIdToken: undefined,
      appCheckToken: undefined,
    } as unknown as CallableRequest;

    // Mock time entries snapshot
    mockTimeEntriesSnapshot = {
      empty: false,
      docs: [
        {
          id: 'entry-1',
          data: () => ({
            companyId: 'company-1',
            workerId: 'worker-1',
            jobId: 'job-1',
            status: 'approved',
            clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
            clockOut: { toDate: () => new Date('2025-10-11T12:00:00Z') },
          }),
        },
        {
          id: 'entry-2',
          data: () => ({
            companyId: 'company-1',
            workerId: 'worker-1',
            jobId: 'job-2',
            status: 'approved',
            clockIn: { toDate: () => new Date('2025-10-11T13:00:00Z') },
            clockOut: { toDate: () => new Date('2025-10-11T17:00:00Z') },
          }),
        },
      ],
    };

    // Mock company document
    mockCompanyDoc = {
      exists: true,
      data: () => ({ defaultHourlyRate: 50.0 }),
    };

    // Mock jobs snapshot
    mockJobsSnapshot = {
      docs: [
        {
          id: 'job-1',
          data: () => ({ name: 'Kitchen Remodel', hourlyRate: 60.0 }),
        },
        {
          id: 'job-2',
          data: () => ({ name: 'Bathroom Paint', hourlyRate: 45.0 }),
        },
      ],
    };

    // Mock invoice reference
    mockInvoiceRef = { id: 'invoice-123' };

    // Setup Firestore query chain
    const mockCollectionRef = {
      where: jest.fn().mockReturnThis(),
      get: jest.fn(),
      doc: jest.fn((docId: string) => {
        if (docId === 'company-1') {
          return { get: jest.fn().mockResolvedValue(mockCompanyDoc) };
        }
        return { get: jest.fn() };
      }),
      add: jest.fn().mockResolvedValue(mockInvoiceRef),
    };

    mockDb.collection.mockImplementation((collectionName: string) => {
      if (collectionName === 'timeEntries') {
        mockCollectionRef.get.mockResolvedValue(mockTimeEntriesSnapshot);
      } else if (collectionName === 'jobs') {
        mockCollectionRef.get.mockResolvedValue(mockJobsSnapshot);
      } else if (collectionName === 'companies') {
        return mockCollectionRef;
      } else if (collectionName === 'invoices') {
        return mockCollectionRef;
      }
      return mockCollectionRef;
    });
  });

  describe('Authentication', () => {
    it('should reject unauthenticated requests', async () => {
      mockRequest.auth = undefined;

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'User must be authenticated'
      );
    });
  });

  describe('Authorization', () => {
    it('should allow admin role', async () => {
      mockRequest.auth!.token.role = 'admin';

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });
      expect(result.ok).toBe(true);
    });

    it('should allow manager role', async () => {
      mockRequest.auth!.token.role = 'manager';

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });
      expect(result.ok).toBe(true);
    });

    it('should reject worker role', async () => {
      mockRequest.auth!.token.role = 'worker';

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Only admins and managers can generate invoices'
      );
    });

    it('should reject requests without role', async () => {
      mockRequest.auth!.token.role = undefined;

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Only admins and managers can generate invoices'
      );
    });
  });

  describe('Company Isolation', () => {
    it('should reject invoicing another company', async () => {
      mockRequest.auth!.token.company_id = 'company-2'; // Different company

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Cannot generate invoice for another company'
      );
    });

    it('should reject time entries from different company', async () => {
      // Mock time entry belonging to different company
      mockTimeEntriesSnapshot.docs[0].data = () => ({
        companyId: 'company-2', // Different company
        workerId: 'worker-1',
        jobId: 'job-1',
        status: 'approved',
        clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
        clockOut: { toDate: () => new Date('2025-10-11T12:00:00Z') },
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'belongs to different company'
      );
    });
  });

  describe('Request Validation', () => {
    it('should reject invalid companyId (empty)', async () => {
      const data = {
        companyId: '',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Invalid request'
      );
    });

    it('should reject invalid customerId (empty)', async () => {
      const data = {
        companyId: 'company-1',
        customerId: '',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Invalid request'
      );
    });

    it('should reject empty timeEntryIds array', async () => {
      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: [],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Invalid request'
      );
    });

    it('should reject invalid dueDate format', async () => {
      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '11/10/2025', // Wrong format (should be YYYY-MM-DD)
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Invalid request'
      );
    });

    it('should accept valid request', async () => {
      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
        notes: 'October 2025 services',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });
      expect(result.ok).toBe(true);
    });

    it('should accept optional jobId', async () => {
      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
        jobId: 'job-1',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });
      expect(result.ok).toBe(true);
      expect(result.invoiceId).toBe('invoice-123');
    });
  });

  describe('Time Entry Validation', () => {
    it('should reject non-approved time entries', async () => {
      mockTimeEntriesSnapshot.docs[0].data = () => ({
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        status: 'pending', // Not approved
        clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
        clockOut: { toDate: () => new Date('2025-10-11T12:00:00Z') },
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'is not approved'
      );
    });

    it('should reject already-invoiced time entries', async () => {
      mockTimeEntriesSnapshot.docs[0].data = () => ({
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        status: 'approved',
        clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
        clockOut: { toDate: () => new Date('2025-10-11T12:00:00Z') },
        invoiceId: 'invoice-999', // Already invoiced
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'is already invoiced'
      );
    });

    it('should reject active time entries (not clocked out)', async () => {
      mockTimeEntriesSnapshot.docs[0].data = () => ({
        companyId: 'company-1',
        workerId: 'worker-1',
        jobId: 'job-1',
        status: 'approved',
        clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
        clockOut: null, // Still active
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'is still active'
      );
    });

    it('should reject if no time entries found', async () => {
      mockTimeEntriesSnapshot.empty = true;
      mockTimeEntriesSnapshot.docs = [];

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-999'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'No time entries found'
      );
    });
  });

  describe('Invoice Creation', () => {
    it('should create invoice with correct structure', async () => {
      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
        notes: 'October services',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });

      expect(result.ok).toBe(true);
      expect(result.invoiceId).toBe('invoice-123');
      expect(result.lineItems).toBe(2); // 2 jobs
      expect(result.timeEntriesInvoiced).toBe(2);

      // Verify invoice data structure
      const invoicesCollection = mockDb.collection('invoices');
      expect(invoicesCollection.add).toHaveBeenCalledWith(
        expect.objectContaining({
          companyId: 'company-1',
          customerId: 'customer-1',
          status: 'pending',
          currency: 'USD',
          notes: 'October services',
        })
      );
    });

    it('should calculate total amount correctly', async () => {
      // Mock calculateHours to return specific values
      (calculateHours as jest.Mock).mockImplementation((entries: any[]) => {
        // job-1: 4 hours, job-2: 3 hours
        if (entries[0].jobId === 'job-1') return 4.0;
        if (entries[0].jobId === 'job-2') return 3.0;
        return 1.0;
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });

      // job-1: 4 hours * $60/hr = $240
      // job-2: 3 hours * $45/hr = $135
      // Total: $375
      expect(result.amount).toBe(375.0);
    });

    it('should use company default hourly rate if job rate not set', async () => {
      // Mock only one entry and one job without hourly rate
      mockTimeEntriesSnapshot.docs = [
        {
          id: 'entry-1',
          data: () => ({
            companyId: 'company-1',
            workerId: 'worker-1',
            jobId: 'job-1',
            status: 'approved',
            clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
            clockOut: { toDate: () => new Date('2025-10-11T12:00:00Z') },
          }),
        },
      ];

      mockJobsSnapshot.docs = [
        {
          id: 'job-1',
          data: () => ({
            name: 'Kitchen Remodel',
            // No hourlyRate field
          }),
        },
      ];

      (calculateHours as jest.Mock).mockReturnValue(5.0);

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });

      // 5 hours * $50/hr (default) = $250
      expect(result.amount).toBe(250.0);
    });

    it('should use $50/hr default if company has no default rate', async () => {
      // Mock company with no defaultHourlyRate
      mockCompanyDoc.data = () => ({}); // No defaultHourlyRate

      // Mock only one entry and one job without hourly rate
      mockTimeEntriesSnapshot.docs = [
        {
          id: 'entry-1',
          data: () => ({
            companyId: 'company-1',
            workerId: 'worker-1',
            jobId: 'job-1',
            status: 'approved',
            clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
            clockOut: { toDate: () => new Date('2025-10-11T12:00:00Z') },
          }),
        },
      ];

      mockJobsSnapshot.docs = [
        {
          id: 'job-1',
          data: () => ({
            name: 'Kitchen Remodel',
            // No hourlyRate field
          }),
        },
      ];

      (calculateHours as jest.Mock).mockReturnValue(10.0);

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });

      // 10 hours * $50/hr (fallback) = $500
      expect(result.amount).toBe(500.0);
    });

    it('should create line items with job names', async () => {
      (calculateHours as jest.Mock).mockImplementation((entries: any[]) => {
        return entries.length * 2.0; // 2 hours per entry
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
      };

      await generateInvoiceHandler({ ...mockRequest, data });

      const invoicesCollection = mockDb.collection('invoices');
      const invoiceData = (invoicesCollection.add as jest.Mock).mock.calls[0][0];

      expect(invoiceData.items).toHaveLength(2);
      expect(invoiceData.items[0].description).toContain('Kitchen Remodel');
      expect(invoiceData.items[1].description).toContain('Bathroom Paint');
    });

    it('should set jobId to first job if multiple jobs', async () => {
      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
      };

      await generateInvoiceHandler({ ...mockRequest, data });

      const invoicesCollection = mockDb.collection('invoices');
      const invoiceData = (invoicesCollection.add as jest.Mock).mock.calls[0][0];

      expect(invoiceData.jobId).toBe('job-1'); // First job
    });

    it('should use provided jobId if specified', async () => {
      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
        jobId: 'job-999',
      };

      await generateInvoiceHandler({ ...mockRequest, data });

      const invoicesCollection = mockDb.collection('invoices');
      const invoiceData = (invoicesCollection.add as jest.Mock).mock.calls[0][0];

      expect(invoiceData.jobId).toBe('job-999');
    });
  });

  describe('Batch Updates', () => {
    it('should update all time entries with invoiceId', async () => {
      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
      };

      await generateInvoiceHandler({ ...mockRequest, data });

      expect(mockBatch.update).toHaveBeenCalledTimes(2);
      expect(mockBatch.update).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          invoiceId: 'invoice-123',
          updatedAt: 'SERVER_TIMESTAMP',
        })
      );
      expect(mockBatch.commit).toHaveBeenCalledTimes(1);
    });
  });

  describe('Error Handling', () => {
    it('should handle company not found', async () => {
      mockCompanyDoc.exists = false;

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Company not found'
      );
    });

    it('should handle Firestore errors', async () => {
      const mockError = new Error('Firestore unavailable');
      mockDb.collection.mockImplementation(() => {
        throw mockError;
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        'Failed to generate invoice'
      );
    });

    it('should wrap non-HttpsError errors', async () => {
      const mockError = new Error('Unknown error');
      mockDb.collection.mockImplementation(() => {
        throw mockError;
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1'],
        dueDate: '2025-11-10',
      };

      await expect(generateInvoiceHandler({ ...mockRequest, data })).rejects.toThrow(
        HttpsError
      );
    });
  });

  describe('Integration Scenarios', () => {
    it('should handle single job, multiple workers', async () => {
      mockTimeEntriesSnapshot.docs = [
        {
          id: 'entry-1',
          data: () => ({
            companyId: 'company-1',
            workerId: 'worker-1',
            jobId: 'job-1',
            status: 'approved',
            clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
            clockOut: { toDate: () => new Date('2025-10-11T12:00:00Z') },
          }),
        },
        {
          id: 'entry-2',
          data: () => ({
            companyId: 'company-1',
            workerId: 'worker-2',
            jobId: 'job-1', // Same job
            status: 'approved',
            clockIn: { toDate: () => new Date('2025-10-11T08:00:00Z') },
            clockOut: { toDate: () => new Date('2025-10-11T12:00:00Z') },
          }),
        },
      ];

      (calculateHours as jest.Mock).mockReturnValue(8.0); // 4 hours per worker

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'],
        dueDate: '2025-11-10',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });

      expect(result.ok).toBe(true);
      expect(result.lineItems).toBe(1); // Single line item for single job
      expect(result.timeEntriesInvoiced).toBe(2);
      // 8 hours * $60/hr = $480
      expect(result.amount).toBe(480.0);
    });

    it('should handle multiple jobs, single worker', async () => {
      (calculateHours as jest.Mock).mockImplementation((entries: any[]) => {
        return entries.length * 3.0; // 3 hours per entry
      });

      const data = {
        companyId: 'company-1',
        customerId: 'customer-1',
        timeEntryIds: ['entry-1', 'entry-2'], // 2 different jobs
        dueDate: '2025-11-10',
      };

      const result = await generateInvoiceHandler({ ...mockRequest, data });

      expect(result.ok).toBe(true);
      expect(result.lineItems).toBe(2); // 2 line items (1 per job)
      expect(result.timeEntriesInvoiced).toBe(2);
      // job-1: 3 hours * $60/hr = $180
      // job-2: 3 hours * $45/hr = $135
      // Total: $315
      expect(result.amount).toBe(315.0);
    });
  });
});
