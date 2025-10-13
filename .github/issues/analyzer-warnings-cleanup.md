# Drive Analyzer Warnings to Zero (Post-Trial)

**Status**: Tracked for Month 2
**Priority**: P2 (Technical Debt)
**Effort**: 1-2 hours

## Context

After baseline health fixes, we achieved **82% reduction** in analyzer issues (74 → 13). Remaining 13 are cosmetic and located in test/skeleton files. This issue tracks final cleanup.

## Acceptance Criteria

- [ ] All `flutter analyze` issues resolved (target: 0 issues)
- [ ] Pre-commit hook passes without `--no-verify`
- [ ] No behavior changes (tests remain green)

## Tasks

### High Priority (Affects CI)
- [ ] Add `unawaited(...)` for 3 integration tests
  - `integration_test/e2e_demo_test.dart:79` - emulator setup
  - `integration_test/offline_queue_test.dart:82` - emulator setup
  - `integration_test/timeclock_geofence_test.dart:59` - emulator setup

- [ ] Add `if (!context.mounted) return;` in 2 async callbacks
  - `lib/features/timeclock/presentation/worker_dashboard_screen.dart:454`
  - `lib/features/timeclock/presentation/worker_dashboard_screen_v2.dart:490`

### Low Priority (Skeleton/Guide Files)
- [ ] Mark intentional skeleton sections with `// ignore: dead_code`
  - `lib/features/admin/presentation/widgets/time_entry_card.dart` (5 warnings)
  - `lib/features/timeclock/presentation/worker_dashboard_screen_v2.dart` (1 warning)

- [ ] Add `unawaited()` for showDialog in v2 screen
  - `lib/features/timeclock/presentation/worker_dashboard_screen_v2.dart:710`

## Analyzer Output (Current State)

```
13 issues found:

info - Missing an 'await' for the 'Future' computed by this expression (3)
  - integration_test\e2e_demo_test.dart:79:12
  - integration_test\offline_queue_test.dart:82:12
  - integration_test\timeclock_geofence_test.dart:59:12

warning - Dead code (6)
  - lib\features\admin\presentation\widgets\time_entry_card.dart:103, 210, 211, 217, 224
  - lib\features\timeclock\presentation\worker_dashboard_screen_v2.dart:79

info - Don't use 'BuildContext's across async gaps (2)
  - lib\features\timeclock\presentation\worker_dashboard_screen.dart:454:34
  - lib\features\timeclock\presentation\worker_dashboard_screen_v2.dart:490:11

info - Missing an 'await' (2)
  - lib\features\timeclock\presentation\worker_dashboard_screen.dart:80:39
  - lib\features\timeclock\presentation\worker_dashboard_screen_v2.dart:710:5
```

## Safety Checklist

- [ ] Run `flutter analyze` - 0 issues
- [ ] Run `flutter test` - all passing
- [ ] Verify no behavior changes (compare test output)
- [ ] Re-enable strict pre-commit hook

## Related

- Baseline Health PR: #[TBD]
- Overnight Report: See `OVERNIGHT_REPORT_2025-10-13.md`
