# Cloud Functions Performance Optimization

> **Purpose**: Guide for optimizing Cloud Functions cold starts and execution time
>
> **Last Updated**: 2024
>
> **Status**: Active

---

## Overview

This document provides strategies for optimizing Firebase Cloud Functions performance, focusing on reducing cold start times and improving execution speed.

---

## Cold Start Optimization

### Problem

Cold starts occur when:
- Function instance is created for the first time
- Function has been idle and scaled to zero
- New version is deployed

**Impact**: 1-5 seconds added to first request

### Solution: Minimum Instances

Set `minInstances` for critical functions to keep them warm:

```typescript
// functions/src/leads/createLead.ts
export const createLead = functions
  .runWith({
    minInstances: 1,           // Keep 1 instance warm
    maxInstances: 10,          // Scale up to 10
    memory: '256MB',           // Optimize for payload size
    timeoutSeconds: 30,        // 30s timeout
    enforceAppCheck: true,
    consumeAppCheckToken: true,
  })
  .https.onCall(async (data, context) => {
    // Function implementation
  });
```

### Recommended Configuration

| Function Type | minInstances | maxInstances | Memory | Timeout |
|---------------|--------------|--------------|--------|---------|
| **Auth (critical)** | 1 | 20 | 256MB | 30s |
| **Payments** | 1 | 10 | 512MB | 60s |
| **Search/List** | 1 | 15 | 256MB | 30s |
| **Background jobs** | 0 | 5 | 256MB | 540s |
| **Webhooks** | 0 | 10 | 256MB | 60s |

**Cost Note**: `minInstances: 1` costs ~$5-10/month per function but eliminates cold starts for users.

---

## Import Optimization

### Problem

Heavy imports increase cold start time:
```typescript
// ❌ Bad - Imports happen on every cold start
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

export const myFunction = functions.https.onCall(async (data, context) => {
  const db = admin.firestore(); // Initialized on each call
});
```

### Solution: Hoist to Global Scope

```typescript
// ✅ Good - Imports happen once per instance
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

// Initialize once at module load
admin.initializeApp();
const db = admin.firestore();

export const myFunction = functions.https.onCall(async (data, context) => {
  // Use pre-initialized db
  await db.collection('users').doc(context.auth!.uid).get();
});
```

---

## Scheduled Warm-ups

### Problem

Even with `minInstances: 0`, functions can be kept warm with scheduled pings.

### Solution: Cloud Scheduler

```typescript
// functions/src/ops/warmup.ts
import * as functions from 'firebase-functions';

/**
 * Scheduled function to warm up critical endpoints
 * Runs every 5 minutes during business hours
 */
export const warmupCriticalFunctions = functions
  .runWith({
    memory: '128MB',
    timeoutSeconds: 60,
  })
  .pubsub.schedule('*/5 6-20 * * *') // Every 5 min, 6am-8pm
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const functions = [
      'clockIn',
      'clockOut',
      'createLead',
    ];

    const warmups = functions.map(async (name) => {
      try {
        // Make lightweight request to keep instance warm
        // Use admin SDK or HTTP client
        functions.logger.info(`Warming up function: ${name}`);
      } catch (error) {
        functions.logger.error(`Failed to warm ${name}:`, error);
      }
    });

    await Promise.all(warmups);
  });
```

**Schedule Patterns:**
- `*/5 * * * *` - Every 5 minutes (aggressive, for critical)
- `*/15 * * * *` - Every 15 minutes (moderate)
- `0 * * * *` - Every hour (light)

---

## Regional Deployment

### Problem

Cross-region latency adds 100-500ms to requests.

### Solution: Deploy in User's Region

```bash
# Default region (us-central1)
firebase deploy --only functions

# Deploy to specific region
firebase functions:config:set regions.primary=us-west1
```

**Configure in code:**
```typescript
// functions/src/index.ts
const region = 'us-west1'; // or from config

export const clockIn = functions
  .region(region)
  .runWith({ minInstances: 1 })
  .https.onCall(async (data, context) => {
    // Function implementation
  });
```

**Region Selection:**
- `us-west1` - California (best for West Coast US)
- `us-east1` - South Carolina (best for East Coast US)
- `us-central1` - Iowa (default, good for nationwide)

---

## Payload Optimization

### Problem

Large request/response payloads increase latency.

### Solution: Compress and Prune

**Server-side:**
```typescript
import * as functions from 'firebase-functions';

export const getJobs = functions.https.onCall(async (data, context) => {
  const jobs = await db.collection('jobs')
    .where('userId', '==', context.auth!.uid)
    .select('id', 'title', 'status', 'scheduledDate') // ✅ Only needed fields
    .limit(50) // ✅ Limit results
    .get();

  return {
    jobs: jobs.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    })),
  };
});
```

**Response Compression:**
```typescript
// Enable gzip compression (automatic for Cloud Functions)
// Firebase automatically compresses responses > 1KB
```

---

## Connection Pooling

### Problem

Creating new connections for each request is slow.

### Solution: Reuse Connections

```typescript
// ✅ Good - Connection pool initialized once
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

// Configure for better performance
db.settings({
  ignoreUndefinedProperties: true,
  // Connection pooling is automatic
});

export const myFunction = functions.https.onCall(async (data, context) => {
  // Reuse existing connection
  await db.collection('items').add(data);
});
```

---

## Monitoring & Profiling

### Firebase Console Metrics

**View Performance:**
1. Firebase Console → Functions
2. Select function → Metrics tab
3. Monitor:
   - Invocations per second
   - Execution time (P50, P95, P99)
   - Memory usage
   - Active instances

### Cloud Trace

**Enable Tracing:**
```typescript
// Already configured in functions/src/lib/ops/
import { withSpan } from './lib/ops';

export const myFunction = functions.https.onCall(
  withSpan('myFunction', async (data, context) => {
    // Function body automatically traced
  })
);
```

**View Traces:**
- Cloud Console → Trace → Trace List
- Filter by function name
- Analyze latency breakdown

### Budget Alerts

```typescript
// Set up budget alerts in Cloud Console
// Alert when:
// - P95 latency > 500ms
// - Execution time > 5s
// - Error rate > 1%
```

---

## Implementation Checklist

### Phase 1: Quick Wins (Week 1)
- [ ] Add `minInstances: 1` to auth functions (clockIn, clockOut)
- [ ] Hoist all imports to global scope
- [ ] Configure regional deployment (us-west1 or primary region)
- [ ] Enable compression (verify in Network tab)

### Phase 2: Advanced (Week 2-3)
- [ ] Implement scheduled warm-ups for critical functions
- [ ] Add Firebase Performance traces
- [ ] Set up Cloud Monitoring alerts
- [ ] Profile with Cloud Trace

### Phase 3: Optimization (Month 1)
- [ ] Analyze cold start patterns
- [ ] Optimize heavy imports (lazy load if needed)
- [ ] Implement response caching where safe
- [ ] Review and adjust minInstances based on usage

---

## Configuration Template

```typescript
// functions/src/config/performance.ts

export interface FunctionConfig {
  minInstances: number;
  maxInstances: number;
  memory: '128MB' | '256MB' | '512MB' | '1GB' | '2GB';
  timeoutSeconds: number;
}

export const FUNCTION_CONFIGS: Record<string, FunctionConfig> = {
  // Critical (low latency required)
  clockIn: {
    minInstances: 1,
    maxInstances: 20,
    memory: '256MB',
    timeoutSeconds: 30,
  },
  clockOut: {
    minInstances: 1,
    maxInstances: 20,
    memory: '256MB',
    timeoutSeconds: 30,
  },
  
  // Important (moderate latency ok)
  createLead: {
    minInstances: 1,
    maxInstances: 10,
    memory: '256MB',
    timeoutSeconds: 30,
  },
  
  // Background (latency not critical)
  cleanupOldData: {
    minInstances: 0,
    maxInstances: 5,
    memory: '256MB',
    timeoutSeconds: 540,
  },
};

// Usage:
export const clockIn = functions
  .runWith(FUNCTION_CONFIGS.clockIn)
  .https.onCall(async (data, context) => {
    // Implementation
  });
```

---

## Cost Considerations

### Pricing Model

**Invocations**: $0.40 per million  
**CPU Time**: $0.0000025 per GB-second  
**Networking**: $0.12 per GB

### Cost Optimization

**minInstances Impact:**
```
1 instance × 256MB × 24h × 30 days = ~5GB-hours/day
= ~$0.30/day = ~$9/month per function
```

**Trade-off:**
- Without minInstances: $0 idle cost + cold start latency
- With minInstances: ~$9/month + no cold starts

**Recommendation**: Use minInstances only for user-facing functions (5-10 functions max).

---

## Related Documentation

- [Performance Budgets](./PERFORMANCE_BUDGETS.md)
- [Frontend Performance Playbook](./perf-playbook-fe.md)
- [Firebase Documentation](https://firebase.google.com/docs/functions/manage-functions)

---

## Quick Reference

**Add minInstances:**
```typescript
export const myFunction = functions
  .runWith({ minInstances: 1 })
  .https.onCall(async (data, context) => {
    // Implementation
  });
```

**Hoist imports:**
```typescript
// Top of file
import * as admin from 'firebase-admin';
admin.initializeApp();
const db = admin.firestore();

// Use in functions
```

**Check performance:**
```bash
# Firebase Console
firebase console functions

# Or visit: https://console.firebase.google.com
```
