# ADR-0001: Technology Stack Selection

**Status:** Accepted  
**Date:** 2024-01-15  
**Deciders:** Engineering Team  
**Tags:** architecture, stack, mobile, backend  
**Context:** Need to select a technology stack for a small business painting management application

---

## Context and Problem Statement

We need to build a mobile-first application for a small painting business to manage operations (estimates, invoices, time tracking). The solution must be:

- **Mobile-first** with potential web support
- **Offline-capable** to work in areas with poor connectivity
- **Cross-platform** (iOS and Android)
- **Fast development** (target MVP in ~4 weeks)
- **Cost-effective** for a small business
- **Secure** with proper authentication, authorization, and data protection
- **Maintainable** by a small team
- **Scalable** to support growth without heavy infra management

## Decision Drivers

- Developer velocity and single codebase
- Serverless backend with low ops overhead
- Offline-first architecture and sync
- Strong type safety (Dart/TypeScript)
- Ecosystem maturity and community support
- Pay-as-you-go pricing fit for small business
- Built-in security features (Security Rules, App Check)

## Considered Options

1. **Flutter + Firebase** (**selected**)
2. React Native + AWS (Amplify/Cognito/DynamoDB/Lambda)
3. Native iOS (Swift) & Android (Kotlin) + custom Node/Postgres backend

---

## Decision Outcome

**Chosen option:** **Flutter + Firebase**

### Frontend: Flutter

**Pros**
- Single codebase for iOS/Android (+ Web potential)
- Excellent dev experience (hot reload), strong Material Design 3 support
- Great runtime performance (AOT to native)
- Accessibility features built-in
- Healthy plugin ecosystem
- Good offline patterns (e.g., Hive/Drift for local cache/queue)

**Cons**
- Dart learning curve
- Larger binary size than fully native
- Some edge cases require platform channels/plugins

**Why not React Native?**
- Avoids JS–native bridge complexity; smoother animations
- Strong typing via Dart without additional tooling
- Generally better offline story with fewer moving parts

**Why not fully Native?**
- Doubles effort and slows iteration
- Requires two specialized codebases and skill sets

### Backend: Firebase

**Services**
- **Auth** (secure user management)
- **Cloud Firestore** (real-time NoSQL with offline persistence)
- **Cloud Functions (TypeScript + Zod)** for business logic and webhooks
- **Storage** for images/PDFs (CDN-backed)
- **App Check** to mitigate abuse
- **Crashlytics & Performance Monitoring** for observability
- **Remote Config** for feature flags

**Pros**
- Serverless, autoscaling, minimal ops
- Security Rules for data-level authorization
- Pay-as-you-go; generous free tier
- Tight Flutter integrations and tooling

**Cons / Mitigations**
- Vendor lock-in → **Mitigate** via repository/service abstractions
- Query limits (no JOINs) → **Mitigate** with data modeling & indexes; export to BigQuery for reporting
- Potential cost spikes at scale → **Mitigate** with usage monitoring, caching, budget alerts

### Payments

- **Primary:** Manual check/cash with admin approval (fits current business)
- **Optional:** Stripe Checkout behind Remote Config flag
- **Rationale:** Meets current workflows while enabling card payments when ready

### State Management & Routing

- **State:** **Riverpod**
  - Compile-time safety, testability, flexible DI, code-gen support
  - Chosen over Bloc (less boilerplate for our scope)
- **Routing:** **go_router**
  - Declarative, deep linking, type-safe navigation, RBAC-friendly

---

## Pros and Cons Summary

**Pros**
- ✅ Single codebase, rapid delivery (4-week MVP feasible)
- ✅ Offline support is battle-tested (Firestore persistence)
- ✅ Minimal ops with serverless backend
- ✅ Strong security posture via Security Rules & App Check
- ✅ Type safety across app and functions
- ✅ Excellent tooling and ecosystem

**Cons**
- ⚠️ Vendor lock-in (Firebase)
- ⚠️ NoSQL modeling complexity
- ⚠️ Cold starts for Functions (mitigate with min instances on critical paths)

---

## Consequences

**Positive**
1. Fast MVP with reduced complexity and cost
2. Reliable offline experience for field crews
3. Secure-by-default access controls at the data layer
4. Seamless scale without infra maintenance

**Negative & Mitigations**
1. Lock-in → repository pattern, modular adapters
2. Query limitations → denormalization, background aggregations, BigQuery exports (V3+)
3. Future costs → telemetry + budget alerts, index hygiene, query optimization

---

## Risks

1. **Pricing variability** if usage spikes  
   _Mitigation:_ Budget alerts, Remote Config throttles, rate limiting
2. **Complex reporting** beyond Firestore’s query model  
   _Mitigation:_ BigQuery exports, scheduled aggregations
3. **Device/platform edge cases**  
   _Mitigation:_ Broad device testing, CI on emulators/simulators

---

## Implementation Notes

### Architecture & Code Organization


- **Repository/Service pattern:** All Firebase calls flow through service layers (e.g., `AuthService`, `FirestoreService`) to enable future migration.
- **Clean Architecture:** Separate presentation, domain, and data layers.

### Offline Strategy

- Local cache & write-ahead queue (Hive/Drift) for robust offline writes
- Conflict policy and retry/backoff logic on reconnect

### Cloud Functions (TypeScript + Zod)

- Input validation with Zod schemas
- Idempotency keys for payment and critical actions
- Structured logging (entity, action, actor, orgId)
- Error taxonomy for predictable client handling

### Security Posture

- **Deny by default** Firestore Rules
- Role-based access (admin/crew lead/crew)
- Prevent client writes to protected fields (e.g., `invoice.paid`, `invoice.paidAt`)
- App Check enforced for callable functions
- Audit logs for payment operations

### Testing Strategy

- Unit tests for domain logic (no Firebase)
- Integration tests with Firebase emulators
- Widget tests for UI
- E2E for critical flows
- Rules tests (emulator) for Security Rules
- Functions tests (emulator)

### Performance Targets

- P50 < 1s, **P95 < 2.5s** for critical screens/calls
- PDF generation ≤ 10s

### Observability

- Crashlytics for crash reports
- Performance Monitoring for traces
- Analytics for adoption/behavior
- JSON structured logs for serverless

---

## Alternatives Considered

- **React Native + AWS:** Flexible but higher setup complexity and steeper learning curve for small team velocity
- **Native + Custom Backend:** Maximum control/perf but doubles app dev effort and adds infra burden

## Related Decisions

- ADR-0002: Offline-First Architecture  
- ADR-0003: Manual Payments as Primary  
- ADR-0004: TypeScript + Zod for Cloud Functions

## References

- [Flutter Documentation](https://flutter.dev/docs)  
- [Firebase Documentation](https://firebase.google.com/docs)  
- [Riverpod Documentation](https://riverpod.dev)  
- [go_router Package](https://pub.dev/packages/go_router)  
- [Zod](https://zod.dev/)

## Superseded By

None (current decision)

---

> **Note:** ADRs are immutable. Revisions require a new ADR that supersedes this one.


