/**
 * Tests for invoice_pdf_functions.ts
 *
 * Test Coverage:
 * - onInvoiceCreated: Firestore trigger for automatic PDF generation
 * - getInvoicePDFUrl: Get signed URL for invoice PDF
 * - regenerateInvoicePDF: Manually regenerate PDF
 * - Error handling: Missing data, permission denied, PDF generation failures
 */

import * as admin from 'firebase-admin';
import { CallableRequest, HttpsError } from 'firebase-functions/v2/https';

// Mock Firebase Admin before importing
jest.mock('firebase-admin', () => {
  const mockFile = {
    save: jest.fn().mockResolvedValue(undefined),
    getSignedUrl: jest.fn().mockResolvedValue(['https://storage.googleapis.com/signed-url']),
  };

  const mockBucket = {
    file: jest.fn(() => mockFile),
  };

  const mockStorage = {
    bucket: jest.fn(() => mockBucket),
  };

  const mockDocRef = {
    update: jest.fn().mockResolvedValue(undefined),
  };

  const mockFirestore = {
    collection: jest.fn(),
  };

  // Setup firestore function with static properties
  const firestoreFunction: any = jest.fn(() => mockFirestore);
  firestoreFunction.FieldValue = {
    serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP'),
    delete: jest.fn(() => 'DELETE_FIELD'),
  };
  firestoreFunction.Timestamp = {
    fromDate: jest.fn((date: Date) => ({ toDate: () => date })),
  };

  // Setup storage function
  const storageFunction: any = jest.fn(() => mockStorage);

  return {
    firestore: firestoreFunction,
    storage: storageFunction,
  };
});

// Mock PDF generation
jest.mock('../generate_invoice_pdf', () => ({
  generateInvoicePDF: jest.fn().mockResolvedValue(Buffer.from('mock-pdf-content')),
  getInvoicePDFPath: jest.fn((invoiceId: string, companyId: string) => `invoices/${companyId}/${invoiceId}.pdf`),
}));

// Import after mocking
import { getInvoicePDFUrlHandler, regenerateInvoicePDFHandler } from '../invoice_pdf_functions';
import { generateInvoicePDF, getInvoicePDFPath } from '../generate_invoice_pdf';

describe('getInvoicePDFUrl', () => {
  let mockDb: any;
  let mockStorage: any;
  let mockRequest: any;
  let mockInvoiceDoc: any;

  beforeEach(() => {
    jest.clearAllMocks();

    mockDb = admin.firestore();
    mockStorage = admin.storage();

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

    // Mock invoice document
    mockInvoiceDoc = {
      exists: true,
      data: () => ({
        companyId: 'company-1',
        customerId: 'customer-1',
        pdfPath: 'invoices/company-1/invoice-123.pdf',
        amount: 1250.0,
      }),
    };

    // Setup Firestore mock
    const mockCollectionRef = {
      doc: jest.fn((docId: string) => ({
        get: jest.fn().mockResolvedValue(mockInvoiceDoc),
      })),
    };

    mockDb.collection.mockImplementation(() => mockCollectionRef);
  });

  describe('Authentication', () => {
    it('should reject unauthenticated requests', async () => {
      mockRequest.auth = undefined;

      const data = { invoiceId: 'invoice-123' };

      await expect(getInvoicePDFUrlHandler({ ...mockRequest, data })).rejects.toThrow('User must be authenticated');
    });
  });

  describe('Validation', () => {
    it('should reject requests without invoiceId', async () => {
      const data = { invoiceId: '' };

      await expect(getInvoicePDFUrlHandler({ ...mockRequest, data })).rejects.toThrow('invoiceId is required');
    });

    it('should reject requests with missing invoiceId', async () => {
      const data = {} as any;

      await expect(getInvoicePDFUrlHandler({ ...mockRequest, data })).rejects.toThrow('invoiceId is required');
    });
  });

  describe('Company Isolation', () => {
    it('should reject access to invoice from another company', async () => {
      mockRequest.auth!.token.company_id = 'company-2'; // Different company

      const data = { invoiceId: 'invoice-123' };

      await expect(getInvoicePDFUrlHandler({ ...mockRequest, data })).rejects.toThrow('Cannot access invoice from another company');
    });
  });

  describe('Invoice Lookup', () => {
    it('should reject if invoice not found', async () => {
      mockInvoiceDoc.exists = false;

      const data = { invoiceId: 'invoice-999' };

      await expect(getInvoicePDFUrlHandler({ ...mockRequest, data })).rejects.toThrow('Invoice not found');
    });

    it('should reject if PDF not yet generated', async () => {
      mockInvoiceDoc.data = () => ({
        companyId: 'company-1',
        customerId: 'customer-1',
        // No pdfPath
      });

      const data = { invoiceId: 'invoice-123' };

      await expect(getInvoicePDFUrlHandler({ ...mockRequest, data })).rejects.toThrow('PDF not yet generated');
    });
  });

  describe('Signed URL Generation', () => {
    it('should generate signed URL with default expiry (7 days)', async () => {
      const data = { invoiceId: 'invoice-123' };

      const result = await getInvoicePDFUrlHandler({ ...mockRequest, data });

      expect(result.ok).toBe(true);
      expect(result.url).toBe('https://storage.googleapis.com/signed-url');
      expect(result.expiresAt).toBeDefined();

      // Check expiry is approximately 7 days from now
      const expiresAt = new Date(result.expiresAt!);
      const now = new Date();
      const daysDiff = (expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);
      expect(daysDiff).toBeGreaterThan(6.9);
      expect(daysDiff).toBeLessThan(7.1);
    });

    it('should generate signed URL with custom expiry', async () => {
      const data = {
        invoiceId: 'invoice-123',
        expiresIn: 3600, // 1 hour
      };

      const result = await getInvoicePDFUrlHandler({ ...mockRequest, data });

      expect(result.ok).toBe(true);
      expect(result.url).toBeDefined();

      // Check expiry is approximately 1 hour from now
      const expiresAt = new Date(result.expiresAt!);
      const now = new Date();
      const hoursDiff = (expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60);
      expect(hoursDiff).toBeGreaterThan(0.9);
      expect(hoursDiff).toBeLessThan(1.1);
    });

    it('should call getSignedUrl with correct parameters', async () => {
      const mockFile = mockStorage.bucket().file();

      const data = { invoiceId: 'invoice-123' };

      await getInvoicePDFUrlHandler({ ...mockRequest, data });

      expect(mockFile.getSignedUrl).toHaveBeenCalledWith({
        action: 'read',
        expires: expect.any(Date),
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle Storage errors', async () => {
      const mockFile = mockStorage.bucket().file();
      mockFile.getSignedUrl.mockRejectedValue(new Error('Storage unavailable'));

      const data = { invoiceId: 'invoice-123' };

      await expect(getInvoicePDFUrlHandler({ ...mockRequest, data })).rejects.toThrow('Failed to get PDF URL');
    });
  });
});

describe('regenerateInvoicePDF', () => {
  let mockDb: any;
  let mockStorage: any;
  let mockRequest: any;
  let mockInvoiceDoc: any;
  let mockCompanyDoc: any;
  let mockCustomerDoc: any;

  beforeEach(() => {
    jest.clearAllMocks();

    mockDb = admin.firestore();
    mockStorage = admin.storage();

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

    // Mock documents
    mockInvoiceDoc = {
      exists: true,
      ref: {
        update: jest.fn().mockResolvedValue(undefined),
      },
      data: () => ({
        companyId: 'company-1',
        customerId: 'customer-1',
        jobId: 'job-1',
        status: 'pending',
        amount: 1250.0,
        currency: 'USD',
        items: [
          { description: 'Test Item', quantity: 1, unitPrice: 1250.0 },
        ],
        dueDate: { toDate: () => new Date('2025-11-10') },
        createdAt: { toDate: () => new Date('2025-10-11') },
      }),
    };

    mockCompanyDoc = {
      exists: true,
      data: () => ({ name: "D'Sierra Painting", email: 'billing@dsierra.com' }),
    };

    mockCustomerDoc = {
      exists: true,
      data: () => ({ name: 'John Smith', email: 'john@example.com' }),
    };

    // Setup Firestore mock
    const mockCollectionRef = {
      doc: jest.fn((docId: string) => {
        if (docId.startsWith('company-')) {
          return { get: jest.fn().mockResolvedValue(mockCompanyDoc) };
        } else if (docId.startsWith('customer-')) {
          return { get: jest.fn().mockResolvedValue(mockCustomerDoc) };
        } else {
          return {
            get: jest.fn().mockResolvedValue(mockInvoiceDoc),
            ref: mockInvoiceDoc.ref,
          };
        }
      }),
    };

    mockDb.collection.mockImplementation(() => mockCollectionRef);
  });

  describe('Authentication', () => {
    it('should reject unauthenticated requests', async () => {
      mockRequest.auth = undefined;

      const data = { invoiceId: 'invoice-123' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('User must be authenticated');
    });
  });

  describe('Authorization', () => {
    it('should allow admin role', async () => {
      mockRequest.auth!.token.role = 'admin';

      const data = { invoiceId: 'invoice-123' };

      const result = await regenerateInvoicePDFHandler({ ...mockRequest, data });
      expect(result.ok).toBe(true);
    });

    it('should allow manager role', async () => {
      mockRequest.auth!.token.role = 'manager';

      const data = { invoiceId: 'invoice-123' };

      const result = await regenerateInvoicePDFHandler({ ...mockRequest, data });
      expect(result.ok).toBe(true);
    });

    it('should reject worker role', async () => {
      mockRequest.auth!.token.role = 'worker';

      const data = { invoiceId: 'invoice-123' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('Only admins and managers can regenerate PDFs');
    });
  });

  describe('Company Isolation', () => {
    it('should reject regenerating PDF for another company', async () => {
      mockRequest.auth!.token.company_id = 'company-2'; // Different company

      const data = { invoiceId: 'invoice-123' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('Cannot regenerate PDF for another company');
    });
  });

  describe('Validation', () => {
    it('should reject requests without invoiceId', async () => {
      const data = { invoiceId: '' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('invoiceId is required');
    });

    it('should reject if invoice not found', async () => {
      mockInvoiceDoc.exists = false;

      const data = { invoiceId: 'invoice-999' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('Invoice not found');
    });

    it('should reject if company not found', async () => {
      mockCompanyDoc.exists = false;

      const data = { invoiceId: 'invoice-123' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('Company not found');
    });

    it('should reject if customer not found', async () => {
      mockCustomerDoc.exists = false;

      const data = { invoiceId: 'invoice-123' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('Customer not found');
    });
  });

  describe('PDF Generation', () => {
    it('should generate PDF and upload to Storage', async () => {
      const data = { invoiceId: 'invoice-123' };

      const result = await regenerateInvoicePDFHandler({ ...mockRequest, data });

      expect(result.ok).toBe(true);
      expect(result.pdfPath).toBe('invoices/company-1/invoice-123.pdf');

      // Check PDF was generated
      expect(generateInvoicePDF).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'invoice-123',
          companyId: 'company-1',
        }),
        expect.objectContaining({ name: "D'Sierra Painting" }),
        expect.objectContaining({ name: 'John Smith' })
      );

      // Check file was saved
      const mockFile = mockStorage.bucket().file();
      expect(mockFile.save).toHaveBeenCalledWith(
        Buffer.from('mock-pdf-content'),
        expect.objectContaining({
          contentType: 'application/pdf',
        })
      );

      // Check invoice was updated
      expect(mockInvoiceDoc.ref.update).toHaveBeenCalledWith(
        expect.objectContaining({
          pdfPath: 'invoices/company-1/invoice-123.pdf',
          pdfGeneratedAt: 'SERVER_TIMESTAMP',
          updatedAt: 'SERVER_TIMESTAMP',
        })
      );
    });

    it('should include regeneration metadata', async () => {
      const data = { invoiceId: 'invoice-123' };

      await regenerateInvoicePDFHandler({ ...mockRequest, data });

      const mockFile = mockStorage.bucket().file();
      expect(mockFile.save).toHaveBeenCalledWith(
        expect.any(Buffer),
        expect.objectContaining({
          metadata: {
            metadata: expect.objectContaining({
              regeneratedBy: 'user-123',
              regeneratedAt: expect.any(String),
            }),
          },
        })
      );
    });

    it('should clear previous PDF errors', async () => {
      const data = { invoiceId: 'invoice-123' };

      await regenerateInvoicePDFHandler({ ...mockRequest, data });

      expect(mockInvoiceDoc.ref.update).toHaveBeenCalledWith(
        expect.objectContaining({
          pdfError: 'DELETE_FIELD',
          pdfErrorAt: 'DELETE_FIELD',
        })
      );
    });
  });

  describe('Error Handling', () => {
    it('should handle PDF generation errors', async () => {
      (generateInvoicePDF as jest.Mock).mockRejectedValue(new Error('PDF generation failed'));

      const data = { invoiceId: 'invoice-123' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('Failed to regenerate PDF');
    });

    it('should handle Storage upload errors', async () => {
      const mockFile = mockStorage.bucket().file();
      mockFile.save.mockRejectedValue(new Error('Storage unavailable'));

      const data = { invoiceId: 'invoice-123' };

      await expect(regenerateInvoicePDFHandler({ ...mockRequest, data })).rejects.toThrow('Failed to regenerate PDF');
    });
  });
});
