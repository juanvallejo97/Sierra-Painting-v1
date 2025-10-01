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
