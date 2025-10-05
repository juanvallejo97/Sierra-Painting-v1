# Update History

**Initialize governance framework** (this PR).

Track notable dependency upgrades, security patches, and breaking changes here.

## SyncStatus Centralization

**Date:** 2024-10  
**Type:** Architecture Improvement

Centralized sync-state management into a single source of truth:

- **Location:** `lib/core/models/sync_status.dart`
- **Purpose:** Single enum for sync states (`synced`, `pending`, `failed`)
- **Impact:** Prevents type conflicts and ensures consistency across app
- **Components:**
  - `SyncStatus` enum with three states
  - `SyncStatusX` extension for UI labels
  - `SyncStatusChip` widget in `lib/core/widgets/sync_status_chip.dart`
  - `GlobalSyncIndicator` for app-wide sync status

**Migration Note:** All widgets and services should import from 
`lib/core/models/sync_status.dart` to avoid duplicate enum definitions.
