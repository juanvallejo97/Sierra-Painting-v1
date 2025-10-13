import { onCall, HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import { LeadSchema, type Lead } from '../lib/zodSchemas';
import { logAudit, createAuditEntry, extractCallableMetadata } from '../lib/audit';
import { checkIdempotency, recordIdempotency, generateIdempotencyKey } from '../lib/idempotency';
import { getDeploymentConfig } from '../config/deployment';
import { checkRateLimit, getClientIP } from '../middleware/rateLimiter';

// Initialize Admin if not already
try { admin.app(); } catch { admin.initializeApp(); }

const LEADS_COLLECTION = 'leads';

// Placeholder captcha verifier – replace with real provider (reCAPTCHA / hCaptcha)
function verifyCaptcha(token: string): boolean {
  logger.warn('Captcha verification not implemented');
  return token?.length > 10;
}

/**
 * Create Lead - Public Endpoint
 *
 * SECURITY DESIGN:
 * This endpoint is intentionally PUBLIC (no authentication required) to allow
 * anonymous website visitors to submit lead forms. Protection against abuse:
 *
 * 1. App Check: Ensures requests come from registered web/mobile apps
 * 2. Rate Limiting: Max 5 requests per hour per IP address
 * 3. Captcha: Verifies human interaction (TODO: implement real provider)
 * 4. Idempotency: Prevents duplicate submissions via hashed key
 * 5. Input Validation: Zod schema validates all fields
 *
 * This multi-layered approach provides defense-in-depth without requiring
 * authentication, which would block legitimate lead capture.
 */
export const createLead = onCall(
  {
  ...getDeploymentConfig('createLead'),
  consumeAppCheckToken: true,
  },
  async (req: CallableRequest) => {
    // --- App Check (defense-in-depth) ---------------------------------------
    if (!req.app) {
      throw new HttpsError('failed-precondition', 'App Check validation failed');
    }

    // --- Rate Limiting (anti-spam) -------------------------------------------
    // Allow 5 lead submissions per hour per IP address
    const clientIP = getClientIP(req);
    await checkRateLimit('createLead', clientIP, 5, 3600);

    // --- Input validation ----------------------------------------------------
    let lead: Lead;
    try {
      lead = LeadSchema.parse(req.data);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Invalid lead data';
      logger.warn('Invalid lead data', { message });
      throw new HttpsError('invalid-argument', message);
    }

    // --- Captcha -------------------------------------------------------------
    if (!verifyCaptcha(lead.captchaToken)) {
      throw new HttpsError('failed-precondition', 'Captcha verification failed');
    }

    // --- Idempotency (email+phone+ts) ---------------------------------------
    const key = generateIdempotencyKey(
      'createLead',
      lead.email ?? '',
      lead.phone ?? '',
      String(Date.now())
    );

    if (await checkIdempotency(key)) {
      logger.info('Duplicate createLead (idempotent OK)', { key, source: lead.source });
      return { leadId: key, message: 'Lead already submitted' };
    }

    // --- Firestore write -----------------------------------------------------
    const db = admin.firestore();
    const docRef = db.collection(LEADS_COLLECTION).doc();

    const toSave = {
      ...lead,
      status: 'new',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // do not store captcha token
    delete (toSave as Partial<Lead> & { captchaToken?: string }).captchaToken;

    await docRef.set(toSave);
    const leadId = docRef.id;

    // --- Idempotency record --------------------------------------------------
    await recordIdempotency(key, { leadId }, 24 * 60 * 60); // 24h TTL

    // --- Audit log -----------------------------------------------------------
    const md = extractCallableMetadata(req);
    await logAudit(
      createAuditEntry({
        entity: 'lead',
        entityId: leadId,
        action: 'created',
        actor: 'anonymous',
        orgId: 'default',
        ...md,
        metadata: { source: lead.source, email: lead.email },
      })
    );

    logger.info('Lead created', { leadId, source: lead.source });
    return { leadId, message: 'Lead submitted successfully' };
  }
);
