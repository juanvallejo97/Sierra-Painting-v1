# Feature Flags

## Overview
Feature flags allow us to:
- Deploy code to production but keep features disabled
- Gradually roll out features to subsets of users
- Quickly disable problematic features without redeployment
- Test features in production with internal users first

## Implementation

### Backend: Firebase Remote Config
We use Firebase Remote Config for centralized feature flag management.

#### Setup
```bash
# In Firebase Console:
# 1. Navigate to Remote Config
# 2. Add parameters with default values
# 3. Create conditions for gradual rollout
```

#### Default Values (functions/src/config/feature-flags.ts)
```typescript
export const DEFAULT_FEATURE_FLAGS = {
  // Sprint-based flags
  feature_b1_clock_in_enabled: true,        // V1
  feature_b2_clock_out_enabled: true,       // V1
  feature_b3_jobs_today_enabled: true,      // V1
  feature_c1_create_quote_enabled: false,   // V2
  feature_c2_quote_to_invoice_enabled: false, // V2
  feature_c3_mark_paid_enabled: false,      // V2
  feature_c5_stripe_checkout_enabled: false, // V4 (behind flag)
  
  // Operational flags
  offline_mode_enabled: true,
  gps_tracking_enabled: true,
  auto_clockout_enabled: false,             // V2
  
  // Performance flags
  enable_performance_monitoring: true,
  enable_crash_reporting: true,
  
  // Admin features
  admin_time_edit_enabled: false,           // V3-V4
  admin_kpi_dashboard_enabled: false,       // V4
};

export type FeatureFlags = typeof DEFAULT_FEATURE_FLAGS;
```

### Frontend: Flutter Remote Config

#### lib/core/services/feature_flag_service.dart
```dart
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeatureFlagService {
  final FirebaseRemoteConfig _remoteConfig;
  
  FeatureFlagService(this._remoteConfig);
  
  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    
    // Set defaults matching backend
    await _remoteConfig.setDefaults({
      'feature_b1_clock_in_enabled': true,
      'feature_b2_clock_out_enabled': true,
      'feature_b3_jobs_today_enabled': true,
      'feature_c1_create_quote_enabled': false,
      'feature_c2_quote_to_invoice_enabled': false,
      'feature_c3_mark_paid_enabled': false,
      'feature_c5_stripe_checkout_enabled': false,
      'offline_mode_enabled': true,
      'gps_tracking_enabled': true,
      'auto_clockout_enabled': false,
      'enable_performance_monitoring': true,
      'enable_crash_reporting': true,
      'admin_time_edit_enabled': false,
      'admin_kpi_dashboard_enabled': false,
    });
    
    // Fetch latest values
    await _remoteConfig.fetchAndActivate();
  }
  
  bool isEnabled(String flagName) {
    return _remoteConfig.getBool(flagName);
  }
  
  String getString(String key) {
    return _remoteConfig.getString(key);
  }
  
  int getInt(String key) {
    return _remoteConfig.getInt(key);
  }
}

// Provider
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService(FirebaseRemoteConfig.instance);
});

// Convenience providers for specific flags
final clockInEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled('feature_b1_clock_in_enabled');
});

final stripeCheckoutEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled('feature_c5_stripe_checkout_enabled');
});
```

### Usage in Code

#### Conditional Feature Rendering
```dart
class JobsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clockInEnabled = ref.watch(clockInEnabledProvider);
    
    return Scaffold(
      body: Column(
        children: [
          // Always show job list
          JobsList(),
          
          // Conditionally show clock-in button
          if (clockInEnabled)
            ClockInButton()
          else
            DisabledFeatureBanner(
              message: 'Clock-in feature coming soon!',
            ),
        ],
      ),
    );
  }
}
```

#### Backend Function Gating
```typescript
import {DEFAULT_FEATURE_FLAGS} from './config/feature-flags';

export const createStripeCheckout = functions.https.onCall(async (data, context) => {
  // Check feature flag (in production, fetch from Remote Config)
  const stripeEnabled = process.env.STRIPE_CHECKOUT_ENABLED === 'true' || 
                        DEFAULT_FEATURE_FLAGS.feature_c5_stripe_checkout_enabled;
  
  if (!stripeEnabled) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Stripe checkout is not currently available'
    );
  }
  
  // ... rest of implementation
});
```

## Flag Lifecycle

### Stage 1: Development
```json
{
  "feature_xyz_enabled": false,  // Disabled by default
  "conditions": []
}
```
- Flag created with default OFF
- Developers test locally by overriding
- Not visible to users

### Stage 2: Internal Testing
```json
{
  "feature_xyz_enabled": false,
  "conditions": [
    {
      "name": "internal_users",
      "condition": "user.email in ['team@sierrapainting.com']",
      "value": true
    }
  ]
}
```
- Enabled for internal email addresses
- Team tests in production environment
- Monitor for issues

### Stage 3: Gradual Rollout
```json
{
  "feature_xyz_enabled": false,
  "conditions": [
    {
      "name": "10_percent_rollout",
      "condition": "percent <= 10",
      "value": true
    }
  ]
}
```
- Enabled for 10% of users
- Monitor metrics, errors, performance
- Gradually increase to 25%, 50%, 100%

### Stage 4: Full Rollout
```json
{
  "feature_xyz_enabled": true,
  "conditions": []
}
```
- Enabled for all users
- Monitor for 1-2 weeks

### Stage 5: Flag Removal (after 1 sprint)
```typescript
// Remove flag checks from code
// Feature is now permanent

// Before:
if (featureXyzEnabled) {
  doNewThing();
} else {
  doOldThing();
}

// After:
doNewThing();
```

## Sprint-Based Flags

### Sprint V1 (Active)
- `feature_b1_clock_in_enabled`: ✅ ON
- `feature_b2_clock_out_enabled`: ✅ ON
- `feature_b3_jobs_today_enabled`: ✅ ON

### Sprint V2 (Upcoming)
- `feature_c1_create_quote_enabled`: 🔒 OFF until V2 deploys
- `feature_c2_quote_to_invoice_enabled`: 🔒 OFF
- `feature_c3_mark_paid_enabled`: 🔒 OFF

### Sprint V4 (Future)
- `feature_c5_stripe_checkout_enabled`: 🔒 OFF (optional feature)
- `admin_kpi_dashboard_enabled`: 🔒 OFF

## Emergency Kill Switches

For immediate rollback without redeployment:

### Scenario: Clock-in causing crashes
```json
// In Firebase Console → Remote Config
{
  "feature_b1_clock_in_enabled": false  // Flip to OFF
}

// Publish immediately
// Users get updated value within minutes
// Feature disabled without app update
```

### Scenario: Stripe payments failing
```json
{
  "feature_c5_stripe_checkout_enabled": false
}

// Manual payments still work
// Users see "Online payments temporarily unavailable"
```

## Testing Feature Flags

### Unit Tests
```dart
test('ClockInButton hidden when flag disabled', () {
  final container = ProviderContainer(
    overrides: [
      clockInEnabledProvider.overrideWithValue(false),
    ],
  );
  
  final widget = ProviderScope(
    parent: container,
    child: JobsScreen(),
  );
  
  final tester = WidgetTester();
  await tester.pumpWidget(widget);
  
  expect(find.byType(ClockInButton), findsNothing);
  expect(find.text('Clock-in feature coming soon!'), findsOneWidget);
});
```

### Integration Tests
```typescript
describe('Feature flags', () => {
  it('should reject Stripe checkout when disabled', async () => {
    process.env.STRIPE_CHECKOUT_ENABLED = 'false';
    
    await expect(
      createStripeCheckout({ invoiceId: 'inv123' })
    ).rejects.toThrow('not currently available');
  });
});
```

## Best Practices

### DO
- ✅ Use flags for new features in sprints V2+
- ✅ Remove flags 1-2 sprints after 100% rollout
- ✅ Document flag purpose and owner
- ✅ Test both ON and OFF states
- ✅ Use meaningful flag names (`feature_<story>_<action>_enabled`)

### DON'T
- ❌ Use flags for bug fixes (just deploy the fix)
- ❌ Keep flags indefinitely (causes code clutter)
- ❌ Nest flags deeply (1 level max)
- ❌ Use flags for A/B testing (use dedicated tool)

## Monitoring

### Metrics to Track
- Feature adoption rate (% users with flag ON)
- Error rate per flag state
- Performance impact (flag ON vs OFF)
- User feedback by flag state

### Alerts
```yaml
# Example: Alert if Stripe failure rate > 5%
alert: stripe_failure_rate_high
condition: stripe_errors / stripe_attempts > 0.05
notify: #engineering, #product
action: Consider disabling feature_c5_stripe_checkout_enabled
```

## Documentation Template

When adding a new flag, document it:

```markdown
### feature_xyz_enabled

**Owner**: @username
**Story**: C5 (Stripe Checkout)
**Sprint**: V4
**Default**: false
**Purpose**: Enable/disable Stripe payment option
**Dependencies**: Stripe API configured, webhook handler deployed
**Rollout Plan**:
  - Week 1: Internal testing
  - Week 2: 10% rollout
  - Week 3: 50% rollout
  - Week 4: 100% rollout
**Removal Date**: 2 weeks after 100% rollout (estimate: Week 6)
```

## Remote Config Setup

### Firebase Console Steps
1. Open Firebase Console → Remote Config
2. Click "Add parameter"
3. Enter flag name: `feature_b1_clock_in_enabled`
4. Set default value: `true` (boolean)
5. (Optional) Add conditions:
   - Name: `staging_environment`
   - Condition: `app.appId == 'com.sierrapainting.staging'`
   - Value: `true`
6. Click "Publish changes"

### Environment-Specific Values
```json
{
  "feature_c5_stripe_checkout_enabled": {
    "defaultValue": false,
    "conditions": [
      {
        "name": "production",
        "condition": "app.appId == 'com.sierrapainting.prod'",
        "value": false  // Still OFF in prod until ready
      },
      {
        "name": "staging",
        "condition": "app.appId == 'com.sierrapainting.staging'",
        "value": true   // ON in staging for testing
      }
    ]
  }
}
```

## References
- [Firebase Remote Config Docs](https://firebase.google.com/docs/remote-config)
- [Feature Flag Best Practices](https://martinfowler.com/articles/feature-toggles.html)
- [ADR-012: Sprint-Based Feature Flags](../adrs/012-sprint-based-flags.md)
