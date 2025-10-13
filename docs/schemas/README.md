# Sierra Painting - Canonical Data Schemas

**Version:** 2.0 (Option B Stability Patch)
**Date:** 2025-10-12
**Status:** ✅ CANONICAL - All code must reference these schemas

---

## Purpose

This directory contains the **single source of truth** for all data structures used across:
- Cloud Functions (Node.js/TypeScript)
- Flutter app (Dart)
- Firestore documents
- Firebase Security Rules

---

## Schema Files

| Entity | File | Description |
|--------|------|-------------|
| User | [user.md](./user.md) | Worker/admin user accounts and custom claims |
| Job | [job.md](./job.md) | Job sites with geofence definitions |
| Assignment | [assignment.md](./assignment.md) | Worker-to-job assignments |
| TimeEntry | [time_entry.md](./time_entry.md) | Clock in/out records with geolocation |

---

## Naming Conventions

### Field Naming Standard
- Use **camelCase** for all field names (e.g., `userId`, `clockInAt`)
- Use **full words**, not abbreviations (e.g., `latitude` not `lat`, except for legacy compatibility)
- Use **At suffix** for timestamps (e.g., `createdAt`, `clockInAt`)
- Use **Id suffix** for references (e.g., `userId`, `jobId`)

### Legacy Compatibility
Some code may reference legacy field names (e.g., `workerId` → `userId`, `clockIn` → `clockInAt`).

**Migration Strategy:**
- Read BOTH old and new field names during transition period (2 weeks)
- Write ONLY new canonical names
- Log deprecation warnings when old names are encountered
- Remove legacy fallbacks on: **2025-10-26**

---

## Type Definitions

### TypeScript (Cloud Functions)
See `functions/src/types.ts` for canonical TypeScript interfaces.

### Dart (Flutter)
See `lib/core/models/` for canonical Dart classes.

---

## Validation Rules

All schemas must satisfy:
1. **Required fields** - Cannot be null/undefined
2. **Field types** - Must match specified type
3. **Firestore rules** - Must pass security rules validation
4. **Indexes** - Composite indexes must exist for queries

---

## Schema Change Process

To modify a schema:
1. Update this documentation FIRST
2. Update TypeScript types in `functions/src/types.ts`
3. Update Dart models in `lib/core/models/`
4. Update Firestore rules if permissions change
5. Add migration script if existing data needs transformation
6. Update tests
7. Get PR approval from team lead

**Never** change schemas directly in code without updating docs.

---

## References

- [Firestore Data Model Best Practices](https://firebase.google.com/docs/firestore/data-model)
- [TypeScript Type Definitions](../../functions/src/types.ts)
- [Flutter Models](../../lib/core/models/)
- [Firestore Rules](../../firestore.rules)
- [Comprehensive Bug Report](../../COMPREHENSIVE_BUG_REPORT.md)

---

**Last Updated:** 2025-10-12
**Owned By:** Engineering Team
