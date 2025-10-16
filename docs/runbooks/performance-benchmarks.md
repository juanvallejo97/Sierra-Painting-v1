# Query Performance Benchmarks

**Purpose:** Reference guide for expected query performance after database hardening implementation.

**Target Metrics:**
- Cold queries (first execution): **<900ms P95**
- Warm queries (cached): **<400ms P95**
- Index usage: **100% (no collection scans)**

---

## Benchmark Summary

| Query | Collection | Cold (P95) | Warm (P95) | Status |
|-------|-----------|-----------|-----------|--------|
| Worker schedule (recent) | job_assignments | <800ms | <350ms | ✅ |
| Worker schedule (upcoming) | job_assignments | <750ms | <300ms | ✅ |
| Pending time entries | timeEntries | <850ms | <380ms | ✅ |
| Weekly revenue | invoices | <800ms | <350ms | ✅ |
| Worker+Job time entries | timeEntries | <750ms | <320ms | ✅ |
| Active jobs | jobs | <700ms | <280ms | ✅ |
| Geofence-enabled jobs | jobs | <720ms | <290ms | ✅ |
| Overdue invoices | invoices | <780ms | <340ms | ✅ |
| Active employees | employees | <650ms | <250ms | ✅ |

---

## Story B: Worker Schedule Queries

### Query 1: Recent Shifts (DESC)

**Use Case:** Worker views their recent shift history

**Query:**
```javascript
db.collection('job_assignments')
  .where('companyId', '==', companyId)
  .where('workerId', '==', workerId)
  .orderBy('shiftStart', 'desc')
  .limit(20)
```

**Index Used:**
```json
{
  "collectionId": "job_assignments",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "workerId", "order": "ASCENDING"},
    {"fieldPath": "shiftStart", "order": "DESCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <800ms
- Warm: <350ms
- Documents returned: 0-20

**Optimization Notes:**
- Most selective field first (companyId)
- Equality filters before orderBy
- DESC order for recent-first display

---

### Query 2: Upcoming Shifts (Range)

**Use Case:** Worker views upcoming shifts for the week

**Query:**
```javascript
db.collection('job_assignments')
  .where('companyId', '==', companyId)
  .where('workerId', '==', workerId)
  .where('shiftStart', '>=', today)
  .where('shiftStart', '<=', nextWeek)
  .orderBy('shiftStart', 'asc')
```

**Index Used:**
```json
{
  "collectionId": "job_assignments",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "workerId", "order": "ASCENDING"},
    {"fieldPath": "shiftStart", "order": "ASCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <750ms
- Warm: <300ms
- Documents returned: 0-50

**Optimization Notes:**
- Range query requires ASC order
- Filters narrow result set before range scan

---

## Story D: Admin Dashboard Queries

### Query 3: Pending Time Entries

**Use Case:** Admin reviews active/pending time entries

**Query:**
```javascript
db.collection('timeEntries')
  .where('companyId', '==', companyId)
  .where('status', '==', 'active')
  .orderBy('clockInAt', 'desc')
  .limit(50)
```

**Index Used:**
```json
{
  "collectionId": "time_entries",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "clockInAt", "order": "DESCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <850ms
- Warm: <380ms
- Documents returned: 0-50

---

### Query 4: Weekly Revenue

**Use Case:** Admin calculates revenue for the past 7 days

**Query:**
```javascript
db.collection('invoices')
  .where('companyId', '==', companyId)
  .where('status', '==', 'paid_cash')
  .where('paidAt', '>=', lastWeek)
  .orderBy('paidAt', 'desc')
```

**Index Used:**
```json
{
  "collectionId": "invoices",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "paidAt", "order": "DESCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <800ms
- Warm: <350ms
- Documents returned: 0-100

**Optimization Notes:**
- Status filter reduces scan size significantly
- paidAt range query with DESC order

---

### Query 5: Worker+Job Time Entries

**Use Case:** Admin views time entries for specific worker and job

**Query:**
```javascript
db.collection('timeEntries')
  .where('companyId', '==', companyId)
  .where('userId', '==', userId)
  .where('jobId', '==', jobId)
  .orderBy('clockInAt', 'desc')
```

**Index Used:**
```json
{
  "collectionId": "time_entries",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "userId", "order": "ASCENDING"},
    {"fieldPath": "jobId", "order": "ASCENDING"},
    {"fieldPath": "clockInAt", "order": "DESCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <750ms
- Warm: <320ms
- Documents returned: 0-30

**Optimization Notes:**
- Three equality filters before orderBy
- Highly selective query (returns small result set)

---

## Story C: Job Location Queries

### Query 6: Active Jobs

**Use Case:** User selects active job from dropdown

**Query:**
```javascript
db.collection('jobs')
  .where('companyId', '==', companyId)
  .where('active', '==', true)
  .orderBy('name', 'asc')
```

**Index Used:**
```json
{
  "collectionId": "jobs",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "active", "order": "ASCENDING"},
    {"fieldPath": "name", "order": "ASCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <700ms
- Warm: <280ms
- Documents returned: 5-50

---

### Query 7: Geofence-Enabled Jobs

**Use Case:** System finds jobs with geofence for validation

**Query:**
```javascript
db.collection('jobs')
  .where('companyId', '==', companyId)
  .where('geofenceEnabled', '==', true)
  .orderBy('createdAt', 'desc')
```

**Index Used:**
```json
{
  "collectionId": "jobs",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "geofenceEnabled", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <720ms
- Warm: <290ms
- Documents returned: 0-50

---

## Invoice Queries

### Query 8: Overdue Invoices

**Use Case:** Admin finds overdue invoices

**Query:**
```javascript
db.collection('invoices')
  .where('companyId', '==', companyId)
  .where('status', '==', 'sent')
  .where('dueDate', '<', today)
  .orderBy('dueDate', 'asc')
```

**Index Used:**
```json
{
  "collectionId": "invoices",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "dueDate", "order": "ASCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <780ms
- Warm: <340ms
- Documents returned: 0-50

---

## Employee Queries

### Query 9: Active Employees

**Use Case:** Admin views active employees

**Query:**
```javascript
db.collection('employees')
  .where('companyId', '==', companyId)
  .where('status', '==', 'active')
  .orderBy('createdAt', 'desc')
```

**Index Used:**
```json
{
  "collectionId": "employees",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

**Performance Targets:**
- Cold: <650ms
- Warm: <250ms
- Documents returned: 0-100

---

## Performance Testing

### Running Benchmarks

```bash
# Start Firestore emulator
firebase emulators:start --only firestore

# Seed realistic test data
npm run seed:fixtures

# Run performance benchmarks
npm run test:perf

# Expected output:
# ✅ All queries meet performance targets
# P95 latencies logged for each query
```

### Production Monitoring

```bash
# Trigger manual monitoring
curl -X POST \
  https://us-east4-YOUR_PROJECT.cloudfunctions.net/queryMonitorManual

# Check Cloud Logging
gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=queryMonitorScheduled" \
  --limit=50 \
  --format=json

# View performance metrics in Firebase Console
# https://console.firebase.google.com/project/YOUR_PROJECT/functions/logs
```

---

## Performance Degradation Alerts

### Warning Thresholds

| Severity | Cold Query | Warm Query | Action |
|----------|-----------|-----------|--------|
| OK | <900ms | <400ms | None |
| WARN | 900-1200ms | 400-600ms | Investigate |
| ERROR | 1200-1500ms | 600-800ms | Immediate review |
| CRITICAL | >1500ms | >800ms | Emergency response |

### Common Causes of Degradation

1. **Index Not Ready**
   - Check: `firebase firestore:indexes`
   - Fix: Wait for index build to complete

2. **Missing Index**
   - Check: Cloud Logging for "index not found" errors
   - Fix: Add required composite index

3. **Large Result Set**
   - Check: Document count in query results
   - Fix: Add pagination, increase limit

4. **Network Latency**
   - Check: Client location vs Firestore region
   - Fix: Use multi-region Firestore

5. **Collection Size**
   - Check: Collection document count
   - Fix: Consider sharding or archiving old data

---

## Optimization Best Practices

### 1. Index Design

✅ **DO:**
- Put most selective field first (usually companyId)
- Use equality filters before range queries
- Match query orderBy direction to index direction

❌ **DON'T:**
- Use `array-contains` with other filters (requires composite index)
- Chain multiple range queries (requires inequality filters)
- Forget to index frequently queried fields

### 2. Query Design

✅ **DO:**
- Use limits to cap result size
- Paginate large result sets
- Cache results client-side when possible

❌ **DON'T:**
- Query without limits
- Use `offset` for pagination (slow)
- Over-fetch data and filter client-side

### 3. Client-Side Optimization

✅ **DO:**
- Use persistent cache
- Implement optimistic UI updates
- Show loading states

❌ **DON'T:**
- Block UI on query completion
- Refetch data unnecessarily
- Ignore offline scenarios

---

## Troubleshooting Slow Queries

### Step 1: Identify Slow Query

```bash
# Check query monitor logs
gcloud logging read "severity>=WARN AND resource.labels.function_name=queryMonitorScheduled"

# Look for queries exceeding thresholds
```

### Step 2: Verify Index Exists

```bash
# List all indexes
firebase firestore:indexes

# Check if required index is READY
# If missing, add to firestore.indexes.json and deploy
```

### Step 3: Analyze Query Structure

```javascript
// Log explain plan (client-side)
query.explain().then(explanation => {
  console.log('Index used:', explanation.metrics.index);
  console.log('Documents scanned:', explanation.metrics.documentsScanned);
  console.log('Documents returned:', explanation.metrics.documentsReturned);
});
```

### Step 4: Optimize Query

- Reduce result set size with limits
- Add more selective filters
- Consider denormalization
- Cache results

---

**Document Version:** 1.0
**Last Updated:** 2025-10-16
**Review Cycle:** Monthly
