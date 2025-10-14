# Feature Flags Guide

## Overview

Feature flags enable safe, gradual rollout of new features and provide runtime control over system behavior. This document describes how to use and manage feature flags in Sierra Painting Cloud Functions.

## Architecture

Feature flags are stored in Firestore at `config/flags` and cached in-memory for 30 seconds to minimize Firestore reads.

### Storage Structure

```typescript
// Firestore: config/flags
{
  "cache.localHotset": {
    enabled: false,
    type: "boolean",
    description: "Enable in-process LRU cache for hot data"
  },
  "tracing.sample": {
    enabled: true,
    value: 1.0,
    type: "number",
    description: "Trace sampling rate (0.0 to 1.0)"
  }
}
```

## Using Feature Flags

### Boolean Flags

```typescript
import { getFlag } from './lib/ops';

const cacheEnabled = await getFlag('cache.localHotset', false);
if (cacheEnabled) {
  // Use cache
}
```

### Numeric Flags

```typescript
const sampleRate = await getFlag('tracing.sample', 1.0);
if (Math.random() < sampleRate) {
  // Enable tracing for this request
}
```

### String Flags

```typescript
const mode = await getFlag('feature.mode', 'default');
```

## Current Flags

### Performance Flags

| Flag Name | Type | Default | Description |
|-----------|------|---------|-------------|
| `cache.localHotset` | boolean | false | Enable in-process LRU cache for hot data |
| `bundles.enable` | boolean | false | Enable Firestore bundles for bulk data loading |
| `tracing.sample` | number | 1.0 | Trace sampling rate (0.0 to 1.0) |

### Operational Flags

| Flag Name | Type | Default | Description |
|-----------|------|---------|-------------|
| `hedge.external` | boolean | false | Enable request hedging for external API calls |
| `canary.cohortPercent` | number | 0 | Percentage of users in canary cohort (0-100) |

## Managing Flags

### Initialize Flags

Run once during deployment to create the flags document:

```typescript
import { initializeFlags } from './lib/ops';

await initializeFlags();
```

### Update Flags via Firestore Console

1. Go to Firestore console
2. Navigate to `config/flags`
3. Update the flag values
4. Changes take effect within 30 seconds (cache TTL)

### Update Flags Programmatically

```typescript
import * as admin from 'firebase-admin';

const db = admin.firestore();
await db.collection('config').doc('flags').update({
  'cache.localHotset': {
    enabled: true,
    type: 'boolean',
    description: 'Enable in-process LRU cache for hot data'
  }
});
```

## Best Practices

### Naming Conventions

- Use dot notation: `category.feature`
- Categories: `cache`, `tracing`, `feature`, `canary`, `hedge`
- Use descriptive names: `cache.localHotset`, not `cache.c1`

### Default Values

- Boolean flags default to `false` (disabled) for safety
- Always provide a default value when calling `getFlag()`
- New features should start disabled

### Rollout Strategy

1. **Deploy with flag disabled**: Deploy code with new feature behind a flag
2. **Enable for testing**: Enable flag in dev/staging environment
3. **Canary rollout**: Enable for small percentage of users
4. **Full rollout**: Enable for all users
5. **Remove flag**: After feature is stable, remove flag and code

### Monitoring

- Monitor error rates after flag changes
- Set up alerts for unexpected behavior
- Use structured logging to track flag usage

### Rollback

If issues arise after enabling a flag:

1. **Immediate**: Disable flag in Firestore console
2. **Medium-term**: Investigate and fix issues
3. **Long-term**: Re-enable or remove flag

## Performance Impact

- **Firestore reads**: 1 read per 30 seconds per function instance
- **Memory**: ~10KB per instance (flag cache)
- **Latency**: <1ms per flag check (in-memory)

## Example: Adding a New Flag

1. **Define the flag** in `getDefaultFlags()`:

```typescript
// functions/src/lib/ops/flags.ts
'feature.newFeature': {
  enabled: false,
  type: 'boolean',
  description: 'Enable new feature X',
}
```

2. **Use the flag** in your code:

```typescript
import { getFlag } from './lib/ops';

const newFeatureEnabled = await getFlag('feature.newFeature', false);
if (newFeatureEnabled) {
  // New feature logic
}
```

3. **Deploy and test**:

```bash
npm run build
firebase deploy --only functions
```

4. **Enable in Firestore**:

Update `config/flags` document to enable the flag.

## Troubleshooting

### Flag not found

If a flag is not found, the default value is returned. Check:
- Flag name is correct (case-sensitive)
- `config/flags` document exists in Firestore
- Flag is properly formatted in Firestore

### Cache not updating

Flags are cached for 30 seconds. Wait 30 seconds after updating in Firestore for changes to take effect.

### Testing flags locally

Use Firebase emulators:

```bash
npm run server
```

Update flags in the Firestore emulator UI at http://localhost:4000

## See Also

- [Observability Guide](./observability.md) - Logging and tracing conventions
- [Runbooks](./runbooks/README.md) - Domain-specific operational guides
