# V1 Ship-Readiness Plan — Project Sierra

**Date:** 2024-10-02  
**Branch:** `ship/v1-readiness`  
**Status:** In Progress

---

## Executive Summary

This document outlines the comprehensive plan for bringing Project Sierra to a board-ready V1 state through aggressive cleanup, restructure, functional hardening, and professional documentation. The plan follows a phased approach with clear acceptance criteria and risk mitigation strategies.

---

## Current State Assessment

### Repository Structure
The repository has undergone previous refactoring efforts (see `REFACTORING_SUMMARY.md`, `RESTRUCTURE_SUMMARY.md`). Current state:

**Strengths:**
- ✅ Core architecture in place (Flutter + Firebase)
- ✅ Basic feature scaffolding (auth, timeclock, estimates, invoices, admin)
- ✅ Cloud Functions structure with TypeScript + Zod
- ✅ Firestore rules with deny-by-default posture
- ✅ CI/CD workflows configured
- ✅ ADR documentation exists
- ✅ Offline service with Hive queue foundation

**Gaps & Issues:**
- ⚠️ Multiple redundant summary files (8+ files: PROJECT_SUMMARY.md, REFACTORING_SUMMARY.md, etc.)
- ⚠️ Functions lint errors (22 errors, 12 warnings)
- ⚠️ Incomplete offline queue reconciliation logic
- ⚠️ Missing telemetry_service.dart (referenced but not implemented)
- ⚠️ RBAC guards incomplete (email-based admin check, no org-scoped claims)
- ⚠️ Missing Testing.md and Security.md in docs/
- ⚠️ No emulator integration tests implemented
- ⚠️ Stub implementations in several Cloud Functions
- ⚠️ Missing PDF generation implementation
- ⚠️ No widgets/ directory in lib/ (referenced in docs but missing)

---

## Proposed Target Structure

```
/ (repo root)
├── README.md                      # Concise, board-ready overview
├── LICENSE                        # Keep
├── .gitignore                     # Enhanced
├── .gitattributes                 # Keep
├── .editorconfig                  # Keep
├── .firebaserc                    # Keep
├── firebase.json                  # Keep
├── firestore.rules                # Hardened
├── firestore.indexes.json         # Complete indexes
├── storage.rules                  # Hardened
├── pubspec.yaml                   # Keep
├── analysis_options.yaml          # Keep
│
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── story.md               # Keep
│   │   ├── bug.md                 # Keep
│   │   └── tech-task.md           # Keep
│   ├── PULL_REQUEST_TEMPLATE.md   # Keep
│   └── workflows/
│       └── ci.yml                 # Consolidated from flutter-ci, functions-ci
│
├── docs/
│   ├── Architecture.md            # Polished, concise
│   ├── Backlog.md                 # Condensed P0 stories
│   ├── KickoffTicket.md           # Executive epic
│   ├── Testing.md                 # NEW: Test strategy + E2E scripts
│   ├── Security.md                # NEW: Security patterns + App Check
│   ├── MIGRATION.md               # Updated with V1-readiness changes
│   ├── APP_CHECK.md               # Keep
│   ├── EMULATORS.md               # Keep
│   ├── DEVELOPER_WORKFLOW.md      # Keep
│   ├── FEATURE_FLAGS.md           # Keep
│   └── ADRs/                      # Keep all ADRs
│
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart            # HARDENED: Custom claims RBAC
│   │   └── theme.dart
│   ├── core/
│   │   ├── services/
│   │   │   ├── auth_service.dart
│   │   │   ├── firestore_service.dart
│   │   │   ├── storage_service.dart
│   │   │   ├── offline_queue_service.dart  # HARDENED: Full reconciliation
│   │   │   └── feature_flag_service.dart
│   │   ├── telemetry/
│   │   │   └── telemetry_service.dart      # NEW: Structured logging
│   │   ├── utils/
│   │   │   ├── result.dart                 # NEW: Result type
│   │   │   └── validators.dart
│   │   ├── providers/
│   │   │   ├── auth_provider.dart
│   │   │   └── firestore_provider.dart
│   │   ├── models/
│   │   │   └── queue_item.dart
│   │   └── widgets/
│   │       ├── error_screen.dart
│   │       └── sync_status_chip.dart
│   ├── features/
│   │   ├── auth/
│   │   ├── timeclock/
│   │   ├── estimates/
│   │   ├── invoices/
│   │   ├── admin/
│   │   └── website/
│   └── widgets/                            # NEW: Shared components
│
├── functions/
│   ├── package.json
│   ├── tsconfig.json
│   ├── .eslintrc.js
│   └── src/
│       ├── index.ts                        # CLEAN: Export wiring
│       ├── lib/
│       │   ├── zodSchemas.ts               # Keep
│       │   ├── audit.ts                    # Keep
│       │   ├── idempotency.ts              # Keep
│       │   └── stripe.ts                   # Keep (optional)
│       ├── leads/
│       │   └── createLead.ts               # HARDENED
│       ├── pdf/
│       │   └── createEstimatePdf.ts        # IMPLEMENTED
│       ├── payments/
│       │   ├── markPaidManual.ts           # HARDENED
│       │   ├── createCheckoutSession.ts    # Keep (optional)
│       │   └── stripeWebhook.ts            # Keep (optional)
│       └── tests/
│           ├── rules.spec.ts               # IMPLEMENTED
│           └── payments.spec.ts            # IMPLEMENTED
│
├── test/
│   └── widget_test.dart
│
├── android/                                # Keep
├── web/                                    # Keep
└── workflows/                              # DELETE (duplicate)
```

---

## Files to Delete

**Rationale:** Remove redundant documentation that creates confusion and maintenance burden.

| File | Rationale |
|------|-----------|
| `PROJECT_SUMMARY.md` | Duplicates README content |
| `REFACTORING_SUMMARY.md` | Historical, not forward-looking |
| `RESTRUCTURE_SUMMARY.md` | Historical, superseded by MIGRATION.md |
| `REVIEW_IMPLEMENTATION_SUMMARY.md` | Historical artifact |
| `IMPLEMENTATION_SUMMARY.md` | Historical artifact |
| `BACKEND_FIX_SUMMARY.md` | Historical artifact |
| `VERIFICATION_REPORT.md` | Historical artifact |
| `VALIDATION_CHECKLIST.md` | Incorporated into Testing.md |
| `QUICKSTART.md` | Consolidated into README.md |
| `SETUP.md` | Consolidated into README.md |
| `CHANGELOG.md` | Use GitHub releases instead |
| `CONTRIBUTING.md` | Keep minimal version in README |
| `workflows/` directory | Duplicate of `.github/workflows/` |
| `.github/workflows/flutter-ci.yml` | Consolidate into ci.yml |
| `.github/workflows/functions-ci.yml` | Consolidate into ci.yml |
| `.github/workflows/deploy-staging.yml` | Keep but simplify |
| `.github/workflows/deploy-production.yml` | Keep but simplify |
| `.github/workflows/security.yml` | Keep but simplify |
| `.github/workflows/.yml` | Empty file, delete |
| `functions/src/schemas/` | Duplicate of lib/zodSchemas.ts |
| `functions/src/services/` | Move to lib/ or consolidate |
| `functions/src/stripe/webhookHandler.ts` | Consolidate into payments/ |
| `lib/core/config/theme_config.dart` | Duplicate of app/theme.dart |
| `lib/core/config/firebase_options.dart` | Duplicate of root firebase_options.dart |
| `docs/index.md` | README serves this purpose |
| `docs/EnhancementsAndAdvice.md` | Historical, not actionable |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Deleting wrong files** | Low | High | Verify each deletion against MIGRATION.md; keep git history |
| **Breaking existing flows** | Medium | High | Test emulators after each change; maintain backward compatibility |
| **Lint errors blocking deploy** | High | Medium | Fix all TypeScript lint errors before hardening |
| **Missing Flutter SDK** | High | Low | Document that Flutter validation must happen post-merge |
| **Firestore rule regressions** | Medium | High | Write emulator tests for all rules; test before deploy |
| **Webhook idempotency issues** | Low | High | Comprehensive tests for Stripe webhook handling |
| **Cost spike from missing indexes** | Medium | Medium | Define all required indexes in firestore.indexes.json |
| **App Check blocking dev** | Medium | Low | Document debug token setup clearly |
| **Offline queue data loss** | Low | High | Implement proper error handling and retry logic |
| **Security rule bypass** | Low | Critical | Deny-by-default; peer review all rule changes |

---

## Phase Breakdown

### Phase 1: Audit & Plan ✅ (This Document)

**Objectives:**
- [x] Enumerate current tree
- [x] Identify dead/duplicated files
- [x] Draft target structure
- [x] Create risk register
- [x] Define migration plan

### Phase 2: Repo Restructure & Cleanup

**Objectives:**
1. Delete redundant summary/historical files
2. Consolidate CI workflows
3. Remove duplicate directories (workflows/, schemas/, services/, config/)
4. Update MIGRATION.md with comprehensive before/after
5. Add missing directories (lib/widgets/, lib/core/telemetry/)

**Acceptance Criteria:**
- [ ] All files in "Files to Delete" removed
- [ ] MIGRATION.md updated with complete inventory
- [ ] No build breaks after restructure
- [ ] Git history preserved

### Phase 3: Functional Hardening

**Flutter Side:**
1. **Router RBAC Guards**
   - Implement custom claims checking (role, orgId)
   - Replace email-based admin check with real claims
   - Add token refresh handling
   - Create route guard utilities

2. **Offline Queue Service**
   - Complete reconciliation logic (retryAll, reconcile)
   - Implement pendingCount provider
   - Add UUID clientId for idempotency
   - Optimistic UI with sync status chips

3. **Telemetry Service**
   - Structured logging with standard fields
   - Analytics event tracking
   - Crashlytics integration
   - Performance monitoring hooks

4. **Result Type**
   - Implement Result<T, E> for error handling
   - Use across service layer

**Cloud Functions Side:**
1. **Fix All Lint Errors**
   - Resolve 22 errors, 12 warnings
   - Proper type annotations
   - Remove unnecessary type assertions

2. **Harden createLead**
   - App Check validation
   - Rate limiting notes
   - Proper error handling

3. **Implement createEstimatePdf**
   - HTML to PDF conversion
   - Firebase Storage upload
   - Signed URL generation
   - Retry logic

4. **Harden markPaidManual**
   - Verify admin-only enforcement
   - Transactional writes
   - Idempotency checks
   - Audit logging

5. **Stripe Functions (Optional)**
   - Feature flag checks
   - Webhook signature verification
   - Event idempotency

**Rules & Indexes:**
1. **Firestore Rules**
   - Verify deny-by-default
   - Add orgId checks
   - Payments subcollection write-only
   - Test all allow/deny paths

2. **Storage Rules**
   - Signed URLs for PDFs
   - Size limits (8MB for photos)
   - Org-scoped paths

3. **Indexes**
   - jobs(orgId, scheduledDate asc)
   - timeEntries collection-group (userId, clockIn)
   - invoices(orgId, status, issueDate desc)
   - estimates(orgId, createdAt desc)

**Acceptance Criteria:**
- [ ] All lint errors fixed
- [ ] Functions build passes
- [ ] Emulator tests pass
- [ ] Critical paths have test coverage
- [ ] No type 'any' usage without justification
- [ ] Structured logging in all functions

### Phase 4: Final Docs

**New Documents:**
1. **Testing.md**
   - Unit test strategy
   - Emulator integration tests
   - E2E test scripts (3 golden paths)
   - Performance test targets

2. **Security.md**
   - Firestore Rules patterns
   - App Check setup
   - Idempotency strategy
   - Stripe webhook security

**Updated Documents:**
1. **README.md**
   - Expand overview
   - Clarify month-1 features
   - Professional formatting
   - Concise getting started
   - Remove fluff

2. **Architecture.md**
   - Add sequence diagrams for key flows
   - Document RBAC implementation
   - Offline queue architecture
   - Idempotency patterns

3. **KickoffTicket.md**
   - Polish to executive epic quality
   - Clear scope boundaries
   - Quality bars
   - Milestones

4. **Backlog.md**
   - Condense to P0 stories only
   - Link to detailed stories in docs/stories/

5. **MIGRATION.md**
   - Complete before/after tree
   - Every deleted file with rationale
   - Import path updates
   - Breaking changes

**Acceptance Criteria:**
- [ ] All docs typo-free (spell check)
- [ ] Consistent formatting (Markdown)
- [ ] No broken internal links
- [ ] Professional tone
- [ ] Concise (remove fluff)

### Phase 5: CI/CD, Tests, & Ship Checks

**Objectives:**
1. Consolidate workflows into ci.yml
2. Ensure emulator tests run in CI
3. Write 3 E2E demo scripts
4. Verify no secrets committed
5. Confirm Stripe flag defaults OFF

**Acceptance Criteria:**
- [ ] CI runs: functions lint/build, emulator tests
- [ ] Emulator tests cover rules (allow/deny)
- [ ] Function tests cover markPaidManual, createLead
- [ ] E2E scripts documented in Testing.md
- [ ] git log --all search for secrets = clean
- [ ] Feature flags verified in firebase.json

---

## Migration Path

### Step-by-Step Execution

1. **Create branch** `ship/v1-readiness` ✅
2. **Write Plan.md** ✅
3. **Commit plan** → Proceed without approval
4. **Phase 2:** Delete files + restructure → Commit with detailed MIGRATION.md
5. **Phase 3:** Fix lint → Build → Harden functions → Test → Commit
6. **Phase 3:** Harden Flutter services → Commit
7. **Phase 4:** Write new docs (Testing.md, Security.md) → Commit
8. **Phase 4:** Polish existing docs → Commit
9. **Phase 5:** Consolidate CI → Write tests → Final validation → Commit
10. **Open PR** with professional description

---

## Success Metrics

**Technical:**
- ✅ Functions build with 0 lint errors/warnings
- ✅ Emulator tests pass (rules + functions)
- ✅ No secrets in git history
- ✅ All indexes defined
- ✅ CI green

**Documentation:**
- ✅ Typo-free
- ✅ Professional tone
- ✅ Concise (no rambling)
- ✅ Complete (all sections filled)

**Security:**
- ✅ Deny-by-default rules
- ✅ Server-only paid status
- ✅ App Check enforced
- ✅ Audit logs for sensitive ops

**Offline:**
- ✅ Hive outbox working
- ✅ Idempotency keys
- ✅ Sync status UI
- ✅ Reconciliation logic

---

## Timeline Estimate

- Phase 2: 1-2 hours
- Phase 3: 3-4 hours
- Phase 4: 2-3 hours
- Phase 5: 1-2 hours

**Total:** 7-11 hours

---

## Next Steps

1. Commit this plan
2. Begin Phase 2: Repo restructure
3. Update MIGRATION.md as we go
4. Report progress frequently

---

**Status:** Ready to execute  
**Last Updated:** 2024-10-02
