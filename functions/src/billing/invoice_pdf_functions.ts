/**
 * Invoice PDF Cloud Functions
 *
 * PURPOSE:
 * Cloud Functions for automatic PDF generation and signed URL retrieval.
 *
 * FEATURES:
 * 1. onInvoiceCreated: Firestore trigger that auto-generates PDF when invoice is created
 * 2. getInvoicePDFUrl: Callable function to get signed URL for existing PDF
 *
 * WORKFLOW:
 * 1. Admin creates invoice via generateInvoice
 * 2. onInvoiceCreated triggers automatically
 * 3. PDF is generated and uploaded to Cloud Storage
 * 4. Invoice document is updated with pdfPath and pdfGeneratedAt
 * 5. Client calls getInvoicePDFUrl to get signed URL (7-day expiry)
 * 6. Client displays/downloads PDF
 */

import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import { generateInvoicePDF, getInvoicePDFPath, InvoiceData } from './generate_invoice_pdf';

/**
 * Firestore trigger: Generate PDF when invoice is created
 *
 * Triggered on: /invoices/{invoiceId} onCreate
 * Action: Generate PDF, upload to Cloud Storage, update invoice document
 */
export const onInvoiceCreated = onDocumentCreated('invoices/{invoiceId}', async (event) => {
    const invoiceId = event.params.invoiceId;
    const snapshot = event.data;
    if (!snapshot) {
      logger.error('No snapshot data in onInvoiceCreated');
      return;
    }
    const invoiceData = snapshot.data() as InvoiceData;

    try {
      logger.info(`Generating PDF for invoice ${invoiceId}`);

      // Fetch company data
      const companyDoc = await admin.firestore().collection('companies').doc(invoiceData.companyId).get();

      if (!companyDoc.exists) {
        logger.error(`Company ${invoiceData.companyId} not found for invoice ${invoiceId}`);
        return;
      }

      const companyData = { id: companyDoc.id, ...companyDoc.data() } as any;

      // Fetch customer data
      const customerDoc = await admin.firestore().collection('customers').doc(invoiceData.customerId).get();

      if (!customerDoc.exists) {
        logger.error(`Customer ${invoiceData.customerId} not found for invoice ${invoiceId}`);
        return;
      }

      const customerData = { id: customerDoc.id, ...customerDoc.data() } as any;

      // Generate PDF
      const pdfBuffer = await generateInvoicePDF(
        { ...invoiceData, id: invoiceId } as InvoiceData,
        companyData,
        customerData
      );

      // Upload to Cloud Storage
      const bucket = admin.storage().bucket();
      const pdfPath = getInvoicePDFPath(invoiceId, invoiceData.companyId);
      const file = bucket.file(pdfPath);

      await file.save(pdfBuffer, {
        contentType: 'application/pdf',
        metadata: {
          metadata: {
            invoiceId: invoiceId,
            companyId: invoiceData.companyId,
            customerId: invoiceData.customerId,
            generatedAt: new Date().toISOString(),
          },
        },
      });

      logger.info(`PDF uploaded to ${pdfPath}`);

      // Update invoice document with PDF path
      await snapshot.ref.update({
        pdfPath: pdfPath,
        pdfGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`Invoice ${invoiceId} updated with PDF path`);
    } catch (error: any) {
      logger.error(`Error generating PDF for invoice ${invoiceId}:`, error);

      // Update invoice with error status
      await snapshot.ref.update({
        pdfError: error.message || 'Unknown error',
        pdfErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
});

/**
 * Callable function: Get signed URL for invoice PDF
 *
 * Request:
 * {
 *   invoiceId: string;
 *   expiresIn?: number;  // Optional: expiry in seconds (default: 7 days)
 * }
 *
 * Response:
 * {
 *   ok: boolean;
 *   url?: string;        // Signed URL (expires in 7 days)
 *   expiresAt?: string;  // ISO timestamp
 *   error?: string;
 * }
 */
/**
 * Get invoice PDF URL handler (exported for testing)
 */
export async function getInvoicePDFUrlHandler(
  req: CallableRequest
): Promise<{ ok: boolean; url?: string; expiresAt?: string; error?: string }> {
  const db = admin.firestore();
  const auth = req.auth;
  const data = req.data as { invoiceId: string; expiresIn?: number };

    // Authentication check
    if (!auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Validate request
    if (!data.invoiceId) {
      throw new HttpsError('invalid-argument', 'invoiceId is required');
    }

    try {
      // Fetch invoice
      const invoiceDoc = await db.collection('invoices').doc(data.invoiceId).get();

      if (!invoiceDoc.exists) {
        throw new HttpsError('not-found', 'Invoice not found');
      }

      const invoice = invoiceDoc.data() as InvoiceData;

      // Company isolation check
      const userCompanyId = auth.token.company_id as string;
      if (invoice.companyId !== userCompanyId) {
        throw new HttpsError('permission-denied', 'Cannot access invoice from another company');
      }

      // Check if PDF exists
      if (!invoice.pdfPath) {
        throw new HttpsError(
          'failed-precondition',
          'PDF not yet generated. Please try again in a few seconds.'
        );
      }

      // Generate signed URL (default: 7 days)
      const expiresIn = data.expiresIn || 7 * 24 * 60 * 60; // 7 days in seconds
      const expiresAt = new Date(Date.now() + expiresIn * 1000);

      const bucket = admin.storage().bucket();
      const file = bucket.file(invoice.pdfPath);

      const [url] = await file.getSignedUrl({
        action: 'read',
        expires: expiresAt,
      });

      return {
        ok: true,
        url: url,
        expiresAt: expiresAt.toISOString(),
      };
    } catch (error: any) {
      logger.error(`Error getting PDF URL for invoice ${data.invoiceId}:`, error);

      // Re-throw HttpsError as-is
      if (error instanceof HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new HttpsError('internal', `Failed to get PDF URL: ${error.message}`);
    }
}

/**
 * Get invoice PDF URL callable (wrapped for Firebase)
 */
export const getInvoicePDFUrl = onCall({ region: 'us-east4' }, getInvoicePDFUrlHandler);

/**
 * Callable function: Regenerate PDF for existing invoice
 *
 * Useful if PDF generation failed initially or invoice was updated.
 *
 * Request:
 * {
 *   invoiceId: string;
 * }
 *
 * Response:
 * {
 *   ok: boolean;
 *   pdfPath?: string;
 *   error?: string;
 * }
 */
/**
 * Regenerate invoice PDF handler (exported for testing)
 */
export async function regenerateInvoicePDFHandler(req: CallableRequest) {
  const db = admin.firestore();
  const auth = req.auth;
  const data = req.data as { invoiceId: string };

    // Authentication check
    if (!auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Authorization check (admin or manager only)
    const role = auth.token.role as string | undefined;
    if (role !== 'admin' && role !== 'manager') {
      throw new HttpsError('permission-denied', 'Only admins and managers can regenerate PDFs');
    }

    // Validate request
    if (!data.invoiceId) {
      throw new HttpsError('invalid-argument', 'invoiceId is required');
    }

    try {
      // Fetch invoice
      const invoiceDoc = await db.collection('invoices').doc(data.invoiceId).get();

      if (!invoiceDoc.exists) {
        throw new HttpsError('not-found', 'Invoice not found');
      }

      const invoiceData = invoiceDoc.data() as InvoiceData;

      // Company isolation check
      const userCompanyId = auth.token.company_id as string;
      if (invoiceData.companyId !== userCompanyId) {
        throw new HttpsError('permission-denied', 'Cannot regenerate PDF for another company');
      }

      // Fetch company data
      const companyDoc = await db.collection('companies').doc(invoiceData.companyId).get();
      if (!companyDoc.exists) {
        throw new HttpsError('not-found', 'Company not found');
      }
      const companyData = { id: companyDoc.id, ...companyDoc.data() } as any;

      // Fetch customer data
      const customerDoc = await db.collection('customers').doc(invoiceData.customerId).get();
      if (!customerDoc.exists) {
        throw new HttpsError('not-found', 'Customer not found');
      }
      const customerData = { id: customerDoc.id, ...customerDoc.data() } as any;

      // Generate PDF
      const pdfBuffer = await generateInvoicePDF(
        { ...invoiceData, id: data.invoiceId } as InvoiceData,
        companyData,
        customerData
      );

      // Upload to Cloud Storage (overwrite existing)
      const bucket = admin.storage().bucket();
      const pdfPath = getInvoicePDFPath(data.invoiceId, invoiceData.companyId);
      const file = bucket.file(pdfPath);

      await file.save(pdfBuffer, {
        contentType: 'application/pdf',
        metadata: {
          metadata: {
            invoiceId: data.invoiceId,
            companyId: invoiceData.companyId,
            customerId: invoiceData.customerId,
            regeneratedAt: new Date().toISOString(),
            regeneratedBy: auth.uid,
          },
        },
      });

      // Update invoice document
      await invoiceDoc.ref.update({
        pdfPath: pdfPath,
        pdfGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        pdfError: admin.firestore.FieldValue.delete(), // Clear any previous error
        pdfErrorAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        ok: true,
        pdfPath: pdfPath,
      };
    } catch (error: any) {
      logger.error(`Error regenerating PDF for invoice ${data.invoiceId}:`, error);

      // Re-throw HttpsError as-is
      if (error instanceof HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new HttpsError('internal', `Failed to regenerate PDF: ${error.message}`);
    }
}

/**
 * Regenerate invoice PDF callable (wrapped for Firebase)
 */
export const regenerateInvoicePDF = onCall({ region: 'us-east4' }, regenerateInvoicePDFHandler);
