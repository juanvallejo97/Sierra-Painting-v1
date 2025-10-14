# Performance Budgets - Sierra Painting Staging

**Last Updated:** 2025-10-12
**Owner:** Engineering Team

---

## Executive Summary

Performance budgets define acceptable thresholds for application performance metrics. Exceeding these budgets triggers alerts and blocks deployments.

**Budget Philosophy:** Fast is better than slow. Users abandon apps that take >3 seconds to load.

---

## Web App Budgets

### Initial Load (Lighthouse Metrics)

| Metric | Budget | Current | Status | Impact |
|--------|--------|---------|--------|--------|
| **First Contentful Paint (FCP)** | < 1.8s | TBD | 🔴 Needs baseline | User sees content |
| **Largest Contentful Paint (LCP)** | < 2.5s | TBD | 🔴 Needs baseline | Main content visible |
| **Time to Interactive (TTI)** | < 3.8s | TBD | 🔴 Needs baseline | App is usable |
| **Total Blocking Time (TBT)** | < 300ms | TBD | 🔴 Needs baseline | Responsiveness |
| **Cumulative Layout Shift (CLS)** | < 0.1 | TBD | 🔴 Needs baseline | Visual stability |

**Target Lighthouse Score:** 90+ (Performance)

**Measurement Tool:** Lighthouse CI via `scripts/perf/check_web.sh`

---

### Bundle Size

| Asset | Budget | Current | Status |
|-------|--------|---------|--------|
| **main.dart.js** | < 2 MB | TBD | 🔴 Needs baseline |
| **Total JS** | < 3 MB | TBD | 🔴 Needs baseline |
| **Total Assets** | < 5 MB | TBD | 🔴 Needs baseline |

**Measurement:**
```bash
flutter build web --release
du -sh build/web/
ls -lh build/web/*.js
```

---

### API Response Time (Web → Functions)

| Endpoint | p50 | p95 | p99 | Status |
|----------|-----|-----|-----|--------|
| **clockIn** | < 500ms | < 1000ms | < 1500ms | 🔴 Needs baseline |
| **clockOut** | < 500ms | < 1000ms | < 1500ms | 🔴 Needs baseline |
| **setUserRole** | < 800ms | < 1500ms | < 2000ms | 🔴 Needs baseline |

**Measurement Tool:** Cloud Logging + `scripts/perf/check_functions.sh`

---

## Cloud Functions Budgets

### Cold Start

| Function | Budget | Current | Status | Priority |
|----------|--------|---------|--------|----------|
| **clockIn** | < 2s | TBD | 🔴 Needs baseline | High |
| **clockOut** | < 2s | TBD | 🔴 Needs baseline | High |
| **setUserRole** | < 3s | TBD | 🔴 Needs baseline | Medium |
| **autoClockOut** | < 5s | TBD | 🔴 Needs baseline | Low (scheduled) |

**Optimization Strategies:**
- Minimum instances: 1 for critical functions (clockIn, clockOut)
- Use Firebase Functions v2 (better cold start)
- Reduce dependencies (tree-shake unused imports)

---

### Memory Usage

| Function | Budget | Current | Status |
|----------|--------|---------|--------|
| **clockIn** | < 256 MB | TBD | 🔴 Needs baseline |
| **clockOut** | < 256 MB | TBD | 🔴 Needs baseline |
| **setUserRole** | < 256 MB | TBD | 🔴 Needs baseline |

**Measurement:**
```bash
gcloud functions describe clockIn --region=us-east4 --project=sierra-painting-staging --format="value(availableMemoryMb)"
```

---

### Execution Time

| Function | p95 Budget | p99 Budget | Status |
|----------|------------|------------|--------|
| **clockIn** | < 1.5s | < 2.5s | 🔴 Needs baseline |
| **clockOut** | < 1.5s | < 2.5s | 🔴 Needs baseline |
| **setUserRole** | < 2s | < 3s | 🔴 Needs baseline |

**Alert Threshold:** p95 exceeds budget for 5 consecutive minutes

---

## Mobile App Budgets

### App Startup Time (Android)

| Metric | Budget | Current | Status |
|--------|--------|---------|--------|
| **Time to first frame** | < 2s | TBD | 🔴 Needs baseline |
| **Time to interactive** | < 3s | TBD | 🔴 Needs baseline |

**Measurement:** Firebase Performance Monitoring trace: `app_boot`

---

### App Startup Time (iOS)

| Metric | Budget | Current | Status |
|--------|--------|---------|--------|
| **Time to first frame** | < 1.5s | TBD | 🔴 Needs baseline |
| **Time to interactive** | < 2.5s | TBD | 🔴 Needs baseline |

**Note:** iOS typically faster due to AOT compilation

---

## Firestore Budgets

### Read Operations (per user per day)

| Collection | Budget | Current | Status |
|------------|--------|---------|--------|
| **time_entries** | < 100 reads | TBD | 🔴 Needs baseline |
| **jobs** | < 50 reads | TBD | 🔴 Needs baseline |
| **users** | < 20 reads | TBD | 🔴 Needs baseline |

**Cost Impact:** 100K reads/day = $0.036/day = $1.08/month (negligible)

---

### Write Operations (per user per day)

| Collection | Budget | Current | Status |
|------------|--------|---------|--------|
| **time_entries** | < 10 writes | TBD | 🔴 Needs baseline |
| **auditLog** | < 20 writes | TBD | 🔴 Needs baseline |

**Cost Impact:** 50K writes/day = $0.18/day = $5.40/month (negligible)

---

## Baseline Capture Plan

**Step 1: Deploy to staging**
```bash
firebase deploy --project sierra-painting-staging
```

**Step 2: Capture web baseline**
```bash
bash scripts/perf/check_web.sh > baseline_web.txt
```

**Step 3: Capture functions baseline**
```bash
bash scripts/perf/check_functions.sh > baseline_functions.txt
```

**Step 4: Update this document**
- Replace "TBD" with actual values
- Set budgets at 90th percentile + 20% buffer

---

## Budget Enforcement

### CI/CD Pipeline

```yaml
# .github/workflows/staging.yml (add step)
- name: Check performance budgets
  run: |
    bash scripts/perf/check_web.sh
    # Fail if budgets exceeded
    if [ $? -ne 0 ]; then
      echo "Performance budget exceeded!"
      exit 1
    fi
```

### Monitoring Alerts

**Cloud Monitoring:** Alert if p95 latency > budget for 5 min
```
Resource: cloud_function
Metric: execution_times
Condition: p95 > 1500ms for 5 min
```

---

## Performance Optimization Checklist

- [ ] Enable Firebase Performance Monitoring
- [ ] Minimize instances: 1 for critical functions
- [ ] Tree-shake unused dependencies
- [ ] Compress images in web assets
- [ ] Enable HTTP/2 server push for critical resources
- [ ] Implement code splitting in Flutter web
- [ ] Add CDN for static assets (Firebase Hosting built-in)
- [ ] Profile functions with Chrome DevTools (Functions emulator)

---

## Regression Investigation Process

**When a budget is exceeded:**

1. **Identify regression commit:**
```bash
git log --oneline --since="3 days ago"
git bisect start
git bisect bad  # Current slow commit
git bisect good <last-known-good-commit>
```

2. **Profile the change:**
```bash
# For web
flutter run --profile -d chrome --dart-define=PROFILE=true

# For functions
firebase functions:shell --inspect
```

3. **Fix or revert:**
- Fix: Optimize hot path, remove blocking calls
- Revert: `git revert <commit-sha>` if fix takes >1 hour

---

## Budget Review Schedule

- **Weekly:** Review current vs budget (automated report)
- **Monthly:** Adjust budgets based on user growth
- **Quarterly:** Re-baseline all metrics

---

## References

- [Web Vitals](https://web.dev/vitals/)
- [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)
- [Firebase Performance](https://firebase.google.com/docs/perf-mon)
- [Cloud Functions Best Practices](https://cloud.google.com/functions/docs/bestpractices/tips)

---

**Baseline Status:** 🔴 Not captured (needs initial deployment)
**Next Review:** 2025-10-26
