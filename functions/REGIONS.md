# Cloud Functions Region Topology

## Current Deployment

### us-east4 (ALL Functions)
**Why:** Single region deployment for simplicity and consistency

**Callables:**
- `clockIn` - Time clock punch-in
- `clockOut` - Time clock punch-out
- `editTimeEntry` - Edit approved time entries
- `createInvoiceFromTime` - Legacy invoice generation
- `generateInvoice` - Invoice generation from time entries
- `getInvoicePDFUrl` - Fetch invoice PDF URL
- `regenerateInvoicePDF` - Regenerate invoice PDF
- `getProbeMetrics` - Latency probe metrics query
- `manualCleanup` - Manual TTL cleanup trigger
- `setUserRole` - Set custom claims on user

**Event-Driven:**
- `onInvoiceCreated` - Firestore trigger for PDF generation

**Schedulers:**
- `autoClockOut` - Scheduled auto-clockout (daily 2am ET)
- `dailyCleanup` - Scheduled TTL cleanup (daily 3am ET)
- `latencyProbe` - Scheduled latency monitoring (every 5min)
- `warm` - Scheduled warmup ping (every 5min)

**HTTP Endpoints:**
- `api` - HTTP endpoint with minInstances=1 for warmth
- `taskWorker` - Background worker HTTP endpoint

## Configuration

Region configuration is set in `functions/src/index.ts`:

```typescript
// Global default for ALL functions
setGlobalOptions({ region: 'us-east4' });

// Callables explicitly specify us-east4
export const clockIn = functions.onCall({ region: 'us-east4' }, async (req) => {...});
export const generateInvoice = onCall({ region: 'us-east4' }, generateInvoiceHandler);
// ... etc

// Schedulers specify us-east4
export const autoClockOut = onSchedule({ region: 'us-east4', ... }, ...);
export const warm = onSchedule({ region: 'us-east4', ... }, ...);
```

## Rationale

### Why us-east4 for All Functions?
- **Simplicity**: Single region eliminates cross-region complexity
- **Consistency**: All functions in same region simplifies debugging and monitoring
- **Timezone alignment**: ET timezone for scheduled jobs (auto-clockout at 2am ET)
- **Cost**: us-east4 is a cost-effective region
- **Acceptable latency**: Latency from us-east4 to most US locations is acceptable (<200ms)

### Firestore Location
- Firestore database is in `us-central1` (default Firebase region)
- Cross-region latency (us-east4 → us-central1) adds ~10-20ms overhead
- This is acceptable for the MVP phase

## Future Optimization

**Potential improvements for production:**

- [ ] **Co-locate with Firestore**: Consider moving all functions to us-central1 to minimize Firestore latency
- [ ] **Multi-region failover**: Deploy to multiple regions for high availability
- [ ] **Regional caching**: Add Cloud CDN or caching layer to reduce repeated Firestore reads
- [ ] **Measure and decide**: Collect real latency metrics and decide if migration is needed

## Monitoring

- **Latency:** Monitor p95 latency for callables via `latencyProbe` function
- **Cold starts:** Track cold start frequency for us-east4 functions (may need warmup)
- **Cross-region calls:** Monitor if any functions make cross-region Firestore calls
- **Cost:** Compare us-central1 vs us-east4 pricing in Firebase Console

## References

- Firebase Functions v2 regions: https://firebase.google.com/docs/functions/locations
- Pricing: https://firebase.google.com/pricing#blaze-calculator
- `setGlobalOptions()`: https://firebase.google.com/docs/functions/config-env#set_global_options
