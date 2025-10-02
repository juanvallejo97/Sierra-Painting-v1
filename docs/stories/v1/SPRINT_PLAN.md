# Sprint V1 - MVP Foundation

**Goal**: Establish secure authentication, time tracking core, and observability foundation.

**Duration**: 2-3 weeks

**Priority**: All P0 (must-ship)

## Stories in Sprint

### Epic A: Authentication & RBAC (BLOCKING)
- ✅ **A1**: Sign-in/out + reliable sessions (Est: S, Risk: M)
- ✅ **A2**: Admin sets roles (claims) (Est: S, Risk: M)  
- ⚠️ **A5**: App Check enforcement (Est: S, Risk: M)

### Epic B: Time Clock (CORE FEATURE)
- 🔄 **B1**: Clock-in (offline + GPS) (Est: M, Risk: M)
- 📋 **B2**: Clock-out + overlap guard (Est: M, Risk: M)
- 📋 **B3**: Jobs Today (assigned only) (Est: S, Risk: L)
- 📋 **B4**: Location permission UX (Est: S, Risk: L)

### Epic E: Operations & Observability (FOUNDATION)
- 📋 **E1**: CI/CD gates (Est: M, Risk: L)
- 📋 **E2**: Rules tests (emulator) - Initial (Est: M, Risk: M)
- 📋 **E3**: Telemetry + Audit Log (Est: S, Risk: L)

**Legend**:
- ✅ Complete
- 🔄 In Progress  
- 📋 To Do
- ⚠️ Blocked/At Risk

## Cut Line Strategy

### Must Ship
- A1, A2, A5: Authentication foundation
- B1, B2: Core clock-in/out functionality
- E1, E3: CI/CD and basic telemetry

### Can Defer if Tight
- B4: Can ship with minimal copy, polish later
- B3: Can show "all jobs" instead of filtered initially
- E2: Can ship with minimal rules tests, expand in V2

### Cannot Defer
- A1, A2, A5: Security foundation is non-negotiable
- B1, B2: Time tracking is the core MVP feature
- E1: CI/CD prevents broken deployments

## Dependencies

```
A1 (Sign-in) ──┬──> B1 (Clock-in)
               │
               ├──> B2 (Clock-out)
               │
               ├──> B3 (Jobs Today)
               │
               └──> B4 (Location UX)

A2 (Roles) ────┴──> E2 (Rules tests need role checks)

A5 (App Check) ───> B1 (API protection)

E1 (CI/CD) ────────> All (blocks bad deploys)

E2 (Rules) ────────> All (security validation)

E3 (Telemetry) ────> B1, B2 (event tracking)
```

## Definition of Ready (Sprint Level)

- [x] All P0 stories have acceptance criteria
- [x] Dependencies identified and ordered
- [x] Schemas defined in `functions/src/schemas/`
- [x] Firestore rules drafted
- [x] UI wireframes reviewed (if applicable)
- [ ] Test users created in Firebase Auth
- [ ] Staging environment configured
- [ ] Performance targets documented

## Definition of Done (Sprint Level)

- [ ] All must-ship stories complete
- [ ] Unit tests pass (≥80% coverage)
- [ ] Integration tests pass (emulator)
- [ ] E2E critical path passes (sign-in → clock-in → clock-out)
- [ ] Firestore rules deployed to staging
- [ ] Functions deployed to staging
- [ ] CI/CD pipeline green
- [ ] Performance targets met (P95 ≤ 2.5s for critical ops)
- [ ] Demo completed with product owner
- [ ] Sprint retrospective documented

## Acceptance Criteria (Sprint)

### Sign-in Flow (A1)
**GIVEN** I open the app  
**WHEN** I enter valid credentials  
**THEN** I see Jobs Today screen within 2 seconds

### Clock-in Flow (B1)
**GIVEN** I am signed in and assigned to Job A  
**WHEN** I tap "Clock In"  
**THEN** I am clocked in within 2.5 seconds (online)  
**OR** I see "Pending Sync" chip (offline)

### Clock-out Flow (B2)
**GIVEN** I have an open clock-in  
**WHEN** I tap "Clock Out"  
**THEN** my shift is closed with accurate hours

### End-to-End (Critical Path)
**GIVEN** I am a painter with the mobile app  
**WHEN** I sign in, navigate to Jobs Today, clock in, work, and clock out  
**THEN** my time entry appears in admin dashboard accurately

## Risks & Mitigations

### Risk: Offline sync complexity
**Likelihood**: Medium  
**Impact**: High (core feature)  
**Mitigation**:
- Use Hive for local queue (proven library)
- Test offline scenarios early
- Idempotency prevents duplicates
- Start with simple queue, iterate

### Risk: GPS permission denial
**Likelihood**: Medium  
**Impact**: Low (can proceed without)  
**Mitigation**:
- Clock-in not blocked by GPS denial
- Clear rationale in permission dialog
- Flag entries with `gpsMissing=true`
- Admin can review later

### Risk: App Check setup complexity
**Likelihood**: Low  
**Impact**: High (security)  
**Mitigation**:
- Debug token for emulator/staging
- Documentation in `docs/APP_CHECK.md`
- Test early with real devices

### Risk: Performance targets not met
**Likelihood**: Low  
**Impact**: Medium  
**Mitigation**:
- Optimistic UI for instant feedback
- Firestore offline persistence
- Monitor with Firebase Performance
- Load test with emulator

## Testing Strategy

### Unit Tests (≥80% coverage)
- Zod schema validation
- Helper functions (auth checks, org scoping)
- Idempotency key generation
- Queue item serialization

### Integration Tests (Emulator)
- Sign-in with valid/invalid credentials
- Clock-in creates entry in Firestore
- Clock-out updates existing entry
- Duplicate clock-in prevented
- Firestore rules enforce permissions

### E2E Tests (Flutter Integration)
- Cold start → sign-in → Jobs Today (≤2s)
- Clock-in online → confirmation (≤2.5s)
- Clock-in offline → sync on reconnect
- GPS permission grant/deny flows

## Performance Targets

| Operation | Target (P95) | Metric |
|-----------|--------------|--------|
| Sign-in | ≤ 2.5s | Auth + Firestore read |
| Clock-in (online) | ≤ 2.5s | Callable function roundtrip |
| Clock-out | ≤ 2.5s | Callable function roundtrip |
| Jobs Today load | ≤ 2.0s | Firestore query + render |
| Offline sync | ≤ 5s per item | Queue processing |

## Rollback Plan

If critical issues arise:

1. **Auth issues**: Revert `firestore.rules` and redeploy
2. **Function errors**: Rollback via Firebase Console → Functions → Rollback
3. **Flutter crash**: Revert to last stable commit, rebuild APK
4. **Data corruption**: Restore from Firestore daily backup

## Sprint Retrospective Template

### What Went Well
- Item 1
- Item 2

### What Could Improve
- Item 1
- Item 2

### Action Items
- [ ] Action 1 (Owner: X)
- [ ] Action 2 (Owner: Y)

### Metrics
- Stories completed: X/Y
- Bugs found: X
- Performance: Met/Not Met
- Test coverage: X%

## Next Sprint Preview (V2)

Focus shifts to **invoicing and manual payments**:
- C1: Create quote + PDF
- C2: Quote → Invoice
- C3: Manual mark-paid
- B5: Auto clock-out safety
- B7: My timesheet (weekly)

Cut line: Ship C1-C3, defer B7 if tight.
