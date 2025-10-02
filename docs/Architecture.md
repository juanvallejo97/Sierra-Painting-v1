# Sierra Painting — Architecture Overview

> **Version:** 2.0.0-refactor  
> **Last Updated:** 2024  
> **Status:** Professional Skeleton (Refactored)

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Frontend Architecture (Flutter)](#frontend-architecture-flutter)
3. [Backend Architecture (Firebase)](#backend-architecture-firebase)
4. [Security Architecture](#security-architecture)
5. [Offline-First Strategy](#offline-first-strategy)
6. [Payment Architecture](#payment-architecture)
7. [Routing & RBAC](#routing--rbac)
8. [Observability & Monitoring](#observability--monitoring)
9. [Performance Targets](#performance-targets)
10. [CI/CD Pipeline](#cicd-pipeline)
11. [Data Flow Examples](#data-flow-examples)
12. [Technology Stack Summary](#technology-stack-summary)
13. [File Organization](#file-organization)
14. [Key Design Decisions](#key-design-decisions)
15. [Scalability](#scalability)
16. [Future Considerations](#future-considerations)
17. [Monitoring & Debugging](#monitoring--debugging)

---

# Architecture Overview

## System Architecture

Sierra Painting follows a modern, mobile-first architecture with offline-first capabilities and a Firebase backend.

### High-Level Architecture

┌─────────────────────────────────────────────────────────┐
│ Flutter App (Dart) │
│ ┌─────────────┐ ┌──────────────┐ ┌───────────────┐ │
│ │ UI │ │ Business │ │ Data Layer │ │
│ │ (Widgets) │→ │ Logic │→ │ (Services) │ │
│ └─────────────┘ └──────────────┘ └───────────────┘ │
│ ↓ ↓ ↓ │
│ ┌──────────────────────────────────────────────────┐ │
│ │ Offline Storage / Queue (Hive) │ │
│ └──────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────┘
│
Internet
│
┌────────────────────────┴────────────────────────────────┐
│ Firebase Backend │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ Auth │ │ Firestore │ │ Storage │ │
│ └──────────────┘ └──────────────┘ └──────────────┘ │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ Functions │ │ App Check │ │ Remote Config│ │
│ │ (TypeScript) │ │ │ │ (Feat Flags) │ │
│ └──────────────┘ └──────────────┘ └──────────────┘ │
└─────────────────────────────────────────────────────────┘
│
(Optional)
│
┌───────┴────────┐
│ Stripe API │
└─────────────────┘


---

## Frontend Architecture (Flutter)

### Layer Structure



lib/
├── main.dart # Entry point
├── app/
│ ├── app.dart # MaterialApp setup
│ └── router.dart # go_router + RBAC guards
├── core/
│ ├── config/ # firebase_options.dart, theme_config.dart
│ ├── services/ # feature_flag_service.dart, offline_service.dart
│ ├── providers/ # Riverpod providers (global DI)
│ ├── utils/ # Helpers
│ └── constants/ # Constants / keys
├── features/ # Feature modules (vertical slices)
│ ├── auth/
│ ├── timeclock/
│ ├── estimates/
│ ├── invoices/
│ ├── payments/
│ └── admin/
└── shared/
├── widgets/ # Reusable UI
└── models/ # Shared models


### State Management
- **Riverpod** for reactive state and DI.
- Feature-specific state lives within feature modules; global cross-cutting providers in `core/providers`.

---

## Backend Architecture (Firebase)

### Cloud Functions Structure



functions/
├── src/
│ ├── index.ts # Main exports
│ ├── schemas/ # Zod schemas
│ ├── services/ # Business helpers (e.g., pdf-service.ts)
│ ├── stripe/ # Stripe integration
│ │ └── webhookHandler.ts # Webhook processing
│ └── utils/ # Utilities (logging, auth checks)
├── package.json
├── tsconfig.json
└── .eslintrc.js


### Function Types
1. **HTTP**
   - `healthCheck`
   - `stripeWebhook` (optional; idempotent, signature-verified)
2. **Callable**
   - `markPaymentPaid` (admin-only, manual payments)
3. **Triggers**
   - `onUserCreate` (provision user profile)
   - `onUserDelete` (cleanup)

---

## Security Architecture

### Firestore Security Rules (Deny-by-Default)



Default: DENY ALL

users:
read: request.auth != null
write: isAdmin(request.auth) && !changingProtectedFields()

projects, estimates, invoices, payments:
read: request.auth != null
create/update: role-based checks (admin/crew lead/crew)
✗ client cannot set invoice.paid / paidAt

audit_logs:
read: isAdmin(request.auth)
write: functions-only


### Storage Security Rules



Default: DENY ALL

Authenticated:

Upload profile images (<10MB)

Read images

Admins:

Upload project images (<10MB)

Upload invoice PDFs (<10MB)


---

## Offline-First Strategy



User Action
↓
[Optimistic UI Update]
↓
[Save to Local Cache (Hive)]
↓
[Enqueue for Sync]
↓
If Online → Sync to Firestore → Update Cache → Confirm UI
If Offline → Keep in Pending Queue → Auto-sync on reconnect


---

## Payment Architecture

### Manual Payment (Check/Cash)


Admin creates invoice in Firestore

Customer pays check/cash

Admin calls markPaymentPaid (callable)

Validates admin role

Creates payment record

Adds audit log

Updates invoice status


### Stripe Payment (Optional; behind Remote Config)


Admin creates invoice

Customer selects "Pay with Stripe"

App creates Checkout session

Stripe redirects back after payment

stripeWebhook verifies & updates invoice (idempotent)


---

## Routing & RBAC

- **go_router** with **route guards**:
  - Redirect unauthenticated users to `/login`
  - Restrict admin screens via user role from `authStateProvider` + user profile
- **Example Guard Flow**


User taps Admin
→ check auth
→ unauth? redirect /login
→ check role (isAdmin)
→ not admin? redirect /timeclock
→ admin? allow


---

## Observability & Monitoring

- **Crashlytics**: crash reporting
- **Performance Monitoring**: screen/network traces
- **Analytics**: feature usage, funnels
- **Structured Logs** (Functions): entity, action, actor, orgId

**Key Metrics**
- App startup time, screen transition time
- API response time, offline sync latency
- Crash-free users, function error rates
- Payment success, feature adoption

---

## Performance Targets

- **Mobile**: P95 < **2.0s** on critical flows
- **Functions**: cold start mitigations (min instances on hot paths)
- **PDF Gen**: ≤ **10s**

**Strategies**
- Lazy image loading; pagination
- Cache-first reads, network-first writes
- Indexed queries; snapshot listeners where appropriate
- Background sync; optimistic updates

---

## CI/CD Pipeline



GitHub Actions

On PR:

Flutter: format, analyze, test

Functions: lint, build

Build APK (debug) as artifact

On main:

Build Functions

Deploy to Staging:
• Functions
• Firestore Rules
• Storage Rules

On tag v*:

Build Flutter release (APK + AAB)

Build Functions

Deploy to Production

Upload artifacts (release)


---

## Data Flow Examples

### 1) User Authentication Flow


Login Screen
→ Firebase Auth (email/password)
→ authStateProvider (Riverpod StreamProvider)
→ go_router redirects based on auth/role
→ Navigate to Timeclock


### 2) Create Estimate with PDF


Estimate Screen
→ call createEstimatePdf (Callable/HTTP)
→ Zod validate
→ Generate PDF (PDFKit)
→ Upload to Storage
→ Create estimate doc in Firestore
→ Return signed URL
→ Display URL


### 3) Mark Invoice Paid (Manual)


Admin Screen
→ call markPaymentPaid
→ verify admin
→ Zod validate payload
→ Firestore transaction:
- set invoice.paid = true
- create audit_log entry
→ success response


### 4) Offline Operation


Create invoice while offline
→ enqueue (Hive)
→ show "Queued for sync"
Reconnect
→ QueueService processes items
→ write to Firestore
→ mark processed & notify "Synced"


---

## Technology Stack Summary

| Layer                | Technology                    | Purpose                                |
|--------------------- |------------------------------ |----------------------------------------|
| UI Framework         | Flutter (Material 3)          | Cross-platform mobile UI               |
| State Management     | Riverpod                      | Reactive state & DI                    |
| Routing              | go_router                     | Declarative routing + guards           |
| Local Storage        | Hive                          | Offline queue/cache                    |
| Backend (BaaS)       | Firebase                      | Auth, Firestore, Storage, Functions    |
| Functions Language   | TypeScript + Zod              | Type-safe backend & validation         |
| PDF Generation       | PDFKit                        | Server-side PDFs                       |
| Payments (optional)  | Stripe                        | Card payments                          |
| CI/CD                | GitHub Actions                | Build, test, deploy                    |

---

## File Organization

### Flutter App


lib/
├── main.dart
├── firebase_options.dart
├── app/
│ ├── app.dart
│ └── router.dart
├── core/
│ ├── models/
│ ├── providers/
│ ├── services/
│ ├── utils/
│ └── constants/
└── features/
├── auth/ (data, domain, presentation)
├── timeclock/ (data, domain, presentation)
├── estimates/ (data, domain, presentation)
├── invoices/ (data, domain, presentation)
└── admin/ (data, domain, presentation)


### Cloud Functions


functions/
├── src/
│ ├── index.ts
│ ├── schemas/
│ ├── services/
│ ├── stripe/
│ └── utils/
├── package.json
├── tsconfig.json
└── .eslintrc.js


---

## Key Design Decisions

1. **Feature-based architecture** (vertical slices)
2. **Clean separation** of data / domain / presentation
3. **RBAC** enforced at router + server rules
4. **Offline-first** with local queue and automatic sync
5. **Server-side PDFs** for consistency and security
6. **Audit trail** for sensitive ops
7. **Type safety** in Flutter (Dart) & Functions (TS + Zod)
8. **Environment separation** (staging / prod)
9. **CI/CD automation** with pre-merge tests and tag-based releases

---

## Scalability

**Supported Today**
- 10,000+ concurrent users (subject to Firebase quotas)
- Auto-scaling Functions & Storage
- Global CDN for assets

**Strategies**
- Horizontal scaling (managed by Firebase)
- Data partitioning by collections
- Composite indexes for complex queries
- CDN + local caching

---

## Future Considerations

- Multi-tenant org model
- Real-time collaboration (admin/admin)
- Advanced analytics / BI (BigQuery exports)
- Push notifications
- Internationalization
- Conflict resolution UI for offline edits
- Background sync workers
- Additional caching on hot data

---

## Monitoring & Debugging

**Development**
- Firebase Emulator UI (localhost:4000)
- Flutter DevTools
- Hot reload

**Production**
- Firebase Console (logs, traces)
- Functions logs with structured fields
- Firestore usage metrics
- Auth audit logs

---

This architecture provides a solid, production-ready foundation with strong security, scalability, and maintainability, while enabling rapid delivery for the MVP and beyond.