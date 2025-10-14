# ADR 004: Timekeeping Model — Event-Driven Function-Write Pattern

**Status**: Accepted
**Date**: 2025-01-11
**Deciders**: Engineering team
**Related**: [ADR 003: Security Rules Architecture]

## Context

We need a timeclock system for field workers that:
- Enforces geofence boundaries (workers can only clock in/out at assigned job sites)
- Prevents tampering or retroactive edits by workers
- Provides admin visibility and approval workflow
- Handles offline scenarios and network failures gracefully
- Maintains a complete audit trail

**Core Problem**: Firestore Security Rules cannot compute distances (Haversine formula), so geofence validation cannot happen at the database layer. We must validate server-side, but we need a pattern that prevents clients from bypassing validation.

## Decision

We implement an **event-driven, function-write-only pattern** with three key components:

### 1. Event Collection (`clockEvents`)
**Purpose**: Client-writable append-only log of clock attempts.

**Rules**:
```javascript
match /clockEvents/{id} {
  // Workers can create only their own events
  allow create: if authed()
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.companyId == claimCompany();

  // Append-only: no updates or deletes
  allow update, delete: if false;
}
```

**Why**:
- Workers need a way to signal "I want to clock in/out"
- Events are immutable and auditable
- Offline-friendly: events can be queued and sent when online
- Failed attempts are preserved for debugging

### 2. Authoritative Collection (`timeEntries`)
**Purpose**: Function-managed records of actual work time.

**Rules**:
```javascript
match /timeEntries/{id} {
  // Workers can read their own; admins read all company
  allow read: if authed() && (
    (hasAnyRole(["admin","manager"]) && resource.data.companyId == claimCompany()) ||
    (resource.data.userId == request.auth.uid && resource.data.companyId == claimCompany())
  );

  // NO client writes - only Cloud Functions can write
  allow write: if false;
}
```

**Why**:
- Single source of truth for payroll, billing, compliance
- Clients cannot forge or modify entries
- Geofence validation enforced before entry creation
- Approved/invoiced entries cannot be edited by clients

### 3. Validation Functions (`clockIn`, `clockOut`)
**Purpose**: Server-side validation with Haversine distance calculation.

**Flow**:
```
Client                  Cloud Function           Firestore
  |                          |                        |
  | clockIn(jobId, lat, lng) |                        |
  |------------------------->|                        |
  |                          | Validate assignment   |
  |                          | Haversine(job, loc)   |
  |                          | Check active entries  |
  |                          | Idempotency check     |
  |                          |                        |
  |                          | TRANSACTION: create entry
  |                          |----------------------->|
  | {id, ok: true}           |                        |
  |<-------------------------|                        |
```

**Validations**:
- User is assigned to job (with active time window)
- Location is within geofence (adaptive radius: 75-250m + accuracy buffer)
- No other active entry exists (transactional guard)
- GPS accuracy acceptable (<50m for clock-in)
- Idempotency via `clientEventId` (retry-safe)

## Consequences

### Positive
1. **Security**: Clients cannot bypass geofence or forge entries
2. **Auditability**: Complete record of attempts (clockEvents) + outcomes (timeEntries)
3. **Flexibility**: Admin edits via `editTimeEntry` with audit trail
4. **Offline support**: Events can queue and replay when online
5. **Compliance**: Immutable approved/invoiced entries
6. **Performance**: Transactional guards prevent race conditions

### Negative
1. **Latency**: Network round-trip to function (2-4s typical)
   - Mitigation: Optimize function cold starts, use regional deployment
2. **Cost**: Function invocations per clock operation
   - Mitigation: Minimal compute, avg <200ms execution time
3. **Complexity**: Two collections instead of one
   - Mitigation: Clear separation of concerns, well-documented pattern

### Neutral
1. **Event collection growth**: Append-only `clockEvents` grows indefinitely
   - Plan: Implement TTL or archival in Month 2 (90-day retention)
2. **Idempotency tokens**: Clients must generate unique `clientEventId`
   - Pattern: Use UUID v4, store in queue for offline scenarios

## Alternative Considered

### Alternative 1: Client-Side Validation with Rules
**Approach**: Store geofence data in Firestore, compute distance in rules.

**Rejected Because**:
- Firestore rules cannot perform Haversine calculation
- Would require pre-computed distance matrices (not scalable)
- Cannot handle dynamic radius or accuracy buffers

### Alternative 2: Direct timeEntry Writes with Function Triggers
**Approach**: Allow clients to write timeEntries, validate with `onCreate` trigger.

**Rejected Because**:
- Window of time where invalid entry exists (before trigger runs)
- Cannot abort client write from trigger (trigger is async)
- Would require separate "pending" → "approved" status dance
- Harder to maintain audit trail

### Alternative 3: Hybrid Client/Function Validation
**Approach**: Client does rough check, function does final validation.

**Rejected Because**:
- Client code can be manipulated (rooted devices, modified APKs)
- Still need function-write-only for security
- Adds complexity without meaningful benefit

## Geofence Strategy

### Clock-In: Hard Gate
- **Deny** if outside geofence
- User cannot proceed without being at job site
- Clear error with distance and direction
- "Explain Issue" option for disputes

**Rationale**: Prevent workers from starting shifts before arriving at job.

### Clock-Out: Soft Gate
- **Allow** if outside geofence, but flag for review
- Set `geoOkOut: false`, add `exceptionTags: ["geofence_out"]`
- Warning message to user
- Surfaces in Admin Review exceptions

**Rationale**:
- Workers might legitimately leave job site before clocking out (equipment returns, etc.)
- Better to capture time with flag than block worker and risk unpaid hours
- Admin can review and approve/adjust later

### Adaptive Radius
```typescript
const baseRadius = Math.max(
  75,  // Minimum (urban safety)
  Math.min(job.radiusM ?? 100, 250)  // Cap at 250m
);
const effectiveRadius = baseRadius + Math.max(accuracy, 15);
```

**Rationale**:
- 75m minimum prevents overly strict enforcement
- 250m maximum prevents overly permissive zones
- Accuracy buffer accounts for GPS drift
- Per-job override via `job.radiusM`

## Edit & Audit Pattern

### Admin Edits
- Use `editTimeEntry` callable function
- Requires `editReason` (3-500 characters)
- Detects overlaps with other entries
- Creates audit record with before/after snapshot
- Resets `approved` flag if material changes

### Invoiced Entry Protection
- Once `invoiceId` is set, entry is "locked"
- Admin can force-edit with `force: true` flag
- Requires explicit audit reason
- Creates `forceEdit: true` audit flag

## Performance Characteristics

### Clock-In (Target: <2s)
```
Network RTT:     100-500ms
Function exec:   100-300ms
Firestore write: 50-100ms
-----------------------------
Total:          250-900ms
```

**Optimizations**:
- Idempotency check first (before expensive operations)
- Regional deployment (us-east4)
- Transaction minimizes round-trips

### Clock-Out (Target: <2s)
- Similar to clock-in
- Soft failure on geofence reduces validation complexity

### Auto Clock-Out (Target: <5s for 100 entries)
- Batch writes (100 per run)
- Runs every 15 minutes
- Idempotent (checks `clockOutAt == null`)

## References

- [Firestore Security Rules - Best Practices](https://firebase.google.com/docs/firestore/security/rules-structure)
- [Haversine Formula for Distance Calculation](https://en.wikipedia.org/wiki/Haversine_formula)
- [Idempotency in Distributed Systems](https://www.microsoft.com/en-us/research/publication/idempotence-is-not-a-medical-condition/)

## Review Notes

**Reviewed**: 2025-01-11
**Next Review**: 2025-03-01 (after 60 days of production data)

**Metrics to Track**:
- Clock-in success rate (target: >95%)
- False-positive geofence denials (target: <1%)
- Average latency (target: p95 <2s)
- Admin edit frequency (inform audit policy)
- Auto clock-out frequency (detect forgotten clock-outs)
