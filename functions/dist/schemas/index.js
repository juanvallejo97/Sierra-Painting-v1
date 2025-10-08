/**
 * Zod Schemas for Sierra Painting
 *
 * Design Principles (from PRD):
 * - Keep schemas ≤10 lines when possible
 * - Use strict validation (no .passthrough())
 * - Server timestamps in ISO-8601 (America/New_York)
 * - All schemas match story acceptance criteria
 */
import { z } from "zod";
// ============================================================================
// Epic A: Authentication & RBAC
// ============================================================================
/**
 * A1: Sign-in/out + reliable sessions
 */
export const LoginSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8).max(128),
});
/**
 * A2: Admin sets roles (claims)
 */
export const SetRoleSchema = z.object({
    uid: z.string().min(1),
    role: z.enum(['admin', 'crewLead', 'crew']),
});
// ============================================================================
// Epic B: Time Clock
// ============================================================================
/**
 * B1: Clock-in (offline + GPS + idempotent)
 */
export const TimeInSchema = z.object({
    jobId: z.string().min(8),
    at: z.number().int().positive(), // Epoch milliseconds
    geo: z.object({
        lat: z.number(),
        lng: z.number(),
    }).optional(),
    clientId: z.string().uuid(), // For idempotency
});
/**
 * B2: Clock-out + overlap guard
 */
export const TimeOutSchema = z.object({
    entryId: z.string().min(1),
    at: z.number().int().positive(),
    breakMin: z.number().min(0).max(180).default(0),
});
// ============================================================================
// Epic C: Invoicing
// ============================================================================
/**
 * C1: Create quote + PDF
 */
export const LineItemSchema = z.object({
    type: z.enum(['labor', 'material', 'other']),
    description: z.string().min(1),
    qty: z.number().min(0),
    unitPrice: z.number().min(0),
});
export const EstimateSchema = z.object({
    leadId: z.string().min(1),
    items: z.array(LineItemSchema).min(1),
    taxRate: z.number().min(0).max(0.15).default(0),
    discount: z.number().min(0).default(0),
});
/**
 * C3: Manual Mark-Paid (check/cash)
 */
export const ManualPaymentSchema = z.object({
    invoiceId: z.string().min(1),
    amount: z.number().int().positive().optional(), // Amount in cents (optional for backward compat)
    method: z.enum(['check', 'cash']),
    reference: z.string().max(64).optional(), // Check number, etc.
    note: z.string().min(3), // Required note
    idempotencyKey: z.string().optional(), // Client-provided for idempotency
});
/**
 * C5: Stripe Checkout (optional)
 */
export const StripeCheckoutSchema = z.object({
    invoiceId: z.string().min(1),
});
// ============================================================================
// Epic D: Lead Management & Scheduling
// ============================================================================
/**
 * D1: Public lead form (App Check + anti-spam)
 */
export const LeadSchema = z.object({
    name: z.string().min(2),
    email: z.string().email().optional(),
    phone: z.string().min(7).optional(),
    address: z.string().min(5),
    details: z.string().max(2000).optional(),
})
    .refine(data => data.email || data.phone, {
    message: "Either email or phone must be provided",
});
// ============================================================================
// Audit & Telemetry
// ============================================================================
/**
 * E3: Telemetry + Audit Log
 */
export const AuditLogSchema = z.object({
    timestamp: z.number().int().positive(),
    entity: z.string(), // 'invoice', 'time_entry', 'user', etc.
    action: z.string(), // 'TIME_IN', 'INVOICE_MARK_PAID', etc.
    actorUid: z.string(),
    orgId: z.string(),
    details: z.record(z.string(), z.any()), // Flexible details object
});
// ============================================================================
// Legacy Schemas (kept for backward compatibility)
// ============================================================================
export const leadSchema = LeadSchema;
export const estimateSchema = EstimateSchema;
export const markPaidManualSchema = ManualPaymentSchema;
export const stripeCheckoutSchema = StripeCheckoutSchema;
