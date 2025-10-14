# Sierra Painting MVP - Kickoff Ticket

## Project Overview
Scaffold a Flutter + Firebase MVP for a painting business management application with offline support, role-based access control, and automated workflows.

## Technical Stack

### Frontend
- **Framework**: Flutter with Material Design 3
- **State Management**: Riverpod (flutter_riverpod + riverpod_generator)
- **Routing**: go_router with RBAC guards
- **Local Storage**: 
  - Firestore offline persistence (automatic caching)
  - Hive for offline queue management
- **Firebase SDK**: firebase_core, cloud_firestore, firebase_auth, firebase_storage

### Backend
- **Platform**: Firebase (Cloud Functions, Firestore, Storage, Authentication)
- **Language**: TypeScript
- **Validation**: Zod schemas
- **Optional**: Stripe for payment processing

### CI/CD
- **Platform**: GitHub Actions
- **Environments**: Staging (main branch), Production (version tags)

## Features

### 1. Authentication (`features/auth`)
- Email/password authentication via Firebase Auth
- Automatic redirect based on auth state
- Secure token management

### 2. Time Clock (`features/timeclock`)
- Clock in/out functionality
- Track work hours per employee
- Store in Firestore `timeclocks` collection

### 3. Estimates (`features/estimates`)
- Create customer estimates
- Generate PDF via Cloud Function
- Store in Firestore `estimates` collection
- PDFs saved to Firebase Storage

### 4. Invoices (`features/invoices`)
- Create and manage invoices
- Payment tracking (manual and Stripe)
- Store in Firestore `invoices` collection
- Client cannot set `invoice.paid` field (security rule)

### 5. Admin Panel (`features/admin`)
- RBAC-protected route (admin-only access)
- User management capabilities
- Audit log viewing

## Cloud Functions

### Required Functions

#### 1. `createLead`
```typescript
Input (Zod validated):
  - name: string
  - email: string (email format)
  - phone: string
  - address: string
  - description?: string

Output:
  - success: boolean
  - leadId: string

Security:
  - Requires authentication
  - Creates audit trail
```

#### 2. `createEstimatePdf`
```typescript
Input (Zod validated):
  - leadId: string
  - items: Array<{description, quantity, unitPrice}>
  - laborHours: number
  - laborRate: number
  - notes?: string

Output:
  - success: boolean
  - estimateId: string
  - pdfUrl: string (signed URL, 7-day expiry)

Security:
  - Requires authentication
  - Generates PDF using PDFKit
  - Uploads to Firebase Storage
```

#### 3. `markPaidManual`
```typescript
Input (Zod validated):
  - invoiceId: string
  - paymentMethod: 'check' | 'cash'
  - amount: number
  - checkNumber?: string
  - notes?: string

Output:
  - success: boolean

Security:
  - Requires admin role
  - Creates audit log entry with:
    - User ID
    - Timestamp
    - IP address
    - Payment details
  - Atomic transaction (invoice + audit log)
```

### Optional Functions (Stripe Integration)

#### 4. `createCheckoutSession`
```typescript
Input:
  - invoiceId: string
  - successUrl: string
  - cancelUrl: string

Output:
  - sessionId: string
  - checkoutUrl: string
```

#### 5. `stripeWebhook`
```typescript
- Verifies webhook signature
- Handles events idempotently (uses event.id)
- Updates invoice status on payment completion
- Creates audit log
```

## Security Rules

### Firestore Rules
```
Default: deny all

users:
  - read: authenticated
  - write: admin only

leads:
  - read: authenticated
  - create: authenticated
  - update/delete: admin only

estimates:
  - read: authenticated
  - create: authenticated
  - update/delete: admin only

invoices:
  - read: authenticated
  - create: authenticated
  - update: authenticated (but cannot modify paid, paidAt, paymentMethod, paymentAmount)
  - delete: admin only

timeclocks:
  - read: authenticated
  - create: authenticated (only own records)
  - update: owner or admin
  - delete: admin only

audit_logs:
  - read: admin only
  - write: none (only functions can write)
```

### Storage Rules
```
estimates/*:
  - read: authenticated
  - write: none (only functions can write)
```

## Folder Structure

```
Sierra-Painting-v1/
├── lib/
│   ├── app/
│   │   ├── app.dart                    # Main app widget with Material3
│   │   └── router.dart                 # go_router configuration with RBAC
│   ├── core/
│   │   ├── models/
│   │   │   └── queue_item.dart         # Hive model for offline queue
│   │   ├── providers/
│   │   │   ├── auth_provider.dart      # Firebase Auth providers
│   │   │   └── firestore_provider.dart # Firestore instance with offline
│   │   ├── services/
│   │   │   └── queue_service.dart      # Offline queue management
│   │   ├── utils/
│   │   └── constants/
│   └── features/
│       ├── auth/
│       │   ├── data/                   # Repositories, data sources
│       │   ├── domain/                 # Entities, use cases
│       │   └── presentation/           # Screens, widgets
│       │       └── login_screen.dart
│       ├── timeclock/
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │       └── timeclock_screen.dart
│       ├── estimates/
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │       └── estimates_screen.dart
│       ├── invoices/
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │       └── invoices_screen.dart
│       └── admin/
│           ├── data/
│           ├── domain/
│           └── presentation/
│               └── admin_screen.dart
├── functions/
│   ├── src/
│   │   ├── schemas/
│   │   │   └── index.ts                # Zod schemas
│   │   ├── services/
│   │   │   └── pdf-service.ts          # PDF generation
│   │   └── index.ts                    # Cloud Functions
│   ├── package.json
│   └── tsconfig.json
├── .github/
│   └── workflows/
│       ├── ci.yml                      # Analyze and test
│       ├── deploy-staging.yml          # Deploy on main push
│       └── deploy-production.yml       # Deploy on tag push
├── docs/
│   └── KickoffTicket.md               # This file
├── firebase.json                       # Firebase configuration
├── firestore.rules                     # Security rules
├── firestore.indexes.json              # Firestore indexes
├── storage.rules                       # Storage security rules
├── pubspec.yaml                        # Flutter dependencies
├── analysis_options.yaml               # Dart analyzer config
└── README.md                           # Setup instructions
```

## Firebase Emulators

Configure for local development:
```json
{
  "emulators": {
    "auth": {"port": 9099},
    "functions": {"port": 5001},
    "firestore": {"port": 8080},
    "storage": {"port": 9199},
    "ui": {"enabled": true, "port": 4000}
  }
}
```

## CI/CD Workflows

### Analyze and Test (on all pushes/PRs)
1. Checkout code
2. Setup Flutter + Node.js
3. Install dependencies
4. Run Flutter: format, analyze, test
5. Run Functions: lint, build

### Deploy Staging (on main branch push)
1. Checkout code
2. Setup Node.js
3. Install Firebase CLI
4. Build functions
5. Deploy to staging project

### Deploy Production (on version tag)
1. Checkout code
2. Setup Flutter + Node.js
3. Build Flutter release (APK + AAB)
4. Build functions
5. Deploy to production project
6. Upload build artifacts

## Setup Checklist

- [x] Initialize Flutter project with Material3
- [x] Configure folder structure
- [x] Add Riverpod state management
- [x] Setup go_router with RBAC guards
- [x] Configure Firestore offline persistence
- [x] Setup Hive for queue management
- [x] Create authentication screens
- [x] Create feature screens (timeclock, estimates, invoices, admin)
- [x] Initialize Firebase project structure
- [x] Create TypeScript Cloud Functions with Zod
  - [x] createLead
  - [x] createEstimatePdf
  - [x] markPaidManual
  - [x] createCheckoutSession (stub)
  - [x] stripeWebhook (stub)
- [x] Configure Firestore security rules
- [x] Configure Storage security rules
- [x] Setup Firebase emulators
- [x] Create comprehensive README
- [x] Setup GitHub Actions CI/CD
  - [x] Analyze and test workflow
  - [x] Deploy staging workflow
  - [x] Deploy production workflow
- [x] Create KickoffTicket.md

## Next Steps (Post-Scaffold)

1. **Firebase Project Setup**
   - Create Firebase project
   - Run `flutterfire configure` to connect Flutter app
   - Enable Authentication (Email/Password)
   - Create Firestore database
   - Create Storage bucket

2. **Initial Data**
   - Create first admin user in Firebase Auth
   - Add admin user document to Firestore `users` collection

3. **Environment Configuration**
   - Add Firebase CI token to GitHub Secrets
   - Configure staging and production Firebase projects
   - Update `firebase.json` with project aliases

4. **Testing**
   - Start Firebase emulators
   - Test authentication flow
   - Test RBAC guards
   - Test offline functionality
   - Test Cloud Functions locally

5. **Stripe Setup** (if needed)
   - Create Stripe account
   - Add API keys to Firebase config
   - Implement Stripe checkout flow
   - Test webhook handling

## Notes

- **Material3**: Using latest Material Design 3 with dynamic color schemes
- **Offline First**: Firestore persistence + Hive queue ensures app works without internet
- **RBAC**: Admin routes protected by checking user role in Firestore
- **Audit Trail**: All sensitive operations (payments) are logged with full context
- **Idempotency**: Stripe webhook uses event.id to prevent duplicate processing
- **Security**: Deny-by-default rules with explicit permissions
- **PDF Generation**: Server-side using PDFKit for security and consistency
- **CI/CD**: Automated testing and deployment with environment separation

## Contact

For questions or issues, contact the development team.