# ADR-006: Idempotency Strategy

## Status
Accepted

## Date
2024-01-15

## Context
In a distributed system with offline support and potential network failures, operations can be retried multiple times. Without idempotency:
- Duplicate clock-ins create multiple time entries
- Double-tapping "Mark Paid" creates duplicate payments
- Offline queue replays can cause data duplication
- Webhook retries from Stripe can process payments twice

We need a comprehensive idempotency strategy that:
- Works across offline/online scenarios
- Prevents duplicate financial transactions
- Supports client-provided and server-generated keys
- Has minimal performance impact
- Is simple to implement consistently

## Decision

### 1. Idempotency Key Strategy
We use **multiple layers** of idempotency:

#### Client-Side (UUID v4 + Operation Type)
```typescript
// Generated once when user initiates action
const clientId = uuid.v4(); // e.g., "f47ac10b-58cc-4372-a567-0e02b2c3d479"
const idempotencyKey = `${operation}:${resourceId}:${clientId}`;
// Example: "clock_in:job123:f47ac10b-58cc-4372-a567-0e02b2c3d479"
```

#### Server-Side (Collection-Based)
```typescript
// Firestore collection: /idempotency/{key}
interface IdempotencyRecord {
  key: string;              // The idempotency key
  operation: string;        // e.g., "mark_paid"
  resourceId: string;       // e.g., invoice ID
  result: any;              // Original operation result
  processedAt: Timestamp;   // When first processed
  expiresAt: Timestamp;     // TTL for cleanup (24-48 hours)
}
```

### 2. Implementation Pattern
```typescript
export const idempotentOperation = functions.https.onCall(async (data, context) => {
  const validatedData = schema.parse(data);
  
  // 1. Generate or use client-provided key
  const idempotencyKey = validatedData.clientId 
    ? `${operation}:${resourceId}:${validatedData.clientId}`
    : `${operation}:${resourceId}:${Date.now()}`;
  
  // 2. Check if already processed
  const idempotencyDoc = await db.collection('idempotency').doc(idempotencyKey).get();
  if (idempotencyDoc.exists) {
    functions.logger.info(`Idempotent request: ${idempotencyKey}`);
    return idempotencyDoc.data()?.result;
  }
  
  // 3. Perform operation in transaction
  const result = await db.runTransaction(async (transaction) => {
    // Business logic here
    const ref = await performOperation(transaction, validatedData);
    
    // 4. Store idempotency record
    transaction.set(db.collection('idempotency').doc(idempotencyKey), {
      key: idempotencyKey,
      operation,
      resourceId,
      result: { success: true, id: ref.id },
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 48 * 60 * 60 * 1000) // 48 hours
      ),
    });
    
    return { success: true, id: ref.id };
  });
  
  return result;
});
```

### 3. Firestore Rules for Idempotency
```javascript
match /idempotency/{key} {
  // Read-only to admins (for debugging)
  allow read: if isAdmin();
  // No client writes - server only
  allow write: if false;
}
```

### 4. Offline Queue Integration
```dart
// Client-side queue item
class QueueItem {
  String id;              // UUID
  String type;            // 'clock_in', 'mark_paid', etc.
  String clientId;        // Idempotency key component
  Map<String, dynamic> data;
  DateTime createdAt;
  bool processed;
  
  // Send to server with clientId for idempotency
  Future<void> sync() async {
    final result = await functions.httpsCallable('clockIn').call({
      'jobId': data['jobId'],
      'clientId': clientId,  // Key for idempotency
      'at': data['at'],
    });
    processed = true;
  }
}
```

### 5. Stripe Webhook Idempotency
```typescript
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  
  // Use Stripe event ID as idempotency key
  const idempotencyKey = `stripe:${event.type}:${event.id}`;
  
  const idempotencyDoc = await db.collection('idempotency').doc(idempotencyKey).get();
  if (idempotencyDoc.exists) {
    // Already processed
    return res.json({ received: true });
  }
  
  // Process event...
  await handleStripeEvent(event);
  
  // Store idempotency record
  await db.collection('idempotency').doc(idempotencyKey).set({
    key: idempotencyKey,
    operation: 'stripe_webhook',
    resourceId: event.data.object.id,
    eventType: event.type,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  res.json({ received: true });
});
```

### 6. Cleanup Strategy
```typescript
// Scheduled function runs daily
export const cleanupIdempotency = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const expiredDocs = await db.collection('idempotency')
      .where('expiresAt', '<', now)
      .limit(500)
      .get();
    
    const batch = db.batch();
    expiredDocs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    
    functions.logger.info(`Cleaned up ${expiredDocs.size} expired idempotency records`);
  });
```

## Consequences

### Positive
- **No Duplicates**: Financial transactions (payments, clock entries) cannot be duplicated
- **Offline Safe**: Offline queue replays are idempotent
- **Webhook Safe**: Stripe webhook retries don't cause duplicate processing
- **Debuggable**: Idempotency collection provides audit trail
- **Client Control**: Clients can provide their own keys for better control
- **Performance**: Single read check before operation, minimal overhead

### Negative
- **Storage Cost**: Extra Firestore collection (mitigated by TTL cleanup)
- **Complexity**: Additional code in every mutating function
- **Clock Skew**: Date.now() fallback can theoretically collide (extremely rare)
- **Cleanup Burden**: Need scheduled function to remove old records

## Alternatives Considered

### 1. Firestore Transaction Alone
- **Why Not**: Transactions prevent concurrent writes but don't prevent retries/replays
- **Example**: User taps "Clock In" twice → two transactions, both succeed

### 2. Unique Constraints in Firestore
- **Why Not**: Firestore doesn't support unique constraints except document IDs
- **Tradeoff**: We use document IDs for idempotency keys

### 3. Client-Side Deduplication Only
- **Why Not**: Clients can be compromised, offline queue can replay, webhooks retry
- **Tradeoff**: Client-side is still useful as first line of defense (disabled buttons)

### 4. Redis/Memcached for Idempotency
- **Why Not**: Additional infrastructure, not available in Firebase stack
- **Tradeoff**: Would be faster but not worth the complexity

### 5. Longer TTL (7+ days)
- **Why Not**: Most retries happen within minutes/hours, not days
- **Tradeoff**: 48 hours balances safety with storage costs

## References
- [Stripe Idempotency](https://stripe.com/docs/api/idempotent_requests)
- [Google Cloud Idempotency Best Practices](https://cloud.google.com/architecture/application-deployment-and-testing-strategies#idempotency)
- [Firebase Transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
- Story B1 (Clock-in with offline + idempotency)
- Story C3 (Manual mark-paid with idempotency)
