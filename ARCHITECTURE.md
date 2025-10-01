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
