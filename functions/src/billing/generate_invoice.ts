/**
 * Generate Invoice from Time Entries
 *
 * PURPOSE:
 * Convert approved time entries into invoices with line items.
 * Aggregates hours by job, applies hourly rates, and creates invoice drafts.
 *
 * FEATURES:
 * - Group time entries by job
 * - Calculate total hours per worker per job
 * - Apply hourly rates (from job or company default)
 * - Create invoice line items with descriptions
 * - Support for multiple jobs in single invoice
 * - Idempotency (won't invoice same time entries twice)
 * - Audit trail (track which time entries are invoiced)
 *
 * SECURITY:
 * - Admin/manager only (checked via custom claims)
 * - Company isolation (can only invoice own company's time entries)
 * - Time entries must be approved before invoicing
 * - Once invoiced, time entries are locked (can't be edited)
 *
 * USAGE:
 * POST /generateInvoice
 * {
 *   "companyId": "company-123",
 *   "customerId": "customer-456",
 *   "timeEntryIds": ["entry-1", "entry-2", ...],
 *   "dueDate": "2025-11-10",
 *   "notes": "October 2025 painting services"
 * }
 *
 * RESPONSE:
 * {
 *   "ok": true,
 *   "invoiceId": "invoice-789",
 *   "amount": 1250.00,
 *   "lineItems": 3,
 *   "timeEntriesInvoiced": 15
 * }
 */

import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import { calculateHours, groupEntriesByJob } from './calculate_hours';
import { z } from 'zod';

// Request schema
const GenerateInvoiceRequestSchema = z.object({
  companyId: z.string().min(1),
  customerId: z.string().min(1),
  timeEntryIds: z.array(z.string()).min(1),
  dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/), // YYYY-MM-DD
  notes: z.string().optional(),
  jobId: z.string().optional(), // Optional: single job invoice
});

type GenerateInvoiceRequest = z.infer<typeof GenerateInvoiceRequestSchema>;

// Invoice line item
interface InvoiceLineItem {
  description: string;
  quantity: number; // Hours
  unitPrice: number; // Hourly rate
  discount?: number;
}

// Response type
interface GenerateInvoiceResponse {
  ok: boolean;
  invoiceId?: string;
  amount?: number;
  lineItems?: number;
  timeEntriesInvoiced?: number;
  error?: string;
}

/**
 * Generate invoice handler (exported for testing)
 */
export async function generateInvoiceHandler(
  req: CallableRequest
): Promise<GenerateInvoiceResponse> {
  const db = admin.firestore();
  const auth = req.auth;
  const data = req.data;

    // Authentication check
    if (!auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    // Authorization check (admin or manager only)
    const role = auth.token.role as string | undefined;
    if (role !== 'admin' && role !== 'manager') {
      throw new HttpsError(
        'permission-denied',
        'Only admins and managers can generate invoices'
      );
    }

    // Validate request
    let request: GenerateInvoiceRequest;
    try {
      request = GenerateInvoiceRequestSchema.parse(data);
    } catch (error) {
      throw new HttpsError(
        'invalid-argument',
        `Invalid request: ${error}`
      );
    }

    // Company isolation check
    const userCompanyId = auth.token.company_id as string;
    if (request.companyId !== userCompanyId) {
      throw new HttpsError(
        'permission-denied',
        'Cannot generate invoice for another company'
      );
    }

    try {
      // Fetch time entries
      const timeEntriesSnapshot = await db
        .collection('timeEntries')
        .where(admin.firestore.FieldPath.documentId(), 'in', request.timeEntryIds)
        .get();

      if (timeEntriesSnapshot.empty) {
        throw new HttpsError(
          'not-found',
          'No time entries found'
        );
      }

      // Validate all time entries
      const timeEntries: any[] = [];
      for (const doc of timeEntriesSnapshot.docs) {
        const entry = doc.data();

        // Check company isolation
        if (entry.companyId !== request.companyId) {
          throw new HttpsError(
            'permission-denied',
            `Time entry ${doc.id} belongs to different company`
          );
        }

        // Check if approved
        if (entry.status !== 'approved') {
          throw new HttpsError(
            'failed-precondition',
            `Time entry ${doc.id} is not approved (status: ${entry.status})`
          );
        }

        // Check if already invoiced
        if (entry.invoiceId) {
          throw new HttpsError(
            'failed-precondition',
            `Time entry ${doc.id} is already invoiced (invoice: ${entry.invoiceId})`
          );
        }

        // Check if clocked out
        if (!entry.clockOut) {
          throw new HttpsError(
            'failed-precondition',
            `Time entry ${doc.id} is still active (not clocked out)`
          );
        }

        timeEntries.push({ id: doc.id, ...entry });
      }

      // Group entries by job
      const entriesByJob = groupEntriesByJob(timeEntries);

      // Fetch company for hourly rate
      const companyDoc = await db.collection('companies').doc(request.companyId).get();
      if (!companyDoc.exists) {
        throw new HttpsError('not-found', 'Company not found');
      }
      const companyData = companyDoc.data()!;

      // Fetch jobs for names and hourly rates
      const jobIds = Object.keys(entriesByJob);
      const jobsSnapshot = await db
        .collection('jobs')
        .where(admin.firestore.FieldPath.documentId(), 'in', jobIds)
        .get();

      const jobs: Record<string, any> = {};
      for (const doc of jobsSnapshot.docs) {
        jobs[doc.id] = { id: doc.id, ...doc.data() };
      }

      // Generate line items
      const lineItems: InvoiceLineItem[] = [];
      let totalAmount = 0;

      for (const [jobId, entries] of Object.entries(entriesByJob)) {
        const job = jobs[jobId];
        const jobName = job?.name || `Job ${jobId}`;
        // Proper null coalescing: job.hourlyRate ?? company.defaultHourlyRate ?? 50.0
        const hourlyRate = job?.hourlyRate ?? companyData.defaultHourlyRate ?? 50.0;

        // Calculate total hours for this job
        const totalHours = calculateHours(entries as any[]);

        // Create line item
        const subtotal = totalHours * hourlyRate;
        lineItems.push({
          description: `${jobName} - Labor (${totalHours.toFixed(2)} hours @ $${hourlyRate.toFixed(2)}/hr)`,
          quantity: totalHours,
          unitPrice: hourlyRate,
        });

        totalAmount += subtotal;
      }

      // Create invoice
      const now = admin.firestore.FieldValue.serverTimestamp();
      const dueDate = admin.firestore.Timestamp.fromDate(new Date(request.dueDate));

      const invoiceData = {
        companyId: request.companyId,
        customerId: request.customerId,
        jobId: request.jobId || jobIds[0], // Use first job if multiple
        status: 'pending',
        amount: totalAmount,
        currency: 'USD',
        items: lineItems,
        notes: request.notes || `Invoice for ${lineItems.length} job(s)`,
        dueDate: dueDate,
        createdAt: now,
        updatedAt: now,
      };

      const invoiceRef = await db.collection('invoices').add(invoiceData);
      const invoiceId = invoiceRef.id;

      // Update time entries with invoiceId (mark as invoiced)
      const batch = db.batch();
      for (const entry of timeEntries) {
        const entryRef = db.collection('timeEntries').doc(entry.id);
        batch.update(entryRef, {
          invoiceId: invoiceId,
          updatedAt: now,
        });
      }
      await batch.commit();

      // Return success
      return {
        ok: true,
        invoiceId: invoiceId,
        amount: totalAmount,
        lineItems: lineItems.length,
        timeEntriesInvoiced: timeEntries.length,
      };
    } catch (error: any) {
      logger.error('Error generating invoice:', error);

      // Re-throw HttpsError as-is
      if (error instanceof HttpsError) {
        throw error;
      }

      // Wrap other errors
      throw new HttpsError(
        'internal',
        `Failed to generate invoice: ${error.message}`
      );
    }
}

/**
 * Generate invoice from approved time entries (wrapped for Firebase)
 */
export const generateInvoice = onCall({ region: 'us-east4', enforceAppCheck: true }, generateInvoiceHandler);
