# Sierra Painting v1 - Product Backlog

## Decision-Ready Kanban

This backlog organizes features into epics with priority assignments (P0–P2) and sprint recommendations (V1–V4).

### Epic Definitions

- **Auth/RBAC**: Authentication, authorization, role-based access control, organization management
- **Time Clock**: Employee time tracking, clock in/out, work hours, timesheets
- **Invoicing/Payments**: Invoice creation, manual payments (check/cash), payment tracking, audit trails
- **Lead/Schedule**: Lead capture, estimates, PDF generation, scheduling (lite)
- **Ops/Observability**: Monitoring, logging, analytics, error tracking, performance metrics

---

## Product Backlog - Sprint Planning

| Story ID | Epic | Story Title | Priority | Sprint | Status | Notes |
|----------|------|-------------|----------|--------|--------|-------|
| **AUTH-001** | Auth/RBAC | Email/password authentication | P0 | V1 | ✅ Done | Firebase Auth integration |
| **AUTH-002** | Auth/RBAC | User profile creation on signup | P0 | V1 | ✅ Done | Auto-create user doc in Firestore |
| **AUTH-003** | Auth/RBAC | Role-based access control (admin/user) | P0 | V1 | ⚠️ Partial | Router guards exist, needs org-level RBAC |
| **AUTH-004** | Auth/RBAC | Organization multi-tenancy | P1 | V2 | 📋 Planned | Users belong to orgs, data scoped by orgId |
| **AUTH-005** | Auth/RBAC | Account lockout after failed attempts | P1 | V2 | 📋 Planned | Security enhancement |
| **AUTH-006** | Auth/RBAC | Admin override audit trail | P1 | V2 | 📋 Planned | Log all admin role changes |
| **AUTH-007** | Auth/RBAC | Password reset flow | P1 | V2 | 📋 Planned | Firebase Auth password reset |
| **AUTH-008** | Auth/RBAC | MFA/2FA support | P2 | V3 | 📋 Planned | Optional security layer |
| **TIME-001** | Time Clock | Clock in/out functionality | P0 | V1 | ✅ Done | Basic time tracking |
| **TIME-002** | Time Clock | Track work hours per employee | P0 | V1 | ✅ Done | Firestore timeclocks collection |
| **TIME-003** | Time Clock | Offline queue for clock in/out | P0 | V1 | ⚠️ Partial | Queue service exists, needs reconciliation |
| **TIME-004** | Time Clock | Pending sync indicator (UI) | P0 | V1 | 📋 Planned | Show "Syncing..." chip when offline |
| **TIME-005** | Time Clock | Idempotency for time entries | P0 | V1 | 📋 Planned | Prevent duplicate clock-ins via clientId |
| **TIME-006** | Time Clock | Edit time entries (admin) | P1 | V2 | 📋 Planned | Admin can fix incorrect times |
| **TIME-007** | Time Clock | Weekly timesheet view | P1 | V2 | 📋 Planned | Summary view for payroll |
| **TIME-008** | Time Clock | Export timesheet to CSV | P2 | V3 | 📋 Planned | For payroll integration |
| **TIME-009** | Time Clock | GPS location tracking (optional) | P2 | V4 | 📋 Planned | Verify on-site work |
| **INV-001** | Invoicing/Payments | Create invoices | P0 | V1 | ✅ Done | Basic invoice creation |
| **INV-002** | Invoicing/Payments | Mark invoice paid (manual check/cash) | P0 | V1 | ✅ Done | Admin-only callable function |
| **INV-003** | Invoicing/Payments | Idempotency for payments | P0 | V1 | ✅ Done | Idempotency key in markPaymentPaid |
| **INV-004** | Invoicing/Payments | Payment audit trail | P0 | V1 | ✅ Done | Audit logs for all payments |
| **INV-005** | Invoicing/Payments | Client cannot set invoice.paid | P0 | V1 | ✅ Done | Firestore security rule enforced |
| **INV-006** | Invoicing/Payments | Invoice status tracking (draft/sent/paid/overdue) | P1 | V2 | 📋 Planned | Lifecycle management |
| **INV-007** | Invoicing/Payments | Payment history view | P1 | V2 | 📋 Planned | Show all payments for invoice |
| **INV-008** | Invoicing/Payments | Send invoice via email | P1 | V2 | 📋 Planned | Email with PDF attachment |
| **INV-009** | Invoicing/Payments | Stripe Checkout integration (optional) | P1 | V3 | ⚠️ Stub | Feature-flagged, webhook handler exists |
| **INV-010** | Invoicing/Payments | Partial payment support | P2 | V3 | 📋 Planned | Track multiple payments per invoice |
| **INV-011** | Invoicing/Payments | Recurring invoices | P2 | V4 | 📋 Planned | Auto-generate monthly invoices |
| **LEAD-001** | Lead/Schedule | Lead capture form (public website) | P0 | V1 | 📋 Planned | No-auth form with captcha + App Check |
| **LEAD-002** | Lead/Schedule | Create estimates | P0 | V1 | ✅ Done | Basic estimate creation |
| **LEAD-003** | Lead/Schedule | Generate PDF estimate | P0 | V1 | ⚠️ Stub | Cloud Function exists, needs implementation |
| **LEAD-004** | Lead/Schedule | PDF preview in app | P0 | V1 | 📋 Planned | Show PDF before sending to customer |
| **LEAD-005** | Lead/Schedule | Estimate totals math (items + labor) | P0 | V1 | 📋 Planned | Client-side calculation with server validation |
| **LEAD-006** | Lead/Schedule | Convert estimate to invoice | P1 | V2 | 📋 Planned | One-click conversion |
| **LEAD-007** | Lead/Schedule | Lead status pipeline (new/contacted/quoted/won/lost) | P1 | V2 | 📋 Planned | Sales funnel tracking |
| **LEAD-008** | Lead/Schedule | Schedule jobs (lite calendar) | P1 | V2 | 📋 Planned | Assign employees to jobs by date |
| **LEAD-009** | Lead/Schedule | Email estimates to customers | P1 | V2 | 📋 Planned | Send PDF via email |
| **LEAD-010** | Lead/Schedule | Estimate templates | P2 | V3 | 📋 Planned | Reusable templates for common jobs |
| **LEAD-011** | Lead/Schedule | Customer portal (view estimates/invoices) | P2 | V4 | 📋 Planned | Customer self-service |
| **OPS-001** | Ops/Observability | Firebase Analytics integration | P0 | V1 | 📋 Planned | Track user actions |
| **OPS-002** | Ops/Observability | Error tracking and logging | P0 | V1 | 📋 Planned | Centralized error handling |
| **OPS-003** | Ops/Observability | Performance monitoring (P95 < 2.5s) | P0 | V1 | 📋 Planned | Track screen load times |
| **OPS-004** | Ops/Observability | App Check enforcement | P0 | V1 | 📋 Planned | Prevent API abuse |
| **OPS-005** | Ops/Observability | Firebase emulator setup | P0 | V1 | ✅ Done | Local development environment |
| **OPS-006** | Ops/Observability | CI/CD pipeline (analyze, test, deploy) | P0 | V1 | ✅ Done | GitHub Actions workflows |
| **OPS-007** | Ops/Observability | Feature flags (Remote Config) | P0 | V1 | ✅ Done | Toggle Stripe, offline mode, etc. |
| **OPS-008** | Ops/Observability | Health check endpoint | P1 | V2 | 📋 Planned | Monitor function availability |
| **OPS-009** | Ops/Observability | Cost monitoring alerts | P1 | V2 | 📋 Planned | Prevent runaway Firebase bills |
| **OPS-010** | Ops/Observability | Database backup strategy | P1 | V2 | 📋 Planned | Regular Firestore exports |
| **OPS-011** | Ops/Observability | Rate limiting on Cloud Functions | P1 | V3 | 📋 Planned | Prevent abuse |
| **OPS-012** | Ops/Observability | APM (Application Performance Monitoring) | P2 | V3 | 📋 Planned | Firebase Performance Monitoring |

---

## Story Details

### High-Priority Stories (P0) - Sprint V1

#### AUTH-003: Org-level RBAC (⚠️ Needs Completion)
**Current State**: Router has basic admin check via email pattern matching  
**Required**: 
- Add `orgId` to user documents
- Update security rules to check `belongsToOrg()`
- Implement organization creation/management
- Admin can only manage users in their org

#### TIME-004: Pending Sync Indicator
**Acceptance Criteria**:
- Show chip/badge on time entries that haven't synced
- Color-coded: yellow (pending), green (synced), red (error)
- Tap to retry failed syncs

#### TIME-005: Idempotency for Time Entries
**Technical Design**:
- Generate `clientId` (UUID) on device
- Include in clock-in/out payload
- Cloud Function checks for duplicate `clientId` before creating entry
- Return existing entry if duplicate detected

#### LEAD-001: Lead Capture Form
**Security Requirements**:
- Public endpoint (no auth required)
- reCAPTCHA v3 verification
- Firebase App Check token required
- Rate limiting (10 submissions per IP per hour)
- Honeypot field for spam prevention

#### LEAD-003: PDF Generation
**Performance Target**: ≤ 10 seconds  
**Implementation**:
- Use Puppeteer or PDFKit in Cloud Function
- HTML template with company branding
- Convert estimate data to formatted PDF
- Upload to Firebase Storage `/estimates/{estimateId}.pdf`
- Return signed URL (7-day expiry)

#### LEAD-004: PDF Preview
**UX Flow**:
1. User creates estimate in app
2. Tap "Preview" button
3. Download PDF from signed URL
4. Display in WebView or native PDF viewer
5. Option to "Send to Customer" or "Edit"

#### LEAD-005: Estimate Totals Math
**Formula**:
```
materialsCost = sum(items.quantity * items.unitPrice)
laborCost = laborHours * laborRate
subtotal = materialsCost + laborCost
tax = subtotal * taxRate
total = subtotal + tax
```
**Validation**: Server must recalculate to prevent client manipulation

#### OPS-001: Analytics Integration
**Events to Track**:
- User login/logout
- Screen views
- Feature usage (clock in/out, create invoice, etc.)
- Error occurrences
- Payment completions

#### OPS-002: Error Tracking
**Requirements**:
- Centralized error handler in Flutter
- Log to Firebase Crashlytics
- Include user context (userId, orgId, screen)
- Sanitize sensitive data before logging

#### OPS-003: Performance Monitoring
**Metrics**:
- Screen load time (P95 < 2.5s)
- Time to interactive (P95 < 3s)
- Function execution time
- Firestore read/write latency

#### OPS-004: App Check
**Enforcement**:
- Enable App Check on all Cloud Functions
- Add attestation provider (DeviceCheck for iOS, Play Integrity for Android)
- Fail closed (reject requests without valid token)
- Test in emulator with debug token

---

## Enhancement Story Details (from EnhancementsAndAdvice.md)

### UX-004: Motion-Reduced Animations (P0, V1)
**Current State**: Standard Flutter animations  
**Enhancement**:
- Detect user's `prefers-reduced-motion` setting
- Disable/reduce animations for accessibility
- Use `MediaQuery.of(context).disableAnimations`
- Provide manual toggle in settings

**Implementation**:
```dart
final reducedMotion = MediaQuery.of(context).disableAnimations;
return AnimatedOpacity(
  duration: reducedMotion ? Duration.zero : Duration(milliseconds: 300),
  // ...
);
```

**Impact**: WCAG 2.2 AA compliance, better UX for users with vestibular disorders  
**Estimated Effort**: 1 day

### UX-007: go_router Error Boundaries (P1, V1)
**Current State**: Basic routing, no error handling  
**Enhancement**:
- Add global error handler for route errors
- Create 404 page for invalid routes
- Redirect to login on auth errors
- Add error logging for navigation failures
- Implement deep link validation

**Implementation**:
```dart
GoRouter(
  errorBuilder: (context, state) => ErrorScreen(error: state.error),
  redirect: (context, state) {
    // Handle auth redirects
  },
)
```

**Impact**: Graceful error handling, better debugging  
**Estimated Effort**: 2 days

### OFF-003: Sync Progress Indicator (P0, V1)
**Current State**: Offline queue exists, but no UI indicators  
**Enhancement**:
- Add badge/chip on items that haven't synced
- Global sync status indicator in app bar
- Tap-to-retry for failed syncs
- Color-coded: yellow (pending), green (synced), red (error)
- Show sync progress percentage

**UI Components**:
```dart
class SyncStatusChip extends StatelessWidget {
  final SyncStatus status;
  // Color: yellow (pending), green (synced), red (error)
}
```

**Impact**: Transparency, user confidence in offline-first architecture  
**Estimated Effort**: 2 days

### SEC-003: Input Validation & Sanitization Layer (P1, V2)
**Current State**: Basic Zod validation in functions  
**Enhancement**:
- Add client-side validation using `flutter_form_builder`
- Implement centralized validation rules
- Add input sanitization for XSS prevention
- Validate file uploads (type, size, content)
- Rate limit form submissions

**Validation Rules**:
```dart
// lib/core/utils/validators.dart
class Validators {
  static String? email(String? value);
  static String? phone(String? value);
  static String? required(String? value);
  static String? positiveNumber(String? value);
  static String? checkNumber(String? value); // Check # format
}
```

**Impact**: Security, better UX (instant feedback), reduced function calls  
**Estimated Effort**: 3 days

### UX-001: Zero-State Content Design (P1, V2)
**Current State**: Empty screens show generic messages  
**Enhancement**:
- Design custom illustrations for empty states
- Add actionable CTAs (e.g., "Create Your First Invoice")
- Show onboarding tips for new users
- Use `lottie` for animated illustrations

**Screens to Enhance**:
- Empty invoice list → "No invoices yet. Create one to get started!"
- Empty time entries → "Clock in to start tracking time"
- Empty estimates → "Create an estimate to send to customers"

**Impact**: Reduced friction for new users, clear next steps  
**Estimated Effort**: 3 days

### UX-002: Skeleton Loaders (P1, V2)
**Current State**: Circular progress indicators  
**Enhancement**:
- Replace spinners with skeleton screens
- Show content shape while loading
- Use `shimmer` package for animated loading effect
- Implement for: invoice list, estimate list, dashboard tiles

**Screens to Update**: 
- Invoices list screen
- Estimates list screen
- Admin dashboard
- Time clock history

**Impact**: Perceived performance improvement, better UX, modern app feel  
**Estimated Effort**: 2 days

### UX-006: Material 3 Theming Tokens (P1, V2)
**Current State**: Basic Material 3 setup exists  
**Enhancement**: 
- Implement design token system using Material 3 ColorScheme
- Add semantic color tokens (e.g., `surface-error`, `on-primary-container`)
- Support light/dark theme switching with user preference persistence
- Add custom theme extensions for brand colors (e.g., "Sierra Blue", "Painting Orange")

**Implementation**:
```dart
// lib/core/theme/design_tokens.dart
class DesignTokens {
  static const sierraBlue = Color(0xFF1976D2);
  static const paintingOrange = Color(0xFFFF9800);
  // ...
}
```

**Impact**: Consistent design language, easier theme customization, improved accessibility  
**Estimated Effort**: 3 days

### PERF-001: Performance Budgets per Screen (P1, V2)
**Current State**: Global P95 < 2.5s target  
**Enhancement**:
- Define specific performance budgets for each screen
- Add automated performance tests
- Track metrics in Firebase Performance Monitoring
- Set alerts for budget violations

**Screen Budgets**:
| Screen | Target Load Time | Time to Interactive |
|--------|------------------|---------------------|
| Login | 1.5s | 2.0s |
| Dashboard | 2.0s | 2.5s |
| Invoices List | 2.0s | 2.5s |
| Create Invoice | 1.8s | 2.2s |
| PDF Preview | 3.0s | 3.5s |

**Impact**: Concrete performance targets, proactive optimization  
**Estimated Effort**: 2 days

### PERF-003: Riverpod Architecture Improvements (P1, V2)
**Current State**: Basic Riverpod setup  
**Enhancement**:
- Add `riverpod_generator` for type-safe providers
- Implement proper state lifecycle management
- Add provider documentation (what data, when it refreshes, cache duration)
- Use `AsyncValue` consistently for async data
- Add proper error handling in providers

**Best Practices**:
- Use `@riverpod` annotation for all providers
- Separate data providers from UI state
- Add `keepAlive: true` for global state
- Document dependencies between providers

**Impact**: Better state management, easier debugging, type safety  
**Estimated Effort**: 3 days

### PERF-004: Feature Flag Taxonomy (P1, V2)
**Current State**: Basic Remote Config feature flags  
**Enhancement**:
- Define feature flag naming convention
- Create flag categories: `feature_*`, `config_*`, `killswitch_*`
- Add flag documentation (purpose, default, rollout plan)
- Implement gradual rollout (percentage-based)
- Add A/B testing support

**Flag Examples**:
- `feature_stripe_enabled` (boolean, default: false)
- `config_max_offline_queue_size` (int, default: 100)
- `killswitch_pdf_generation` (boolean, default: false - emergency disable)

**Impact**: Safer feature rollouts, quick incident response  
**Estimated Effort**: 1 day

### ADM-005: Observability Dashboard (P2, V3)
**Current State**: Firebase Console for logs  
**Enhancement**:
- Create admin dashboard for observability
- Show real-time metrics: active users, pending syncs, error rate
- Add cost tracking widget (Firebase usage)
- Display recent audit logs
- Add alert configuration UI

**Widgets**:
- Active users (last 24h)
- Pending offline operations
- Failed function calls (last hour)
- Top errors (grouped by type)
- Cost trend (daily Firebase spend)

**Impact**: Proactive issue detection, cost control  
**Estimated Effort**: 5 days

### PERF-002: Background Upload & Thumbnails (P2, V3)
**Current State**: PDF uploads happen in foreground  
**Enhancement**:
- Use `workmanager` for background PDF generation/upload
- Generate thumbnail images for PDFs (first page preview)
- Show upload progress in notification
- Resume interrupted uploads
- Cache thumbnails locally

**Technical Design**:
- Cloud Function: Generate thumbnail on PDF upload
- Store thumbnail in Storage: `/estimates/{id}_thumb.jpg`
- Display thumbnail in estimate list

**Impact**: Better UX, app remains responsive, faster preview  
**Estimated Effort**: 5 days

---

## Missing Stories (Identified Gaps)

### Security & Compliance
- **SEC-001**: HTTPS enforcement (P0, V1) - Force secure connections
- **SEC-002**: Content Security Policy headers (P1, V2) - Web security
- **SEC-003**: Input sanitization library (P1, V2) - Prevent XSS/injection
- **SEC-004**: Secrets management via Secret Manager (P0, V1) - No .env secrets in repo

### Offline & Sync
- **OFF-001**: Conflict resolution strategy (P0, V1) - Last-write-wins with warning
- **OFF-002**: Offline login (P1, V2) - Cache credentials securely
- **OFF-003**: Sync progress indicator (P0, V1) - Global sync status
- **OFF-004**: Max offline queue size (P1, V2) - Prevent unbounded growth

### Payments
- **PAY-001**: Payment receipt generation (P1, V2) - PDF receipt after payment
- **PAY-002**: Refund support (P2, V3) - Manual refund with audit trail
- **PAY-003**: Payment method validation (P1, V2) - Check number format validation

### Admin & Reports
- **ADM-001**: User deactivation (P1, V2) - Soft delete users
- **ADM-002**: Dashboard analytics tiles (P1, V2) - Revenue, outstanding invoices, etc.
- **ADM-003**: Audit log viewer (P0, V1) - Admin can view all audit events
- **ADM-004**: Export reports to CSV (P2, V3) - Financial reports
- **ADM-005**: Observability dashboard (P2, V3) - Real-time metrics, error rates, cost tracking

### Performance & Architecture
- **PERF-001**: Performance budgets per screen (P1, V2) - Define and track load time targets
- **PERF-002**: Background upload with thumbnails (P2, V3) - PDF thumbnails and async uploads
- **PERF-003**: Riverpod architecture improvements (P1, V2) - Code generation, type safety, lifecycle
- **PERF-004**: Feature flag taxonomy (P1, V2) - Naming convention, gradual rollout, A/B testing

### UX & Accessibility
- **UX-001**: Zero-state content (P1, V2) - Empty state guidance for new users
- **UX-002**: Skeleton loaders (P1, V2) - Loading placeholders instead of spinners
- **UX-003**: Haptic feedback (P2, V3) - Vibration on button taps
- **UX-004**: Motion-reduced animations (P0, V1) - Respect accessibility preferences
- **UX-005**: WCAG 2.2 AA compliance audit (P0, V1) - Color contrast, labels, keyboard nav
- **UX-006**: Material 3 theming tokens (P1, V2) - Design token system with semantic colors
- **UX-007**: Error boundaries in go_router (P1, V1) - Custom 404 pages and error handling

---

## Sprint Recommendations

### Sprint V1 (MVP - Weeks 1-4)
**Goal**: Offline-first core workflows with security  
**Stories**: AUTH-001, AUTH-002, AUTH-003, TIME-001, TIME-002, TIME-003, TIME-004, TIME-005, INV-001, INV-002, INV-003, INV-004, INV-005, LEAD-001, LEAD-002, LEAD-003, LEAD-004, LEAD-005, OPS-001, OPS-002, OPS-003, OPS-004, OPS-005, OPS-006, OPS-007, SEC-001, SEC-004, OFF-001, OFF-003, ADM-003, UX-004, UX-005, UX-007

### Sprint V2 (Enhancement - Weeks 5-8)
**Goal**: Workflow improvements and admin tools  
**Stories**: AUTH-004, AUTH-005, AUTH-006, AUTH-007, TIME-006, TIME-007, INV-006, INV-007, INV-008, LEAD-006, LEAD-007, LEAD-008, LEAD-009, OPS-008, OPS-009, OPS-010, SEC-002, SEC-003, OFF-002, OFF-004, PAY-001, PAY-003, ADM-001, ADM-002, UX-001, UX-002, UX-006, PERF-001, PERF-003, PERF-004

### Sprint V3 (Scale - Weeks 9-12)
**Goal**: Advanced features and integrations  
**Stories**: AUTH-008, TIME-008, INV-009, INV-010, LEAD-010, OPS-011, OPS-012, PAY-002, ADM-004, ADM-005, UX-003, PERF-002

### Sprint V4 (Polish - Weeks 13-16)
**Goal**: Customer-facing features and advanced scheduling  
**Stories**: TIME-009, INV-011, LEAD-011

---

## Acceptance Criteria Standards

All stories must meet:
- [ ] Unit tests written and passing
- [ ] Integration tests for critical paths
- [ ] Security rules validated
- [ ] Documentation updated
- [ ] Accessibility checked (WCAG 2.2 AA)
- [ ] Performance validated (P95 < 2.5s)
- [ ] Code review approved
- [ ] QA sign-off

---

## Notes

- All P0 stories are **blockers** for production release
- P1 stories enhance usability and should be in V2
- P2 stories are **nice-to-have** and can be deferred
- Feature flags allow gradual rollout of new features
- Offline-first is non-negotiable for field workers

---

## Risk Register (from EnhancementsAndAdvice.md)

### Security Risks

#### RISK-SEC-001: Offline Data Duplication
**Severity**: High  
**Mitigation**:
- Implement clientId-based idempotency
- Server-side duplicate detection
- Conflict resolution strategy (last-write-wins with warning)
- Add reconciliation job to clean up duplicates

#### RISK-SEC-002: Client Tampering (Invoice Amounts)
**Severity**: Critical  
**Mitigation**:
- Server must recalculate all totals
- Firestore rules prevent client setting paid/amount fields
- Audit log all invoice modifications
- Add server-side validation function

#### RISK-SEC-003: Insufficient App Check Coverage
**Severity**: High  
**Mitigation**:
- Enable App Check on ALL callable functions
- Fail closed (reject requests without token)
- Monitor App Check violations in Firebase Console
- Add App Check enforcement tests

#### RISK-SEC-004: Leaked API Keys
**Severity**: Critical  
**Mitigation**:
- Use Secret Manager for all sensitive values
- Never commit .env files
- Add secrets scanning to CI/CD
- Rotate keys immediately if leaked

#### RISK-SEC-005: Account Takeover via Weak Passwords
**Severity**: Medium  
**Mitigation**:
- Enforce password complexity (min 8 chars, uppercase, number, symbol)
- Implement account lockout after 5 failed attempts
- Add optional MFA/2FA
- Monitor for suspicious login patterns

### Offline Risks

#### RISK-OFF-001: Unbounded Queue Growth
**Severity**: Medium  
**Mitigation**:
- Set max queue size (e.g., 100 items)
- Show warning when queue > 50 items
- Oldest items auto-expire after 7 days
- Add queue cleanup job

#### RISK-OFF-002: Stale Data Conflicts
**Severity**: High  
**Mitigation**:
- Implement optimistic locking (version field)
- Detect conflicts on sync
- Show conflict resolution UI
- Default to last-write-wins with warning

#### RISK-OFF-003: Offline Login Failures
**Severity**: Medium  
**Mitigation**:
- Cache Firebase Auth token securely
- Allow offline login with cached token (expires 1 hour)
- Show clear error if token expired
- Document offline login limitations

### Payment Risks

#### RISK-PAY-001: Webhook Replay Attacks
**Severity**: High  
**Mitigation**:
- Verify webhook signature (Stripe secret)
- Check event.id against idempotency collection
- Reject events older than 5 minutes
- Log all webhook attempts

#### RISK-PAY-002: Missing Payment Records
**Severity**: Critical  
**Mitigation**:
- Use Firestore transactions for payment updates
- Add reconciliation job (compare Stripe vs Firestore daily)
- Alert on mismatches
- Manual audit process for discrepancies

#### RISK-PAY-003: Refund Abuse
**Severity**: Medium  
**Mitigation**:
- Require two-person approval for refunds > $500
- Log all refunds with reason
- Alert owner on any refund
- Implement refund limit per day

### Operational Risks

#### RISK-OPS-001: Cost Spike
**Severity**: High  
**Mitigation**:
- Set Firebase budget alerts ($100, $500, $1000)
- Implement rate limiting on functions
- Add query pagination (limit 50 items per query)
- Monitor Cloud Function invocations
- Add circuit breaker for expensive operations

#### RISK-OPS-002: Data Loss
**Severity**: Critical  
**Mitigation**:
- Enable Firestore daily backups
- Test restore process monthly
- Add soft-delete for critical documents
- Implement audit trail for all deletions
- Require confirmation for bulk operations

#### RISK-OPS-003: Function Cold Start Latency
**Severity**: Medium  
**Mitigation**:
- Use Cloud Run for long-running tasks
- Increase function timeout to 540s
- Pre-warm functions with scheduled pings
- Show progress indicator during PDF generation
- Cache commonly used templates

#### RISK-OPS-004: Emulator Drift from Production
**Severity**: Medium  
**Mitigation**:
- Keep emulator versions up-to-date
- Test deployments in staging before production
- Add integration tests against real Firebase
- Document known emulator limitations
- Use firebase-tools 12.0+
