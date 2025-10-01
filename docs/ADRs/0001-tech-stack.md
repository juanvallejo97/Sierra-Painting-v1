# ADR-0001: Technology Stack Selection

**Status:** Accepted  
**Date:** 2024-01-15  
**Deciders:** Engineering Team  
**Context:** Need to select a technology stack for a small business painting management application

## Context and Problem Statement

We need to build a mobile-first application for a small painting business to manage operations, estimates, invoices, and time tracking. The solution must be:
- **Mobile-first** with potential web support
- **Offline-capable** to work in areas with poor connectivity
- **Cost-effective** for a small business
- **Secure** with proper authentication and authorization
- **Maintainable** by a small team

## Decision Drivers

- **Developer velocity**: Ability to build for multiple platforms quickly
- **Firebase ecosystem**: Serverless backend, authentication, database, storage
- **Offline-first architecture**: Critical for field work
- **Type safety**: Reduce runtime errors
- **Community support**: Large ecosystem and plugins
- **Cost**: Pay-as-you-go pricing suitable for small business
- **Security**: Built-in security features (App Check, Security Rules)

## Considered Options

1. **Flutter + Firebase** (selected)
2. React Native + Firebase
3. Native iOS/Android + custom backend

## Decision Outcome

**Chosen option:** Flutter + Firebase

### Frontend: Flutter
- **Single codebase** for iOS, Android, and Web
- **Material Design 3** with excellent accessibility support
- **Hot reload** for rapid development
- **Strong type safety** with Dart
- **Excellent performance** (compiled to native code)
- **Hive** for local storage and offline-first architecture

### Backend: Firebase
- **Firebase Authentication**: Secure user management
- **Cloud Firestore**: NoSQL database with offline persistence and real-time sync
- **Cloud Functions**: TypeScript serverless functions with Zod validation
- **Firebase Storage**: Secure file storage for PDFs and images
- **Firebase App Check**: Protection against abuse
- **Firebase Remote Config**: Feature flags (e.g., Stripe payments)
- **Crashlytics & Performance Monitoring**: Built-in observability

### Payments
- **Primary**: Manual check/cash payments with admin approval
- **Optional**: Stripe Checkout behind feature flag
- **Rationale**: Most painting businesses use check/cash; Stripe is optional for those ready to adopt card payments

### Security Posture
- **Firestore Rules**: Deny-by-default
- **Client restrictions**: Cannot set `invoice.paid` or `invoice.paidAt`
- **Role-Based Access Control**: Admin, Crew Lead, Crew roles
- **App Check**: Enforced for callable functions
- **Audit logging**: All payment operations logged immutably

## Pros and Cons

### Pros
- ✅ Single codebase for multiple platforms (reduces development time by ~60%)
- ✅ Firebase's generous free tier suitable for small business
- ✅ Built-in offline support in Firestore
- ✅ Security rules enforce authorization at database level
- ✅ Serverless functions scale automatically
- ✅ Type safety in both Dart (Flutter) and TypeScript (Functions)
- ✅ Excellent tooling and IDE support

### Cons
- ⚠️ Vendor lock-in to Firebase ecosystem
- ⚠️ Learning curve for Firestore's NoSQL data modeling
- ⚠️ Cold start times for Cloud Functions (mitigated with min instances for critical functions)

## Implementation Notes

### Flutter Architecture
- **Clean Architecture**: Separation of data, domain, and presentation layers
- **Feature-based structure**: Each feature is self-contained
- **Offline queue**: Hive-backed queue for writes when offline
- **Accessibility**: WCAG 2.2 AA compliance (48x48 touch targets, semantic labels, text scaling)

### Cloud Functions Architecture
- **Zod validation**: All inputs validated with Zod schemas
- **Idempotency**: Payment functions use idempotency keys
- **Structured logging**: Entity, action, actor, orgId for every operation
- **Error taxonomy**: Proper error codes for client handling

### Performance Targets
- **P50 < 1s** for API calls
- **P95 < 2.5s** for API calls
- **PDF generation ≤ 10s**

### Observability
- **Firebase Crashlytics**: Crash reporting
- **Firebase Performance Monitoring**: Screen load times, network traces
- **Firebase Analytics**: User behavior and feature adoption
- **Structured logging**: JSON logs with consistent schema

## Links
- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Zod Schema Validation](https://zod.dev/)
