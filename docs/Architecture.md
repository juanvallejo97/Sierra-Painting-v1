# Sierra Painting - Architecture Overview

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
7. [Observability & Monitoring](#observability--monitoring)
8. [Performance Targets](#performance-targets)
9. [File Organization](#file-organization)
10. [Key Design Decisions](#key-design-decisions)

---

# Architecture Overview

## System Architecture

Sierra Painting follows a modern, mobile-first architecture with offline-first capabilities and Firebase backend.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter App (Dart)                    │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │     UI      │  │    Business  │  │   Data Layer  │  │
│  │  (Widgets)  │→ │     Logic    │→ │   (Services)  │  │
│  └─────────────┘  └──────────────┘  └───────────────┘  │
│         ↓                ↓                   ↓          │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Offline Storage (Hive)                   │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │
                    Internet
                         │
┌────────────────────────┴────────────────────────────────┐
│                  Firebase Backend                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │     Auth     │  │   Firestore  │  │   Storage    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Functions   │  │  App Check   │  │ Remote Config│  │
│  │ (TypeScript) │  │              │  │ (Feat Flags) │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                         │
                    (Optional)
                         │
                 ┌───────┴────────┐
                 │  Stripe API    │
                 └────────────────┘
```

## Frontend Architecture (Flutter)

### Layer Structure

```
lib/
├── main.dart                    # App entry point
├── core/                        # Core functionality
│   ├── config/                  # Configuration
│   │   ├── firebase_options.dart
│   │   └── theme_config.dart
│   ├── services/                # Core services
│   │   ├── feature_flag_service.dart
│   │   └── offline_service.dart
│   └── utils/                   # Utility functions
├── features/                    # Feature modules
│   ├── auth/                    # Authentication feature
│   ├── projects/                # Projects management
│   ├── payments/                # Payment processing
│   └── invoices/                # Invoice management
└── shared/                      # Shared components
    ├── widgets/                 # Reusable widgets
    └── models/                  # Data models
```

### State Management

- **Provider** pattern for dependency injection and state management
- Services are provided at the app level
- Feature-specific state managed within feature modules

### Offline-First Architecture

```
User Action
    ↓
[Optimistic Update to UI]
    ↓
[Save to Local Cache (Hive)]
    ↓
[Queue Sync Operation]
    ↓
[Check Network Status]
    ↓
If Online:
    ↓
[Sync to Firebase]
    ↓
[Update Local Cache]
    ↓
[Confirm to UI]

If Offline:
    ↓
[Keep in Pending Queue]
    ↓
[Auto-sync when online]
```

## Backend Architecture (Firebase)

### Cloud Functions Structure

```
functions/
├── src/
│   ├── index.ts                 # Main exports
│   ├── stripe/                  # Stripe integration
│   │   └── webhookHandler.ts   # Webhook processing
│   └── utils/                   # Utility functions
├── package.json
└── tsconfig.json
```

### Function Types

1. **HTTP Functions**
   - `stripeWebhook`: Handles Stripe webhook events (idempotent)
   - `healthCheck`: Health check endpoint

2. **Callable Functions**
   - `markPaymentPaid`: Admin function to mark manual payments

3. **Trigger Functions**
   - `onUserCreate`: Creates user profile on signup
   - `onUserDelete`: Cleans up user data on deletion

### Security Model

#### Firestore Security Rules (Deny-by-Default)

```
Default: DENY ALL

Authenticated Users Can:
- Read own profile
- Update own profile (except role)
- Read projects
- Read own payments/invoices

Admins Can:
- Create/Update/Delete projects
- Create/Update payments
- Create/Update invoices
- Manage users
```

#### Storage Security Rules

```
Default: DENY ALL

Authenticated Users Can:
- Upload profile images (<10MB)
- Read all images

Admins Can:
- Upload project images (<10MB)
- Upload invoice PDFs (<10MB)
```

## Data Flow

### Payment Processing Flow

#### Manual Payment (Check/Cash)

```
1. Admin creates invoice in Firestore
2. Customer receives notification
3. Customer pays with check/cash
4. Admin marks payment as paid via callable function
   ↓
   - Validates admin role
   - Creates payment record
   - Adds audit log entry
   - Updates invoice status
5. Customer sees updated status
```

#### Stripe Payment (Optional)

```
1. Admin creates invoice in Firestore
2. Customer clicks "Pay with Stripe"
3. Flutter app creates Stripe Checkout session
4. Customer completes payment on Stripe
5. Stripe sends webhook to Cloud Function
   ↓
   - Verifies webhook signature
   - Checks idempotency (event ID)
   - Creates payment record
   - Updates invoice status
6. Customer sees updated status
```

## Authentication Flow

```
1. User signs up with email/password
   ↓
2. Firebase Auth creates user
   ↓
3. onUserCreate function triggers
   ↓
4. Creates user profile in Firestore
   ↓
5. User can now access app
```

## Feature Flag System

```
App Startup
    ↓
[Initialize Remote Config]
    ↓
[Fetch feature flags]
    ↓
[Cache locally]
    ↓
[App uses flags to enable/disable features]

Examples:
- stripe_enabled: false → Show only manual payment
- stripe_enabled: true → Show Stripe option
- offline_mode_enabled: true → Enable offline sync
```

## Accessibility Architecture

### WCAG 2.2 AA Compliance

1. **Visual Design**
   - Minimum contrast ratio 4.5:1 for text
   - Minimum contrast ratio 3:1 for UI components
   - Large text (18pt+) minimum 3:1

2. **Touch Targets**
   - Minimum 48x48 logical pixels
   - Adequate spacing between interactive elements

3. **Text Scaling**
   - Support up to 200% text scaling
   - App limits to 130% to maintain usability
   - Layouts adapt to text size changes

4. **Semantic Labels**
   - All interactive elements have labels
   - Images have meaningful descriptions
   - Form fields have proper labels

5. **Screen Reader Support**
   - Proper heading hierarchy
   - Meaningful focus order
   - Status messages announced

## Performance Considerations

### Mobile Performance

- **Target**: P95 < 2 seconds for critical operations
- **Optimization strategies**:
  - Lazy loading of images
  - Pagination for lists
  - Local caching
  - Optimistic updates
  - Background sync

### Offline Performance

- **Instant UI updates**: Don't wait for network
- **Background sync**: Sync when network available
- **Conflict resolution**: Last-write-wins strategy
- **Cache strategy**: Cache-first for reads, network-first for writes

### Firebase Performance

- **Firestore**: Indexed queries for fast reads
- **Functions**: Cold start optimization with keep-warm
- **Storage**: CDN for fast image delivery
- **App Check**: Minimal latency impact

## Scalability

### Current Architecture Supports

- **Users**: 10,000+ concurrent users
- **Firestore**: Unlimited reads/writes (subject to quotas)
- **Functions**: Auto-scaling based on load
- **Storage**: Unlimited storage (paid)

### Scaling Strategies

1. **Horizontal Scaling**: Firebase handles automatically
2. **Data Partitioning**: Collection-based partitioning
3. **Caching**: Local + CDN caching
4. **Indexing**: Composite indexes for complex queries

## Monitoring and Observability

### Metrics to Monitor

1. **Performance**
   - App startup time
   - Screen transition time
   - API response time
   - Offline sync time

2. **Errors**
   - Crash rate
   - Function errors
   - Network errors
   - Sync failures

3. **Usage**
   - Active users
   - Feature usage
   - Payment success rate
   - Offline usage patterns

### Tools

- **Firebase Performance Monitoring**: App performance
- **Firebase Crashlytics**: Crash reporting
- **Cloud Functions Logs**: Backend logs
- **Firebase Analytics**: User behavior

## Disaster Recovery

### Backup Strategy

1. **Firestore**: Daily automated backups
2. **Storage**: Redundant storage in multiple regions
3. **Functions**: Version controlled in Git
4. **Configuration**: Stored in Git

### Recovery Plan

1. **Data Loss**: Restore from Firestore backup
2. **Service Outage**: Firebase handles automatically
3. **Code Issues**: Rollback Functions deployment
4. **Security Breach**: Revoke credentials, audit logs

## Future Considerations

### Potential Enhancements

1. **Multi-tenant Architecture**: Support multiple businesses
2. **Real-time Collaboration**: Multiple admins updating simultaneously
3. **Advanced Analytics**: Business intelligence dashboard
4. **Push Notifications**: Real-time updates
5. **Internationalization**: Multiple languages support
6. **Advanced Offline**: Conflict resolution UI
7. **WebSockets**: Real-time updates without polling
=======
# Sierra Painting MVP - Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
│                      (Material3 UI)                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │    Auth     │  │  Timeclock  │  │  Estimates  │        │
│  │   Feature   │  │   Feature   │  │   Feature   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│  ┌─────────────┐  ┌─────────────┐                          │
│  │  Invoices   │  │    Admin    │                          │
│  │   Feature   │  │   Feature   │                          │
│  └─────────────┘  └─────────────┘                          │
├─────────────────────────────────────────────────────────────┤
│              State Management (Riverpod)                     │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Auth Providers  │  │ Firestore Provider│               │
│  └──────────────────┘  └──────────────────┘               │
├─────────────────────────────────────────────────────────────┤
│                    Routing (go_router)                       │
│              ┌────────────────────────────┐                 │
│              │   RBAC Guards & Redirects  │                 │
│              └────────────────────────────┘                 │
├─────────────────────────────────────────────────────────────┤
│     Local Storage          │      Network Layer             │
│  ┌─────────────────┐      │   ┌──────────────────┐        │
│  │  Hive Queue     │      │   │  Firebase SDK     │        │
│  │  (Offline ops)  │      │   │  (Auth, Firestore)│        │
│  └─────────────────┘      │   └──────────────────┘        │
└────────────┬────────────────────────┬───────────────────────┘
             │                        │
             │                        │
┌────────────▼────────────────────────▼───────────────────────┐
│                    Firebase Backend                          │
├─────────────────────────────────────────────────────────────┤
│  Firebase Authentication                                     │
│  ┌──────────────────────────────────────┐                  │
│  │  Email/Password Auth                  │                  │
│  │  User Session Management              │                  │
│  └──────────────────────────────────────┘                  │
├─────────────────────────────────────────────────────────────┤
│  Cloud Firestore                                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │  Users   │ │  Leads   │ │Estimates │ │ Invoices │     │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘     │
│  ┌──────────┐ ┌──────────────────────────────────┐        │
│  │Timeclocks│ │      Audit Logs                  │        │
│  └──────────┘ └──────────────────────────────────┘        │
│                                                             │
│  Security Rules (Deny-by-default)                          │
│  • Client cannot set invoice.paid                          │
│  • RBAC for admin operations                               │
│  • Authenticated users only                                │
├─────────────────────────────────────────────────────────────┤
│  Cloud Functions (TypeScript + Zod)                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  createLead                                          │  │
│  │  • Validates lead data with Zod                     │  │
│  │  • Creates Firestore document                       │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  createEstimatePdf                                   │  │
│  │  • Generates PDF with PDFKit                        │  │
│  │  • Uploads to Firebase Storage                      │  │
│  │  • Returns signed URL (7-day expiry)                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  markPaidManual                                      │  │
│  │  • Validates payment data (check/cash)              │  │
│  │  • Updates invoice in transaction                   │  │
│  │  • Creates audit log (user, IP, timestamp)          │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  createCheckoutSession (Stripe - Optional)          │  │
│  │  • Creates Stripe checkout session                  │  │
│  │  • Returns session URL                              │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  stripeWebhook (Stripe - Optional)                  │  │
│  │  • Verifies webhook signature                       │  │
│  │  • Handles events idempotently                      │  │
│  │  • Updates invoice on payment success               │  │
│  └──────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Firebase Storage                                           │
│  ┌──────────────────────────────────────┐                  │
│  │  /estimates/*.pdf                     │                  │
│  │  (Generated PDF documents)            │                  │
│  └──────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline                            │
│                   (GitHub Actions)                           │
├─────────────────────────────────────────────────────────────┤
│  On Push/PR:                                                │
│  ┌──────────────────────────────────────┐                  │
│  │  1. Flutter: format, analyze, test   │                  │
│  │  2. Functions: lint, build           │                  │
│  │  3. Build APK (debug)                │                  │
│  └──────────────────────────────────────┘                  │
│                                                             │
│  On Main Branch Push:                                       │
│  ┌──────────────────────────────────────┐                  │
│  │  1. Build Functions                  │                  │
│  │  2. Deploy to Staging                │                  │
│  │     • Functions                      │                  │
│  │     • Firestore Rules                │                  │
│  │     • Storage Rules                  │                  │
│  └──────────────────────────────────────┘                  │
│                                                             │
│  On Version Tag (v*):                                       │
│  ┌──────────────────────────────────────┐                  │
│  │  1. Build Flutter release (APK+AAB)  │                  │
│  │  2. Build Functions                  │                  │
│  │  3. Deploy to Production             │                  │
│  │  4. Upload artifacts                 │                  │
│  └──────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Examples

### 1. User Authentication Flow
```
User Login Screen
    │
    ├──> Firebase Auth (signInWithEmailAndPassword)
    │
    ├──> authStateProvider (Riverpod StreamProvider)
    │
    ├──> go_router redirect logic
    │
    └──> Navigate to Timeclock Screen
```

### 2. Create Estimate with PDF
```
Flutter App (Estimate Screen)
    │
    ├──> Call createEstimatePdf Cloud Function
    │       │
    │       ├──> Validate data with Zod schema
    │       │
    │       ├──> Generate PDF with PDFKit
    │       │
    │       ├──> Upload to Firebase Storage
    │       │
    │       ├──> Create Firestore estimate document
    │       │
    │       └──> Return signed URL
    │
    └──> Display PDF URL to user
```

### 3. Mark Invoice as Paid (Manual Payment)
```
Admin User (Admin Screen)
    │
    ├──> Call markPaidManual Cloud Function
    │       │
    │       ├──> Verify user has admin role
    │       │
    │       ├──> Validate payment data with Zod
    │       │
    │       ├──> Start Firestore transaction
    │       │       │
    │       │       ├──> Update invoice.paid = true
    │       │       │
    │       │       └──> Create audit_log document
    │       │               (user, timestamp, IP, payment details)
    │       │
    │       └──> Commit transaction
    │
    └──> Return success
```

### 4. Offline Operation Flow
```
User creates invoice (no internet)
    │
    ├──> Add to Hive queue
    │       (QueueItem: type="create_invoice", data={...})
    │
    ├──> Show "Queued for sync" message
    │
Internet connection restored
    │
    ├──> QueueService detects connectivity
    │
    ├──> Process pending queue items
    │       │
    │       ├──> Send to Firestore
    │       │
    │       ├──> Mark as processed
    │       │
    │       └──> Remove from queue
    │
    └──> Show "Synced" notification
```

### 5. RBAC Route Guard
```
User clicks Admin menu
    │
    ├──> go_router intercepts navigation
    │
    ├──> Check authStateProvider.value
    │       │
    │       ├──> Not logged in? → Redirect to /login
    │       │
    │       └──> Logged in? → Continue
    │
    ├──> Check user.email contains 'admin'
    │       │
    │       ├──> Not admin? → Redirect to /timeclock
    │       │
    │       └──> Is admin? → Allow access
    │
    └──> Load Admin Screen
```

## Security Architecture

### Firestore Rules (Deny-by-Default)
```
Default: DENY all

users collection:
  ✓ read: authenticated
  ✓ write: admin only

invoices collection:
  ✓ read: authenticated
  ✓ create: authenticated
  ✓ update: authenticated (but NOT paid/paidAt/paymentMethod)
  ✗ client cannot set paid=true

audit_logs collection:
  ✓ read: admin only
  ✗ write: none (only Cloud Functions)
```

### Authentication Flow
```
1. User enters credentials
2. Firebase Auth validates
3. Returns user token
4. Token included in all requests
5. Firestore rules check token
6. Cloud Functions verify token
```

### Admin Role Verification
```
Cloud Function receives request
    │
    ├──> Extract user token
    │
    ├──> Get user document from Firestore
    │       SELECT * FROM users WHERE uid = token.uid
    │
    ├──> Check isAdmin field
    │       if (!user.isAdmin) throw PermissionDenied
    │
    └──> Proceed with operation
```

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI Framework** | Flutter 3.16+ | Cross-platform mobile app |
| **UI Design** | Material3 | Modern, accessible UI |
| **State Management** | Riverpod | Reactive state management |
| **Routing** | go_router | Declarative routing with guards |
| **Local Storage** | Hive | Offline queue persistence |
| **Backend** | Firebase | BaaS (auth, database, storage) |
| **Database** | Cloud Firestore | NoSQL with offline support |
| **Functions** | Cloud Functions | Serverless compute |
| **Language (Functions)** | TypeScript | Type-safe backend code |
| **Validation** | Zod | Runtime type validation |
| **PDF Generation** | PDFKit | Server-side PDF creation |
| **Payments (optional)** | Stripe | Payment processing |
| **CI/CD** | GitHub Actions | Automated testing & deployment |

## File Organization

### Flutter App Structure
```
lib/
├── main.dart                    # Entry point
├── firebase_options.dart        # Firebase config
├── app/
│   ├── app.dart                # MaterialApp setup
│   └── router.dart             # Route definitions
├── core/
│   ├── models/                 # Shared data models
│   ├── providers/              # Global providers
│   ├── services/               # Shared services
│   ├── utils/                  # Helper functions
│   └── constants/              # App constants
└── features/
    ├── auth/
    │   ├── data/               # API clients, repositories
    │   ├── domain/             # Business logic
    │   └── presentation/       # UI screens & widgets
    ├── timeclock/              # Same structure
    ├── estimates/              # Same structure
    ├── invoices/               # Same structure
    └── admin/                  # Same structure
```

### Cloud Functions Structure
```
functions/
├── src/
│   ├── index.ts               # Function exports
│   ├── schemas/
│   │   └── index.ts          # Zod schemas
│   └── services/
│       └── pdf-service.ts    # Business logic
├── package.json
├── tsconfig.json
└── .eslintrc.js
```

## Key Design Decisions

1. **Feature-based architecture**: Each feature is self-contained
2. **Clean separation**: data/domain/presentation layers
3. **Provider pattern**: Centralized state with Riverpod
4. **RBAC at router level**: Security enforced before rendering
5. **Offline-first**: Local queue with automatic sync
6. **Server-side PDF**: Security and consistency
7. **Audit trail**: All sensitive operations logged
8. **Type safety**: TypeScript + Zod for functions
9. **Environment separation**: Staging and production
10. **CI/CD automation**: Tests before merge, deploy on tag

## Scaling Considerations

### Current Architecture Supports:
- ✅ Multiple concurrent users
- ✅ Offline operation
- ✅ Automatic scaling (Firebase)
- ✅ Global CDN (Firebase)
- ✅ Role-based permissions

### Future Enhancements:
- Add Firestore indexes for complex queries
- Implement caching layer for frequently accessed data
- Add background sync workers
- Implement pagination for large lists
- Add real-time updates with Firestore listeners
- Implement push notifications
- Add analytics and monitoring
- Implement automated backups

## Performance Optimizations

1. **Firestore offline persistence**: Automatic caching
2. **Hive queue**: Fast local storage
3. **Lazy loading**: Features loaded on demand
4. **Signed URLs**: Direct access to Storage files
5. **Indexes**: Pre-configured for common queries
6. **Build optimization**: Release builds minified

## Monitoring & Debugging

### Development
- Firebase Emulator UI: http://localhost:4000
- Flutter DevTools: Chrome debugger
- Hot reload: Instant code updates

### Production
- Firebase Console: Real-time logs
- Cloud Functions logs: Detailed execution traces
- Firestore usage metrics: Database performance
- Authentication logs: Login attempts and failures

---

This architecture provides a solid foundation for a production-ready painting business management application with security, scalability, and maintainability built in from day one.
main
