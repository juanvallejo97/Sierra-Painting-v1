# Firebase Region Configuration

**Date**: 2025-10-10
**Region**: `us-east4` (Northern Virginia)
**Decision**: Optimized for East Coast latency

---

## Selected Region

**us-east4** (Northern Virginia, USA)

---

## Rationale

### Geographic Proximity
- Development team located on East Coast
- Primary user base expected in Eastern United States
- Lower latency for real-time operations (Firestore, Storage)

### Performance Impact

| Service | us-east4 Latency | us-central1 Latency | Improvement |
|---------|------------------|---------------------|-------------|
| **Firestore reads** | ~15-25ms | ~35-50ms | ~20-30ms faster |
| **Firestore writes** | ~25-35ms | ~45-60ms | ~20-30ms faster |
| **Storage uploads** | ~50-100ms | ~80-150ms | ~30-50ms faster |
| **Cloud Functions** | ~100-200ms | ~150-250ms | ~50ms faster |

### Service Availability

All required Firebase services available in us-east4:
- ✅ Cloud Firestore
- ✅ Cloud Storage
- ✅ Cloud Functions
- ✅ Firebase Authentication
- ✅ Firebase Hosting
- ✅ App Check

---

## Configuration Requirements

### Critical: All Services Must Use Same Region

⚠️ **IMPORTANT**: Firestore and Storage MUST be in the same region for optimal performance.

**During project setup**:
1. **Firestore**: Select `us-east4` when creating database
2. **Storage**: Select `us-east4` when enabling storage
3. **Cloud Functions**: Deploy to `us-east4` (configured in `firebase.json`)

### Verify Region Consistency

```bash
# Check Firestore location
# Firebase Console → Firestore → Settings
# Should show: us-east4

# Check Storage location
# Firebase Console → Storage → Settings
# Should show: us-east4

# Check Functions deployment region
# firebase.json → functions.region should be "us-east4"
```

---

## Migration Considerations

### If Changing Regions Later

⚠️ **Region is immutable after creation** - you cannot change a project's region.

To migrate to a different region:
1. Create new Firebase project in desired region
2. Export all Firestore data
3. Export all Storage files
4. Import to new project
5. Update app configuration
6. Migrate users (requires Cloud Functions)

**Estimated effort**: 2-4 hours for small datasets, longer for production data.

### Multi-Region Strategy (Future)

For global scale, consider:
- **Primary**: us-east4 (East Coast users)
- **Secondary**: europe-west1 (European users)
- **Tertiary**: asia-northeast1 (Asian users)

Use Firebase Hosting CDN for static assets (automatically multi-region).

---

## Cloud Functions Configuration

Update `firebase.json` to deploy functions to us-east4:

```json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs18",
    "region": "us-east4"
  }
}
```

Or specify per-function in code:

```typescript
import { region } from 'firebase-functions/v2';

export const myFunction = region('us-east4').https.onCall((request) => {
  // Function logic
});
```

---

## Monitoring

### Latency Monitoring

Track p50/p95/p99 latencies by region:
- **Target p95**: <100ms for Firestore reads
- **Target p95**: <300ms for Cloud Functions

### Alert Thresholds

Set alerts if latency exceeds:
- Firestore reads: >150ms (p95)
- Firestore writes: >200ms (p95)
- Cloud Functions: >600ms (p95)
- Storage uploads: >500ms (p95)

---

## Cost Implications

### Pricing (us-east4 vs us-central1)

**No price difference** - both regions have identical Firebase pricing:
- Firestore: $0.06/100k reads, $0.18/100k writes
- Storage: $0.026/GB/month
- Functions: $0.40/million invocations

### Network Egress

Network egress charges apply for:
- Data transfer between regions
- Data transfer to client (same regardless of region)

**Best practice**: Keep all services in same region to minimize cross-region charges.

---

## Region-Specific Features

### Available in us-east4

✅ All Firebase features available:
- Firestore (Native mode)
- Cloud Storage
- Cloud Functions (Gen 1 & Gen 2)
- Firebase Authentication
- Firebase Hosting
- App Check
- Extensions
- Emulator Suite

### SLA Guarantees

Firebase provides 99.95% uptime SLA for:
- Firestore
- Authentication
- Storage
- Hosting

Cloud Functions: 99.5% uptime SLA

---

## Checklist for New Projects

When creating staging/production projects:

- [ ] **Firestore**: Location set to `us-east4`
- [ ] **Storage**: Location set to `us-east4`
- [ ] **Functions**: `firebase.json` specifies `region: "us-east4"`
- [ ] **Verify**: All services in same region
- [ ] **Document**: Update `.firebaserc` with project IDs
- [ ] **Test**: Measure actual latency from East Coast

---

## References

- [Firebase Locations](https://firebase.google.com/docs/projects/locations)
- [Cloud Functions Locations](https://cloud.google.com/functions/docs/locations)
- [Firestore Locations](https://cloud.google.com/firestore/docs/locations)
- [Performance Monitoring](https://firebase.google.com/docs/perf-mon)

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-10-10 | Selected us-east4 | East Coast proximity, lower latency for dev team and expected users |

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
