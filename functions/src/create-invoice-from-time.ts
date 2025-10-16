/**
 * Create Invoice From Time - Billing Integration
 *
 * PURPOSE:
 * Converts approved time entries into an invoice with automated line items.
 * Streamlines the time → billing workflow for MVP.
 *
 * WORKFLOW:
 * 1. Validate all entries are approved and not already invoiced
 * 2. Aggregate total hours across all entries
 * 3. Create invoice with line item: "Labor - {hours}h @ ${rate}/hr"
 * 4. Atomically lock all time entries by setting invoiceId (batch write)
 * 5. Create audit record for the operation
 *
 * ACCEPTANCE GATES:
 * - Process 100 entries in ≤5s
 * - Atomic operation (all or nothing)
 * - Prevents double-invoicing via invoiceId check
 *
 * SECURITY:
 * - Requires admin or manager role
 * - Company isolation enforced
 * - Audit trail for all operations
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v2/https";

/**
 * Create Invoice From Time Callable Function
 *
 * @param companyId - Company ID
 * @param jobId - Job ID (for grouping/reference)
 * @param timeEntryIds - Array of time entry IDs to invoice
 * @param hourlyRate - Billing rate per hour
 * @param customerId - Customer to bill
 * @param dueDate - Invoice due date
 * @param notes - Optional invoice notes
 */
export const createInvoiceFromTime = functions.onCall({ region: 'us-east4' }, async (req) => {
  const {
    companyId,
    jobId,
    timeEntryIds,
    hourlyRate,
    customerId,
    dueDate,
    notes,
  } = req.data || {};

  const uid = req.auth?.uid;
  const role = req.auth?.token?.role;
  const userCompanyId = req.auth?.token?.company_id;

  // 1) Authentication & Authorization
  if (!uid) {
    throw new functions.HttpsError("unauthenticated", "Sign in required");
  }

  if (!role || !["admin", "manager"].includes(role)) {
    throw new functions.HttpsError(
      "permission-denied",
      "Only admin or manager can create invoices"
    );
  }

  if (!userCompanyId || userCompanyId !== companyId) {
    throw new functions.HttpsError("permission-denied", "Company mismatch");
  }

  // 2) Validate parameters
  if (!companyId || !jobId || !timeEntryIds || !hourlyRate || !customerId || !dueDate) {
    throw new functions.HttpsError(
      "invalid-argument",
      "Missing required parameters: companyId, jobId, timeEntryIds, hourlyRate, customerId, dueDate"
    );
  }

  if (!Array.isArray(timeEntryIds) || timeEntryIds.length === 0) {
    throw new functions.HttpsError(
      "invalid-argument",
      "timeEntryIds must be a non-empty array"
    );
  }

  if (timeEntryIds.length > 100) {
    throw new functions.HttpsError(
      "invalid-argument",
      "Cannot invoice more than 100 entries at once"
    );
  }

  if (typeof hourlyRate !== "number" || hourlyRate <= 0) {
    throw new functions.HttpsError(
      "invalid-argument",
      "hourlyRate must be a positive number"
    );
  }

  const dueDateObj = new Date(dueDate);
  if (isNaN(dueDateObj.getTime())) {
    throw new functions.HttpsError("invalid-argument", "Invalid dueDate");
  }

  const db = admin.firestore();

  // 3) Fetch and validate all time entries
  const entries: Array<{id: string; data: admin.firestore.DocumentData}> = [];
  let totalHours = 0;

  for (const entryId of timeEntryIds) {
    const entrySnap = await db.doc(`timeEntries/${entryId}`).get();

    if (!entrySnap.exists) {
      throw new functions.HttpsError("not-found", `Time entry not found: ${entryId}`);
    }

    const entry = entrySnap.data()!;

    // Validate company isolation
    if (entry.companyId !== companyId) {
      throw new functions.HttpsError(
        "permission-denied",
        `Entry ${entryId} belongs to different company`
      );
    }

    // Validate entry is approved
    if (!entry.approved) {
      throw new functions.HttpsError(
        "failed-precondition",
        `Entry ${entryId} is not approved. All entries must be approved before invoicing.`
      );
    }

    // Validate entry is not already invoiced
    if (entry.invoiceId) {
      throw new functions.HttpsError(
        "failed-precondition",
        `Entry ${entryId} is already invoiced (invoice: ${entry.invoiceId})`
      );
    }

    // Validate entry is closed (has clockOutAt)
    if (!entry.clockOutAt) {
      throw new functions.HttpsError(
        "failed-precondition",
        `Entry ${entryId} is still active (not clocked out)`
      );
    }

    // Calculate duration
    const clockIn = entry.clockInAt.toDate();
    const clockOut = entry.clockOutAt.toDate();
    const durationMs = clockOut.getTime() - clockIn.getTime();
    const durationHours = durationMs / (1000 * 60 * 60);

    entries.push({id: entryId, data: entry});
    totalHours += durationHours;
  }

  // 4) Create invoice document
  const invoiceRef = db.collection("invoices").doc();
  const invoiceId = invoiceRef.id;

  const totalAmount = totalHours * hourlyRate;

  const invoice = {
    companyId,
    customerId,
    jobId, // Reference to job
    status: "pending",
    amount: totalAmount,
    currency: "USD",
    items: [
      {
        description: `Labor - ${jobId}`, // TODO: resolve job name
        quantity: totalHours,
        unitPrice: hourlyRate,
        discount: 0,
      },
    ],
    timeEntryIds, // Reference to source time entries
    dueDate: admin.firestore.Timestamp.fromDate(dueDateObj),
    notes: notes || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: uid,
  };

  // 5) Atomic batch: create invoice + lock all time entries
  const batch = db.batch();

  // Create invoice
  batch.set(invoiceRef, invoice);

  // Lock all time entries
  for (const entry of entries) {
    const entryRef = db.doc(`timeEntries/${entry.id}`);
    batch.update(entryRef, {
      invoiceId,
      invoicedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Create audit record
  const auditRef = db.collection("audits").doc();
  batch.set(auditRef, {
    type: "invoice_from_time",
    companyId,
    invoiceId,
    timeEntryIds,
    totalHours,
    totalAmount,
    createdBy: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Commit batch
  await batch.commit();

  return {
    ok: true,
    invoiceId,
    totalHours,
    totalAmount,
    entriesLocked: entries.length,
  };
});
