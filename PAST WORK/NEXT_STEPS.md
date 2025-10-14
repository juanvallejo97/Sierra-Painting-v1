# NEXT_STEPS.md — D’Sierra Painting App (3‑Month Development Plan)

**Audience:** Claude + 5‑dev squad • **Mode:** single‑focus, reversible PRs • **Source baseline:**
PATCH_STATUS.md (92% complete)  
**Goal:** Ship a production‑ready v1 with invoices/estimates/timeclock/jobs, hardened security, and
observability.  
**Cadence:** 6 sprints × 2 weeks (12 weeks total).

---

## 0) Executive snapshot (what’s already solid)

- Security + CI foundation landed; 11 Firestore composite indexes defined; rules and storage tests
  in CI; emulator tests for `setUserRole`.
- Telemetry (Crashlytics/Analytics/Performance) instrumented; widget tests stable and isolated from
  Firebase; canonical web target is **Flutter Web** only; large legacy web code removed.
- Coverage moved ~10 → 33% with 127 passing tests; P0 + P1 complete; most P2/P3 items done;
  remaining coverage push and some debug print hygiene left.

**Immediate risk:** Indexes were deployed to a project you have access to (`to-do-app-ac602`) rather
than the intended `sierra-painting-*` projects. Fix aliases/permissions before any prod/staging
validation.

---

## 1) Immediate Triage (Days 0–2)

**A. Firebase projects & aliases**

- [ ] Confirm/create the correct GCP/Firebase projects: `sierra-painting-staging`,
      `sierra-painting-prod`.
- [ ] Update `.firebaserc` with explicit aliases:
  ```json
  {
    "projects": {
      "default": "sierra-painting-staging",
      "staging": "sierra-painting-staging",
      "prod": "sierra-painting-prod"
    }
  }
  ```
- [ ] `firebase use --add` → map `staging` and `prod`; verify `firebase projects:list` shows both.
- [ ] Grant developer roles: `roles/firebaseadmin`, `roles/datastore.indexAdmin`,
      `roles/cloudfunctions.admin` (least privilege for deployers).

**B. Deploy & verify indexes (repeatable)**

- [ ] `firebase deploy --only firestore:indexes --project sierra-painting-staging`
- [ ] Exercise all query paths in staging; confirm no “index required” errors.
- [ ] Promote to prod once staging is green.

**C. Rules warnings clean‑up**

- [ ] Remove/rename unused or invalid helper functions in `firestore.rules` (e.g., `isManager`,
      `isAdmin`, `isSelf`, `isSignedIn`) to silence compiler warnings.
- [ ] Ensure the rules helpers match CI tests; keep a tiny golden sample of documents for local
      emulator tests.

**D. Telemetry smoke**

- [ ] Trigger one synthetic error and one performance trace in staging; verify they arrive in
      Crashlytics/Performance.
- [ ] Create alerting policies for error budget / latency SLOs.

---

## 2) Epics (3 months)

### E1 — Invoices & Estimates (create → detail → edit → PDF → payments)

**Outcomes**

- CRUD flows complete; detail screens; robust validation; draft/sent/paid statuses; PDF generation &
  Storage; payment link (Stripe Checkout).  
  **Deliverables**
- `features/{invoices,estimates}/presentation/{detail,edit}_screen.dart`
- `services/pdf_service.dart` (server‑generated for stability) + Cloud Function for PDF
- Stripe integration (Checkout hosted page); webhook function to mark invoices paid
- Security rules: per‑company read; per‑role write matrix (+ tests) **Definition of Done**
- 95% of happy‑path tasks done; rules tests cover all write paths; sample invoices render to PDF
  with <3s p95; payment status updates idempotently.

### E2 — Jobs & Assignments

**Outcomes**

- Kanban board (Backlog → Scheduled → In‑Progress → Done), crew assignment, job site photos.
  **Deliverables**
- `features/jobs/...` + drag‑and‑drop lanes on Web; mobile list with quick status changes
- Storage paths & rules for job photos; size/type limits and crew‑only uploads **DoD**
- Realtime updates without jank (>60 fps on Web and Mobile); rules tests for crew‑only uploads.

### E3 — Timeclock Enhancements & Offline Sync

**Outcomes**

- Reliable clock in/out with queue; banners for offline; auto‑sync on reconnect; optional
  geofencing. **Deliverables**
- `NetworkStatus.onlineStream` drives queue drain; persistent `QueueItem` storage
- Optional GPS capture on clock events (config flag) **DoD**
- 0 data loss in chaos testing (airplane‑mode cycles); p75 startup ≤ 1200ms; scroll jank ≤ 1%.

### E4 — Admin & RBAC UI

**Outcomes**

- Admin panel to manage users/roles via `setUserRole` function; company settings. **Deliverables**
- `features/admin/users_screen.dart` with search, role assignment, audit log view **DoD**
- All role changes audited; unit + emulator tests verify claims document flow.

### E5 — Observability, SLOs, and Release

**Outcomes**

- Canary → prod pipeline; on‑call handbook; dashboards; error budget policy. **Deliverables**
- GitHub Actions: tag‑to‑prod; staging on push to `main`; rollback script; alerts
- Scorecard report generated per release **DoD**
- Canary runs 24–48h with no regressions; p95 Functions ≤ 600ms; error budget <1%.

---

## 3) 6 Sprint Plan (2 weeks each)

> **Capacity assumption:** 5 devs × ~25 effective hrs/week/dev = ~62–70 pts / sprint. Keep WIP low;
> 1 intent per PR.

### Sprint 1 — Environment parity & Invoice/Estimate foundations

- Fix Firebase aliases and deploy indexes to real staging/prod.
- Wire navigation & empty/detail screens for invoices/estimates.
- Form scaffolds with validation; repositories hardened with emulator tests.
- Telemetry smoke tests and initial dashboards. **Exit:** Staging functional for read + basic
  create; rules tests green; no CLI warnings.

### Sprint 2 — Invoice/Estimate edit flows + PDFs

- PDF service (Cloud Function) + Storage; email/share link.
- Status transitions (draft/sent/paid/canceled) with audit logs.
- Unit + emulator rules tests for all transitions. **Exit:** PDF created under 3s p95; secure
  Storage; payment stub in place.

### Sprint 3 — Stripe payments & webhooks

- Checkout session creation; webhook function to mark `paid`.
- Retry/idempotency keys; test mode + live mode configs.
- Admin export of paid invoices. **Exit:** End‑to‑end payment in staging; revenue events visible in
  Analytics.

### Sprint 4 — Jobs & Assignments

- Kanban board (web) + mobile list; assignment picker; job photo upload flows.
- Storage rules + tests; offline image queue with retries. **Exit:** Crew‑only uploads enforced;
  smooth drag & drop; perf traces stable.

### Sprint 5 — Timeclock offline & geofencing (optional)

- Queue‑driven timeclock; reconnect sync; conflict resolution.
- Optional GPS capture and geofence warnings (feature flag). **Exit:** Chaos testing passes; zero
  lost events; user‑visible offline indicators.

### Sprint 6 — Admin UI, release hardening & go‑live

- Users & roles screen; company settings.
- Canary release + on‑call runbook; rollback drills; performance tuning.
- Documentation (ADRs, runbooks), accessibility & UX polish. **Exit:** Canary → General
  Availability; scorecard + release notes generated.

---

## 4) Cross‑cutting quality bars (enforced every PR)

- Exactly **one module intent per PR**; reversible changes; before/after metrics if perf‑sensitive.
- No schema breaks without migration/backfill; rules & function tests must pass.
- Coverage gate at 40% now, nudge toward 45–50% by Sprint 6 via incremental tests.
- Mobile/Web smoke suites green; bundle/asset budgets enforced for web + mobile.
- App Check enforced (CI emulators bypass only).

---

## 5) Team & RACI (initial)

- **Tech Lead/Owner:** Claude (plans, reviews, merges, release captain)
- **FE Lead (Flutter):** Dev A — Invoices/Estimates UI, Jobs Kanban, Offline banners
- **BE/Functions:** Dev B — PDF/Stripe/webhooks, audit logs, rules
- **Platform/CI:** Dev C — Actions, canary/rollback, perf tracing, budgets
- **Mobile parity & QA:** Dev D — iOS/Android polish, camera flows, accessibility
- **Generalist:** Dev E — repositories/tests, admin UI, docs

---

## 6) Risks & mitigations

- **Project/permission drift:** lock `.firebaserc` and env docs; require alias in deploy scripts.
- **Rules complexity & warnings:** consolidate helpers; keep exhaustive emulator tests.
- **Cold starts/latency:** pin runtime; set `minInstances` for hot endpoints; simple response
  caching.
- **Docs drift:** update READMEs per module; CI doc‑link checker; monthly audit.
- **Payment failures:** webhook retries with idempotency; admin override tools.

---

## 7) DOR / DOD checklists

**Ready:** user story, API and rules impact, UI sketches, analytics events, acceptance tests
listed.  
**Done:** tests (unit + emulator) pass; telemetry added; docs updated; release notes & screenshots;
scorecard updated.

---

## 8) Useful commands (repeatable)

```bash
# Local emulators with seed data
firebase emulators:start --only auth,firestore,storage,functions

# Run rules and function tests
npm --prefix functions test

# Flutter tests (no platform channels)
./scripts/run_test_local_temp.ps1

# Integration tests with emulators
./scripts/run_integration_with_emulators.ps1 -- cmd /c "flutter test integration_test/bootstrap_test.dart"
```

---

## 9) Release train

- **Staging:** every `main` push auto‑deploys functions/rules/indexes/web.
- **Prod:** protected via tag `release/vX.Y.Z` + canary (read‑only) for 24–48h + explicit promote.
- **Rollback:** documented script + operator checklist; drill once per sprint.
