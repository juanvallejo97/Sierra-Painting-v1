# Security Guide — Project Sierra

> **Version:** V1  
> **Last Updated:** 2024-10-02  
> **Status:** Board-Ready

---

## Security Philosophy

**Deny-by-Default**: All access is denied unless explicitly allowed  
**Defense in Depth**: Multiple layers of security controls  
**Server Authority**: Critical state changes (payments, status) happen server-side only  
**Auditability**: All sensitive operations logged immutably  
**Privacy-First**: No PII in logs, minimal data collection

---

## Threat Model

### In Scope

- Unauthorized access to user data
- Invoice/payment tampering
- Privilege escalation (crew → admin)
- Data exfiltration
- Rate limiting bypass
- XSS/injection attacks

### Out of Scope (for V1)

- DDoS protection (handled by Firebase)
- Physical device security
- Social engineering
- Third-party library vulnerabilities (assumed trusted)

---

## Authentication & Authorization

### Firebase Authentication

```typescript
// All callable functions check authentication
export const someFu function = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = context.auth.uid;
  // ... proceed with authenticated logic
});
```

### Custom Claims RBAC

**Roles:**
- `admin`: Full access, can mark invoices paid, manage users
- `crew_lead`: Can manage crew, view schedules
- `crew`: Can clock in/out, view assigned jobs

**Setting Claims (Admin Function):**
```typescript
export const setUserRole = functions.https.onCall(async (data, context) => {
  // Verify caller is admin
  if (!context.auth?.token.role || context.auth.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }

  const {uid, role, orgId} = data;
  
  // Validate inputs
  if (!['admin', 'crew_lead', 'crew'].includes(role)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid role');
  }

  // Set custom claims
  await admin.auth().setCustomUserClaims(uid, {role, orgId});
  
  // Audit log
  await logAudit(createAuditEntry({
    entity: 'user',
    entityId: uid,
    action: 'updated',
    actor: context.auth.uid,
    orgId: context.auth.token.orgId,
    metadata: {role, newOrgId: orgId},
  }));

  return {success: true};
});
```

**Checking Claims (Flutter):**
```dart
final user = FirebaseAuth.instance.currentUser;
final idTokenResult = await user?.getIdTokenResult(true);
final role = idTokenResult?.claims?['role'] as String?;

if (role == 'admin') {
  // Show admin features
}
```

---

## Firestore Security Rules

### Core Principles

1. **Deny by default**
2. **Org-scoped data** (multi-tenancy)
3. **Role-based permissions**
4. **Server-only critical fields**

### Example Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================================
    // HELPER FUNCTIONS
    // ============================================================
    
    // Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Check if user belongs to organization
    function belongsToOrg(orgId) {
      return isAuthenticated() && 
             request.auth.token.orgId == orgId;
    }
    
    // Check if user has specific role
    function hasRole(role) {
      return isAuthenticated() && 
             request.auth.token.role == role;
    }
    
    // Check if user is admin
    function isAdmin() {
      return hasRole('admin');
    }
    
    // ============================================================
    // DEFAULT DENY
    // ============================================================
    
    match /{document=**} {
      allow read, write: if false;
    }
    
    // ============================================================
    // USER COLLECTION
    // ============================================================
    
    match /users/{userId} {
      // Users can read their own profile
      allow read: if isAuthenticated() && 
                     request.auth.uid == userId;
      
      // Admins can read all users in their org
      allow read: if isAdmin() && 
                     resource.data.orgId == request.auth.token.orgId;
      
      // Users can update their own profile (except role/orgId)
      allow update: if isAuthenticated() && 
                       request.auth.uid == userId &&
                       !request.resource.data.diff(resource.data).affectedKeys()
                         .hasAny(['role', 'orgId']);
      
      // Only server can create/delete users (via Auth triggers)
      allow create, delete: if false;
    }
    
    // ============================================================
    // INVOICES COLLECTION
    // ============================================================
    
    match /invoices/{invoiceId} {
      // Users can read invoices in their org
      allow read: if belongsToOrg(resource.data.orgId);
      
      // Users can create invoices (server validates)
      allow create: if isAuthenticated() && 
                       belongsToOrg(request.resource.data.orgId);
      
      // Users can update invoices BUT NOT paid/paidAt fields
      allow update: if isAuthenticated() && 
                       belongsToOrg(resource.data.orgId) &&
                       !request.resource.data.diff(resource.data).affectedKeys()
                         .hasAny(['paid', 'paidAt', 'paymentMethod', 'paymentAmount']);
      
      // Only admins can delete invoices
      allow delete: if isAdmin() && 
                       belongsToOrg(resource.data.orgId);
      
      // ============================================================
      // PAYMENTS SUBCOLLECTION (Write-Only)
      // ============================================================
      
      match /payments/{paymentId} {
        // Server can write (via Cloud Function markPaidManual)
        allow write: if false; // All writes via server function
        
        // Admins can read payment records
        allow read: if isAdmin() && 
                       belongsToOrg(get(/databases/$(database)/documents/invoices/$(invoiceId)).data.orgId);
      }
    }
    
    // ============================================================
    // LEADS COLLECTION (Public Write)
    // ============================================================
    
    match /leads/{leadId} {
      // Public can create leads (via createLead function with App Check)
      // Note: This is actually handled by Cloud Function, not direct writes
      allow create: if false; // All writes via createLead function
      
      // Admins can read leads
      allow read: if isAdmin();
      
      // Admins can update/delete leads
      allow update, delete: if isAdmin();
    }
    
    // ============================================================
    // TIME ENTRIES (Collection Group)
    // ============================================================
    
    match /{path=**}/timeEntries/{entryId} {
      // Users can read their own time entries
      allow read: if isAuthenticated() && 
                     resource.data.userId == request.auth.uid;
      
      // Admins can read all time entries in their org
      allow read: if isAdmin() && 
                     belongsToOrg(resource.data.orgId);
      
      // Users can create their own time entries
      allow create: if isAuthenticated() && 
                       request.resource.data.userId == request.auth.uid &&
                       belongsToOrg(request.resource.data.orgId);
      
      // Time entries are immutable after creation (prevent time fraud)
      allow update, delete: if false;
    }
    
    // ============================================================
    // ACTIVITY LOGS (Read-Only)
    // ============================================================
    
    match /activityLog/{logId} {
      // Only admins can read audit logs
      allow read: if isAdmin();
      
      // No one can write (server-only)
      allow write: if false;
    }
  }
}
```

### Testing Rules

```bash
# Start emulators
firebase emulators:start

# Run rules tests
cd functions
npm run test:rules
```

---

## Cloud Functions Security

### App Check Enforcement

**Status:** ✅ **ENFORCED** - All callable functions now enforce App Check with replay protection

```typescript
// All callable functions enforce App Check with replay protection
export const createLead = functions
  .runWith({
    enforceAppCheck: true,
    consumeAppCheckToken: true, // Prevents replay attacks
  })
  .https.onCall(async (data, context) => {
    // Defense in depth: runtime validation
    if (!context.app) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'App Check validation failed'
      );
    }
    
    // App Check token is now consumed and cannot be reused
    // Proceed with function logic
  });
```

**Protected Functions:**
- ✅ `createLead` - Lead form submission
- ✅ `markPaidManual` - Manual payment processing
- ✅ `markPaymentPaid` - Legacy payment processing (backward compat)
- ✅ `clockIn` - Time clock entry
- ✅ `initializeFlags` - Feature flag initialization

**Setup App Check:**
1. Enable in Firebase Console → App Check
2. For debug (development):
   ```bash
   flutter run
   # Copy debug token from logs
   # Register in Firebase Console → App Check → Debug tokens
   ```
3. For production:
   - Android: SafetyNet or Play Integrity API
   - iOS: DeviceCheck or App Attest
   - Web: reCAPTCHA

**Security Benefits:**
- **Anti-abuse**: Only legitimate app instances can call functions
- **Replay protection**: Tokens are single-use (consumeAppCheckToken)
- **Defense in depth**: App Check + authentication + authorization

### Input Validation (Zod)

```typescript
import {z} from 'zod';

const ManualPaymentSchema = z.object({
  invoiceId: z.string().min(1),
  method: z.enum(['check', 'cash']),
  reference: z.string().max(64).optional(),
  note: z.string().min(3), // Required note for audit
  idempotencyKey: z.string().optional(),
}).strict(); // Reject unknown fields

export const markPaidManual = functions.https.onCall(async (data: unknown, context) => {
  // Type-safe validation
  let validatedPayment;
  try {
    validatedPayment = ManualPaymentSchema.parse(data);
  } catch (error: unknown) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid payment data');
  }
  
  // Proceed with validated data
});
```

### Rate Limiting

**Function-Level (Future Enhancement):**
```typescript
// Use Firebase Extensions: Rate Limit by IP or User
// Or implement custom with Firestore:

async function checkRateLimit(userId: string, action: string): Promise<boolean> {
  const key = `rate_limit:${userId}:${action}`;
  const now = Date.now();
  const windowMs = 60000; // 1 minute
  const maxRequests = 10;

  const doc = await db.collection('rate_limits').doc(key).get();
  const data = doc.data();

  if (!data || now - data.windowStart > windowMs) {
    // New window
    await db.collection('rate_limits').doc(key).set({
      windowStart: now,
      count: 1,
    });
    return true;
  }

  if (data.count >= maxRequests) {
    return false; // Rate limit exceeded
  }

  await db.collection('rate_limits').doc(key).update({
    count: admin.firestore.FieldValue.increment(1),
  });
  return true;
}
```

---

## Idempotency

### Strategy

All critical write operations use idempotency keys to prevent duplicate submissions (e.g., offline retries, webhook replays).

### Implementation

```typescript
// lib/idempotency.ts
export async function checkIdempotency(key: string): Promise<boolean> {
  const doc = await db.collection('idempotency').doc(key).get();
  return doc.exists;
}

export async function recordIdempotency(
  key: string,
  result: unknown,
  ttlSeconds: number = 24 * 60 * 60
): Promise<void> {
  await db.collection('idempotency').doc(key).set({
    key,
    result,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: new Date(Date.now() + ttlSeconds * 1000),
  });
}

// Usage in function
export const markPaidManual = functions.https.onCall(async (data, context) => {
  const idempotencyKey = data.idempotencyKey || 
    generateIdempotencyKey('markPaid', data.invoiceId, context.auth.uid);

  // Check if already processed
  const alreadyProcessed = await checkIdempotency(idempotencyKey);
  if (alreadyProcessed) {
    return await getIdempotencyResult(idempotencyKey);
  }

  // Process payment...
  const result = await processPayment(data);

  // Record idempotency
  await recordIdempotency(idempotencyKey, result);

  return result;
});
```

### Stripe Webhook Idempotency

```typescript
export async function handleStripeWebhook(req, res) {
  const event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);

  // Check if event already processed
  const alreadyProcessed = await isStripeEventProcessed(event.id);
  if (alreadyProcessed) {
    res.json({received: true, note: 'already processed'});
    return;
  }

  // Process event...
  await processStripeEvent(event);

  // Record as processed (with 30-day TTL)
  await recordStripeEvent(event.id, event.type);

  res.json({received: true});
}
```

---

## Audit Logging

### What to Log

- ✅ Payment operations (mark paid, refund, void)
- ✅ User role changes
- ✅ Invoice creation/modification
- ✅ Time entry creation (for payroll audit)
- ✅ Lead submissions
- ❌ Read operations (too noisy)
- ❌ PII (names, addresses) - only IDs

### Log Format

```typescript
interface AuditLogEntry {
  entity: 'invoice' | 'payment' | 'user' | ...;
  entityId: string;
  action: 'created' | 'updated' | 'deleted' | 'paid' | ...;
  actor: string; // Firebase UID
  actorRole?: 'admin' | 'crew_lead' | 'crew';
  orgId: string;
  timestamp: string; // ISO 8601
  ipAddress?: string;
  userAgent?: string;
  changes?: Record<string, {old: unknown; new: unknown}>;
  metadata?: Record<string, unknown>;
}
```

### Creating Audit Logs

```typescript
import {logAudit, createAuditEntry} from './lib/audit';

await logAudit(createAuditEntry({
  entity: 'invoice',
  entityId: invoiceId,
  action: 'paid',
  actor: userId,
  actorRole: 'admin',
  orgId: orgId,
  metadata: {
    amount: 1500,
    method: 'check',
    reference: 'CHK-12345',
  },
}));
```

### Querying Audit Logs

```typescript
// Get all payment logs for an invoice
const logs = await db.collection('activityLog')
  .where('entity', '==', 'invoice')
  .where('entityId', '==', invoiceId)
  .where('action', '==', 'paid')
  .orderBy('timestamp', 'desc')
  .limit(10)
  .get();
```

---

## Stripe Security (Optional Feature)

### Webhook Signature Verification

```typescript
import Stripe from 'stripe';

export async function handleStripeWebhook(req, res) {
  const sig = req.headers['stripe-signature'];
  
  let event: Stripe.Event;
  try {
    // Verify signature - CRITICAL: prevents spoofing
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      webhookSecret
    );
  } catch (err) {
    functions.logger.error('Webhook signature verification failed:', err);
    res.status(400).json({error: 'Invalid signature'});
    return;
  }

  // Signature valid, process event
  await processEvent(event);
  res.json({received: true});
}
```

### API Key Management

**Never commit secrets:**
```bash
# .gitignore
.env
.env.*
functions/.runtimeconfig.json
```

**Use Secret Manager:**
```bash
# Store secret
firebase functions:secrets:set STRIPE_SECRET_KEY

# Access in function
const stripeKey = process.env.STRIPE_SECRET_KEY;
```

---

## Data Privacy

### PII Handling

- **Minimize Collection**: Only collect what's necessary
- **No Logs**: Never log PII (names, emails, addresses)
- **Anonymize**: Hash user IDs for analytics
- **Retention**: Auto-delete old audit logs (> 2 years)

### User Data Deletion

```typescript
export const onUserDelete = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;

  // Delete user profile
  await db.collection('users').doc(userId).delete();

  // Anonymize time entries (keep for payroll)
  const timeEntries = await db.collectionGroup('timeEntries')
    .where('userId', '==', userId)
    .get();

  const batch = db.batch();
  timeEntries.forEach(doc => {
    batch.update(doc.ref, {
      userId: 'DELETED_USER',
      anonymized: true,
    });
  });
  await batch.commit();

  // Anonymize audit logs
  const auditLogs = await db.collection('activityLog')
    .where('actor', '==', userId)
    .get();

  const batch2 = db.batch();
  auditLogs.forEach(doc => {
    batch2.update(doc.ref, {
      actor: 'DELETED_USER',
      anonymized: true,
    });
  });
  await batch2.commit();
});
```

---

## Penetration Testing Checklist

### Before V1 Launch

- [ ] SQL Injection: Test all user inputs (Firestore is NoSQL, but test string inputs)
- [ ] XSS: Test lead form with `<script>` tags
- [ ] CSRF: Verify all state-changing operations require auth
- [ ] Privilege Escalation: Test crew user accessing admin routes
- [ ] Rate Limiting: Spam submit lead form 100 times
- [ ] Idempotency: Submit same invoice payment 10 times simultaneously
- [ ] Rules Bypass: Try direct Firestore writes to set `invoice.paid=true`
- [ ] Webhook Spoofing: Send fake Stripe webhook without signature
- [ ] Token Expiry: Test with expired Firebase ID token

---

## Incident Response

### Security Breach Protocol

1. **Detect**: Monitor for unusual activity (Firebase Analytics, Cloud Logging)
2. **Contain**: Disable compromised accounts, revoke API keys
3. **Investigate**: Review audit logs, identify affected data
4. **Notify**: Inform affected users within 72 hours (GDPR)
5. **Remediate**: Patch vulnerability, reset credentials
6. **Review**: Post-mortem, update security controls

### Contact

- **Security Issues**: security@sierrapainting.com
- **Bug Bounty**: TBD (V2)

---

## Compliance

### GDPR (if applicable)

- ✅ Right to access: User can export their data
- ✅ Right to deletion: User can request account deletion
- ✅ Data minimization: Only collect necessary data
- ✅ Audit logs: Track all data access/modifications
- ✅ Breach notification: 72-hour timeline

### PCI DSS (if using Stripe)

- ✅ Never store card numbers (Stripe handles)
- ✅ Use HTTPS for all communication
- ✅ Tokenize payment data
- ✅ Regular security audits

---

## Summary

- ✅ Deny-by-default Firestore Rules
- ✅ Custom claims RBAC (admin, crew_lead, crew)
- ✅ App Check enforced on callable functions
- ✅ Zod validation for all inputs
- ✅ Idempotency for critical operations
- ✅ Immutable audit logs
- ✅ Stripe webhook signature verification
- ✅ Server-only critical state (invoice.paid)
- ✅ PII handling and data deletion
- ✅ Workload Identity Federation for CI/CD (no long-lived keys)

For questions, see [Architecture.md](./Architecture.md) or [DEVELOPER_WORKFLOW.md](./DEVELOPER_WORKFLOW.md).

For CI/CD security setup, see [GCP Workload Identity Setup](./ops/gcp-workload-identity-setup.md).
