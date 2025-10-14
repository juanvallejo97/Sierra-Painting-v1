# ADR-012: Sprint-Based Feature Flags

## Status
Accepted

## Date
2024-01-15

## Context
As we implement features across multiple sprints (V1-V4), we need a way to:
- Deploy code incrementally without exposing incomplete features
- Test features in production with internal users before public release
- Quickly disable problematic features without redeployment
- Support gradual rollout to manage risk
- Align feature releases with sprint boundaries

Traditional approaches have limitations:
- **Branch-based**: Long-lived feature branches cause merge conflicts and delayed integration
- **Manual toggles**: Environment variables require redeployment to change
- **Database flags**: Custom implementation, maintenance burden
- **No flags**: Must wait for full feature completion before any deployment

The PRD specifies sprint-based delivery (V1, V2, V3, V4) with clear cut lines. We need flags that:
- Map to sprint boundaries (V1 features, V2 features, etc.)
- Can be toggled remotely without code changes
- Support conditional rollout (internal → 10% → 50% → 100%)
- Are temporary (removed after full rollout)

## Decision

We adopt **Firebase Remote Config** for sprint-based feature flags with the following structure:

### 1. Flag Naming Convention
```
feature_<epic><story>_<action>_enabled

Examples:
- feature_b1_clock_in_enabled
- feature_c5_stripe_checkout_enabled
- feature_d1_lead_form_enabled
```

Pattern breakdown:
- `feature_`: Prefix for all feature flags
- `<epic><story>`: Story ID (B1, C5, D1)
- `<action>`: Short action description
- `_enabled`: Suffix for boolean flags

### 2. Default Values
All flags default to their sprint state:
```typescript
// V1 features (in production)
feature_b1_clock_in_enabled: true
feature_b2_clock_out_enabled: true

// V2 features (deployed but gated)
feature_c1_create_quote_enabled: false
feature_c2_quote_to_invoice_enabled: false

// V4 features (optional, behind flag indefinitely)
feature_c5_stripe_checkout_enabled: false
```

### 3. Implementation

#### Frontend (Flutter)
```dart
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService(FirebaseRemoteConfig.instance);
});

// Usage in widgets
class JobsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clockInEnabled = ref.watch(clockInEnabledProvider);
    
    if (clockInEnabled) {
      return ClockInButton();
    } else {
      return ComingSoonBanner();
    }
  }
}
```

#### Backend (Cloud Functions)
```typescript
export const createStripeCheckout = functions.https.onCall(async (data, context) => {
  // Check feature flag
  const stripeEnabled = process.env.STRIPE_CHECKOUT_ENABLED === 'true';
  
  if (!stripeEnabled) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Feature not available'
    );
  }
  // ... implementation
});
```

### 4. Flag Lifecycle

#### Stage 1: Development (OFF by default)
```json
{"feature_c5_stripe_checkout_enabled": false}
```
- Story C5 code merged to main
- Flag OFF, feature not visible to users
- Developers test locally with override

#### Stage 2: Internal Testing
```json
{
  "feature_c5_stripe_checkout_enabled": false,
  "conditions": [
    {
      "name": "internal_users",
      "condition": "user.email in ['team@sierrapainting.com']",
      "value": true
    }
  ]
}
```
- Enabled for team email addresses only
- Test in production environment
- Monitor for issues

#### Stage 3: Gradual Rollout
```json
{
  "conditions": [
    {"name": "10_percent", "condition": "percent <= 10", "value": true},
    {"name": "50_percent", "condition": "percent <= 50", "value": true},
    {"name": "100_percent", "value": true}
  ]
}
```
- Week 1: 10% of users
- Week 2: 50% of users
- Week 3: 100% of users
- Monitor metrics at each stage

#### Stage 4: Flag Removal (after 1-2 sprints)
```typescript
// Remove conditional logic
// Before:
if (featureEnabled) { doNewThing(); } else { doOldThing(); }

// After:
doNewThing();
```
- After 2 weeks at 100%, remove flag checks
- Feature is now permanent
- Clean up feature flag from Remote Config

### 5. Emergency Kill Switches
For critical issues requiring immediate rollback:
```json
// Flip flag to OFF in Firebase Console
{"feature_c5_stripe_checkout_enabled": false}

// Publish immediately
// Takes effect within minutes
// No app update or redeployment needed
```

## Consequences

### Positive
- **Continuous Integration**: Merge code frequently, enable features when ready
- **Risk Management**: Gradual rollout limits blast radius
- **Fast Rollback**: Disable features instantly without redeployment
- **Sprint Alignment**: Flags map to sprint deliverables (V1, V2, V3, V4)
- **Testing in Prod**: Internal users test features before public release
- **No Branch Divergence**: All code on main, flags control visibility
- **Monitoring**: Track adoption, errors, performance per flag state

### Negative
- **Code Complexity**: Conditional logic increases cyclomatic complexity
- **Testing Burden**: Must test both ON and OFF states
- **Flag Debt**: Old flags must be removed (requires discipline)
- **Cache Delay**: Remote Config has ~1 hour cache (use immediate for emergencies)
- **Dependency**: Relies on Firebase Remote Config availability

## Alternatives Considered

### 1. Long-Lived Feature Branches
**Why Not**: 
- Merge conflicts increase over time
- Integration issues discovered late
- Contradicts continuous integration principles
- Difficult to test combined feature set

**Tradeoff**: Simpler (no flag logic) but higher risk of integration bugs

### 2. Environment Variables
**Why Not**:
- Requires redeployment to change
- No gradual rollout capability
- Same value for all users (can't do 10% rollout)

**Tradeoff**: Simpler infrastructure but less flexible

### 3. Database-Based Flags
**Why Not**:
- Custom implementation and maintenance
- Need to build admin UI
- Extra latency for flag checks
- Firestore reads cost money at scale

**Tradeoff**: More control but higher cost and complexity

### 4. LaunchDarkly / Split.io
**Why Not**:
- Additional cost ($$$)
- External dependency
- More features than we need (A/B testing, experimentation)

**Tradeoff**: More powerful but overkill for sprint-based gating

### 5. No Feature Flags
**Why Not**:
- Must wait for complete feature before any deployment
- No way to test in production incrementally
- Higher risk (all-or-nothing releases)

**Tradeoff**: Simpler code but higher deployment risk

## Implementation Guidelines

### DO
- ✅ Create flag when starting story (default OFF)
- ✅ Test both enabled and disabled states
- ✅ Document flag owner and removal date
- ✅ Remove flags 1-2 sprints after 100% rollout
- ✅ Use consistent naming convention
- ✅ Keep flag checks simple (1 level deep max)

### DON'T
- ❌ Use flags for bug fixes (just deploy the fix)
- ❌ Keep flags longer than 2 sprints at 100%
- ❌ Nest flag checks (hard to reason about)
- ❌ Use flags for A/B testing (different tool)
- ❌ Create flags without removal plan

## Monitoring

Track these metrics per flag state:
- **Adoption Rate**: % users with flag enabled
- **Error Rate**: Errors per flag state (ON vs OFF)
- **Performance**: P95 latency (ON vs OFF)
- **User Actions**: Feature usage when enabled

Alert on:
- Error rate spike after enabling flag
- Performance degradation (> 10% P95 increase)
- Zero adoption (indicates rollout stuck)

## Sprint-to-Flag Mapping

### V1 (Currently Active)
- `feature_b1_clock_in_enabled: true`
- `feature_b2_clock_out_enabled: true`
- `feature_b3_jobs_today_enabled: true`

### V2 (Deploy week of X, enable week of Y)
- `feature_c1_create_quote_enabled: false → true`
- `feature_c2_quote_to_invoice_enabled: false → true`
- `feature_c3_mark_paid_enabled: false → true`

### V3 (Future)
- `feature_d1_lead_form_enabled: false`
- `feature_d2_review_lead_enabled: false`
- `feature_d3_schedule_lite_enabled: false`

### V4 (Optional Features)
- `feature_c5_stripe_checkout_enabled: false` (may stay OFF)
- `admin_kpi_dashboard_enabled: false`

## References
- [Feature Toggles (Martin Fowler)](https://martinfowler.com/articles/feature-toggles.html)
- [Firebase Remote Config](https://firebase.google.com/docs/remote-config)
- [Trunk Based Development](https://trunkbaseddevelopment.com/)
- [docs/FEATURE_FLAGS.md](../FEATURE_FLAGS.md) - Detailed implementation guide
- Sierra Painting PRD - Sprint planning and cut lines
