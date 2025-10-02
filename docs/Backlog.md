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

### UX & Accessibility
- **UX-001**: Zero-state content (P1, V2) - Empty state guidance for new users
- **UX-002**: Skeleton loaders (P1, V2) - Loading placeholders instead of spinners
- **UX-003**: Haptic feedback (P2, V3) - Vibration on button taps
- **UX-004**: Motion-reduced animations (P0, V1) - Respect accessibility preferences
- **UX-005**: WCAG 2.2 AA compliance audit (P0, V1) - Color contrast, labels, keyboard nav

---

## Sprint Recommendations

### Sprint V1 (MVP - Weeks 1-4)
**Goal**: Offline-first core workflows with security  
**Stories**: AUTH-001, AUTH-002, AUTH-003, TIME-001, TIME-002, TIME-003, TIME-004, TIME-005, INV-001, INV-002, INV-003, INV-004, INV-005, LEAD-001, LEAD-002, LEAD-003, LEAD-004, LEAD-005, OPS-001, OPS-002, OPS-003, OPS-004, OPS-005, OPS-006, OPS-007, SEC-001, SEC-004, OFF-001, OFF-003, ADM-003, UX-004, UX-005

### Sprint V2 (Enhancement - Weeks 5-8)
**Goal**: Workflow improvements and admin tools  
**Stories**: AUTH-004, AUTH-005, AUTH-006, AUTH-007, TIME-006, TIME-007, INV-006, INV-007, INV-008, LEAD-006, LEAD-007, LEAD-008, LEAD-009, OPS-008, OPS-009, OPS-010, SEC-002, SEC-003, OFF-002, OFF-004, PAY-001, PAY-003, ADM-001, ADM-002, UX-001, UX-002

### Sprint V3 (Scale - Weeks 9-12)
**Goal**: Advanced features and integrations  
**Stories**: AUTH-008, TIME-008, INV-009, INV-010, LEAD-010, OPS-011, OPS-012, PAY-002, ADM-004, UX-003

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
