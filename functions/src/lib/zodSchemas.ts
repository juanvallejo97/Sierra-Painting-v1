/**
 * Zod Schema Definitions for Sierra Painting
 * 
 * PURPOSE:
 * Centralized validation schemas for all Cloud Function inputs and outputs.
 * Ensures type safety and runtime validation of data crossing the client-server boundary.
 * 
 * RESPONSIBILITIES:
 * - Define input/output schemas for all callable functions
 * - Define document schemas for Firestore writes
 * - Provide type inference for TypeScript
 * - Runtime validation with descriptive error messages
 * 
 * PUBLIC API:
 * - LeadSchema: Validate lead form submissions
 * - EstimateSchema: Validate estimate documents
 * - InvoiceSchema: Validate invoice documents
 * - ManualPaymentSchema: Validate manual payment requests
 * - CheckoutSessionSchema: Validate Stripe checkout requests (optional)
 * - TimeEntrySchema: Validate timeclock entries
 * - LineItemSchema: Validate estimate/invoice line items
 * 
 * SECURITY CONSIDERATIONS:
 * - All schemas use .strict() to reject unknown fields
 * - String inputs are .trim() to prevent whitespace exploits
 * - Amounts are validated as positive numbers
 * - Email addresses are validated with regex
 * - Phone numbers are validated with regex
 * - Enums restrict values to known constants
 * 
 * PERFORMANCE NOTES:
 * - Zod parsing is fast (~1-2ms per validation)
 * - Use .optional() sparingly to keep schemas strict
 * - Prefer .transform() over manual post-processing
 * 
 * INVARIANTS:
 * - All monetary amounts in cents (not dollars)
 * - All timestamps as ISO 8601 strings or Firestore Timestamps
 * - All IDs are non-empty strings
 * 
 * USAGE EXAMPLE:
 * ```typescript
 * const validatedData = LeadSchema.parse(data);
 * // or with error handling:
 * const result = LeadSchema.safeParse(data);
 * if (!result.success) {
 *   throw new functions.https.HttpsError('invalid-argument', result.error.message);
 * }
 * ```
 * 
 * TODO:
 * - Add schema versioning for API evolution
 * - Consider using .brand() for opaque types (e.g., InvoiceId, UserId)
 * - Add schema documentation generation (zod-to-json-schema)
 */

import {z} from 'zod';

// ============================================================
// SHARED / PRIMITIVE SCHEMAS
// ============================================================

/**
 * Non-empty string (trimmed)
 */
const NonEmptyString = z.string().trim().min(1);

/**
 * Email validation
 */
const Email = z.string().trim().email();

/**
 * Phone number (US format: XXX-XXX-XXXX or XXXXXXXXXX)
 */
const PhoneNumber = z.string().trim().regex(/^\d{10}$|^\d{3}-\d{3}-\d{4}$/);

/**
 * Positive integer (for amounts in cents)
 */
const PositiveAmount = z.number().int().positive();

/**
 * ISO 8601 date string
 */
const ISODateString = z.string().datetime();

/**
 * Organization ID (non-empty string)
 */
const OrgId = NonEmptyString;

/**
 * User ID (non-empty string, typically Firebase UID)
 */
const UserId = NonEmptyString;

// ============================================================
// LEAD SCHEMA (createLead function)
// ============================================================

export const LeadSchema = z.object({
  name: NonEmptyString,
  email: Email,
  phone: PhoneNumber,
  address: NonEmptyString,
  message: z.string().trim().max(2000),
  captchaToken: NonEmptyString, // reCAPTCHA or hCaptcha token
  source: z.enum(['website', 'referral', 'social_media']).optional(),
}).strict();

export type Lead = z.infer<typeof LeadSchema>;

// ============================================================
// LINE ITEM SCHEMA (used in Estimates and Invoices)
// ============================================================

export const LineItemSchema = z.object({
  id: NonEmptyString,
  description: NonEmptyString.max(500),
  quantity: z.number().positive(),
  unitPrice: PositiveAmount, // in cents
  totalPrice: PositiveAmount, // in cents (quantity * unitPrice)
  category: z.enum(['labor', 'materials', 'equipment', 'other']).optional(),
}).strict();

export type LineItem = z.infer<typeof LineItemSchema>;

// ============================================================
// ESTIMATE SCHEMA (createEstimatePdf function)
// ============================================================

export const EstimateSchema = z.object({
  id: NonEmptyString,
  orgId: OrgId,
  customerId: UserId,
  customerName: NonEmptyString,
  customerEmail: Email,
  customerPhone: PhoneNumber.optional(),
  customerAddress: NonEmptyString,
  lineItems: z.array(LineItemSchema).min(1),
  subtotal: PositiveAmount, // in cents
  tax: z.number().nonnegative(), // in cents
  total: PositiveAmount, // in cents
  notes: z.string().trim().max(2000).optional(),
  validUntil: ISODateString.optional(),
  createdAt: ISODateString,
}).strict();

export type Estimate = z.infer<typeof EstimateSchema>;

// ============================================================
// INVOICE SCHEMA (used in markPaidManual, createCheckoutSession)
// ============================================================

export const InvoiceSchema = z.object({
  id: NonEmptyString,
  orgId: OrgId,
  customerId: UserId,
  customerName: NonEmptyString,
  customerEmail: Email,
  estimateId: NonEmptyString.optional(),
  lineItems: z.array(LineItemSchema).min(1),
  subtotal: PositiveAmount, // in cents
  tax: z.number().nonnegative(), // in cents
  total: PositiveAmount, // in cents
  status: z.enum(['draft', 'sent', 'paid', 'cancelled']),
  // IMPORTANT: 'paid' and 'paidAt' can only be set server-side
  paid: z.boolean().optional(),
  paidAt: ISODateString.optional(),
  dueDate: ISODateString.optional(),
  notes: z.string().trim().max(2000).optional(),
  createdAt: ISODateString,
  updatedAt: ISODateString,
}).strict();

export type Invoice = z.infer<typeof InvoiceSchema>;

// ============================================================
// MANUAL PAYMENT SCHEMA (markPaidManual function)
// ============================================================

export const ManualPaymentSchema = z.object({
  invoiceId: NonEmptyString,
  amount: PositiveAmount, // in cents
  paymentMethod: z.enum(['check', 'cash']),
  checkNumber: z.string().trim().optional(), // required if paymentMethod === 'check'
  notes: z.string().trim().max(500).optional(),
  idempotencyKey: z.string().trim().optional(), // client-provided for idempotent retries
}).strict().refine(
  (data) => {
    // If payment method is 'check', checkNumber is required
    if (data.paymentMethod === 'check' && !data.checkNumber) {
      return false;
    }
    return true;
  },
  {
    message: 'checkNumber is required when paymentMethod is "check"',
    path: ['checkNumber'],
  }
);

export type ManualPayment = z.infer<typeof ManualPaymentSchema>;

// ============================================================
// STRIPE CHECKOUT SESSION SCHEMA (createCheckoutSession function - OPTIONAL)
// ============================================================

export const CheckoutSessionSchema = z.object({
  invoiceId: NonEmptyString,
  successUrl: z.string().url(),
  cancelUrl: z.string().url(),
}).strict();

export type CheckoutSession = z.infer<typeof CheckoutSessionSchema>;

// ============================================================
// TIME ENTRY SCHEMA (timeclock functions)
// ============================================================

export const TimeEntrySchema = z.object({
  id: NonEmptyString,
  orgId: OrgId,
  userId: UserId,
  jobId: NonEmptyString,
  clockIn: ISODateString,
  clockOut: ISODateString.optional(),
  breakMinutes: z.number().nonnegative().default(0),
  notes: z.string().trim().max(500).optional(),
  idempotencyKey: z.string().trim().optional(), // for offline queue deduplication
}).strict().refine(
  (data) => {
    // If clockOut is set, it must be after clockIn
    if (data.clockOut && new Date(data.clockOut) <= new Date(data.clockIn)) {
      return false;
    }
    return true;
  },
  {
    message: 'clockOut must be after clockIn',
    path: ['clockOut'],
  }
);

export type TimeEntry = z.infer<typeof TimeEntrySchema>;

// ============================================================
// AUDIT LOG ENTRY SCHEMA (internal use)
// ============================================================

export const AuditLogEntrySchema = z.object({
  entity: z.enum(['invoice', 'payment', 'estimate', 'user', 'job', 'timeEntry', 'lead']),
  entityId: NonEmptyString,
  action: z.enum(['created', 'updated', 'deleted', 'paid', 'sent', 'approved']),
  actor: UserId,
  actorRole: z.enum(['admin', 'crew_lead', 'crew', 'customer']).optional(),
  orgId: OrgId,
  timestamp: ISODateString,
  ipAddress: z.string().trim().optional(),
  userAgent: z.string().trim().optional(),
  changes: z.record(z.string(), z.unknown()).optional(), // Old/new values for updates
  metadata: z.record(z.string(), z.unknown()).optional(), // Additional context
}).strict();

export type AuditLogEntry = z.infer<typeof AuditLogEntrySchema>;

// ============================================================
// USER SCHEMA (for user documents in Firestore)
// ============================================================

export const UserSchema = z.object({
  uid: UserId,
  email: Email,
  displayName: z.string().trim().optional(),
  photoURL: z.string().url().optional(),
  role: z.enum(['admin', 'crew_lead', 'crew', 'customer']),
  orgId: OrgId,
  createdAt: ISODateString,
  updatedAt: ISODateString,
}).strict();

export type User = z.infer<typeof UserSchema>;

// ============================================================
// EXPORTS
// ============================================================

export default {
  LeadSchema,
  EstimateSchema,
  InvoiceSchema,
  ManualPaymentSchema,
  CheckoutSessionSchema,
  TimeEntrySchema,
  AuditLogEntrySchema,
  UserSchema,
  LineItemSchema,
};
