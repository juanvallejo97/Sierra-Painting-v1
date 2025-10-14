# System architecture

Sierra Painting is a mobile-first painting business management application built with Flutter and
Firebase. This document explains the high-level system architecture and design.

## Overview

The system uses a three-tier architecture:

1. **Frontend**: Flutter mobile app with offline-first capabilities
2. **Backend**: Firebase serverless services (Auth, Firestore, Functions, Storage)
3. **Integration**: Optional third-party services (Stripe for payments)

## System diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                   │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │     UI      │→ │   Business   │→ │  Data Layer   │  │
│  │  (Widgets)  │  │    Logic     │  │  (Services)   │  │
│  └─────────────┘  └──────────────┘  └───────────────┘  │
│         ↓                ↓                  ↓           │
│  ┌──────────────────────────────────────────────────┐  │
│  │        Offline Storage / Queue (Hive)            │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │
                    Internet
                         │
┌────────────────────────┴────────────────────────────────┐
│                  Firebase Backend                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │     Auth     │  │  Firestore   │  │   Storage    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Functions   │  │  App Check   │  │Remote Config │  │
│  │ (TypeScript) │  │              │  │(Feat Flags)  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                         │
                   (Optional)
                         │
                 ┌───────┴────────┐
                 │   Stripe API   │
                 └────────────────┘
```

## Frontend architecture

The Flutter app follows a layered architecture:

- **Presentation layer**: UI widgets and screens
- **Business logic layer**: State management with Riverpod
- **Data layer**: Services that communicate with Firebase or local storage

### Offline-first design

The app works offline by default:

1. User actions are queued locally in Hive
2. Changes sync to Firestore when connectivity is restored
3. Optimistic updates provide immediate feedback

See [Offline-first design](offline-first.md) for details.

## Backend architecture

Firebase provides the backend infrastructure:

- **Authentication**: User sign-in with email/password and role-based access control (RBAC)
- **Firestore**: NoSQL database for storing jobs, invoices, time entries
- **Cloud Functions**: Server-side logic for PDF generation, payments, lead processing
- **Storage**: File storage for PDFs and images
- **App Check**: Protection against abuse
- **Remote Config**: Feature flags for progressive rollout

### Security model

All Firebase services use deny-by-default security rules. Access is explicitly granted based on:

- User authentication state
- User role (admin, manager, worker)
- Resource ownership

See [Security model](security-model.md) for details.

## Key design decisions

- **Offline-first**: Mobile workers often have poor connectivity
- **Manual payments primary**: Most customers pay by check or cash
- **Feature flags**: Enable gradual rollout and quick rollback
- **Story-driven development**: Each feature tied to user stories with acceptance criteria

See [Architecture Decision Records](../adrs/) for detailed rationale.

## Performance characteristics

Target metrics (P95):

- Sign-in: ≤ 2.5s
- Clock-in (online): ≤ 2.5s
- Jobs today load: ≤ 2.0s
- Offline sync: ≤ 5s per item
- PDF generation: ≤ 10s

## Scalability

Current design supports:

- Up to 100 concurrent users
- Up to 1000 jobs per month
- Up to 10,000 time entries per month

For larger scale, consider:

- Sharding Firestore collections
- Cloud Run for CPU-intensive tasks
- CDN for static assets

## Next steps

- [Understand offline-first design](offline-first.md)
- [Learn about security model](security-model.md)
- [Review Architecture Decision Records](../adrs/)
