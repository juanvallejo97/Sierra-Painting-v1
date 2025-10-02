# Sierra Painting Backend - Schema Architecture

## Overview

This document explains the schema architecture used in the Sierra Painting backend Cloud Functions. Understanding this structure is critical for maintaining consistency and avoiding compilation errors.

## Schema Files

### 1. `src/schemas/index.ts` - Primary Schema Source

**Purpose**: Contains lightweight, PRD-aligned schemas that follow the project's design principles.

**Design Principles**:
- Keep schemas ≤10 lines when possible
- Use strict validation (no `.passthrough()`)
- Server timestamps in ISO-8601 (America/New_York)
- All schemas match story acceptance criteria

**Key Schemas**:
- `TimeInSchema` - Clock-in with GPS and idempotency
- `TimeOutSchema` - Clock-out with break tracking
- `ManualPaymentSchema` - Manual payment (check/cash)
  - Properties: `method`, `reference`, `note`, `idempotencyKey`
- `LeadSchema` - Public lead form submission
- `EstimateSchema` - Estimate creation with line items
- `LoginSchema` - User authentication
- `SetRoleSchema` - Admin role assignment
- `AuditLogSchema` - Audit trail entries

**Used by**: `src/index.ts` (main Cloud Functions entry point)

### 2. `src/lib/zodSchemas.ts` - Comprehensive Schema Library

**Purpose**: More comprehensive schemas with additional validation and documentation.

**Key Schemas**:
- `LeadSchema` - Extended with captcha validation
- `EstimateSchema` - Full estimate document structure
- `InvoiceSchema` - Complete invoice with payment tracking
- `ManualPaymentSchema` - Different from schemas/index.ts version
  - Properties: `paymentMethod`, `checkNumber`, `notes`, `idempotencyKey`
- `TimeEntrySchema` - Full time entry document
- `UserSchema` - User profile structure
- `AuditLogEntrySchema` - Detailed audit log format

**Used by**: Individual function modules in domain folders (leads/, payments/, etc.)

## Import Guidelines

### Main Entry Point (`src/index.ts`)

```typescript
// Use lightweight schemas from schemas/
import { TimeInSchema, ManualPaymentSchema } from "./schemas";
```

### Individual Function Modules

```typescript
// Use comprehensive schemas from lib/
import { ManualPaymentSchema, InvoiceSchema } from "../lib/zodSchemas";
```

## Schema Property Naming Conventions

### ManualPaymentSchema Variants

**schemas/index.ts version**:
```typescript
{
  invoiceId: string,
  method: 'check' | 'cash',        // ← note: 'method'
  reference: string (optional),     // ← generic reference
  note: string,                     // ← note: 'note' (required)
  idempotencyKey: string (optional)
}
```

**lib/zodSchemas.ts version**:
```typescript
{
  invoiceId: string,
  amount: number,
  paymentMethod: 'check' | 'cash', // ← note: 'paymentMethod'
  checkNumber: string (optional),   // ← specific to checks
  notes: string (optional),         // ← note: 'notes' (optional)
  idempotencyKey: string (optional)
}
```

## Migration Path

The codebase is currently in a transitional state:

1. **Legacy functions** in `src/index.ts` use `schemas/index.ts`
2. **New modular functions** in domain folders use `lib/zodSchemas.ts`
3. **Future goal**: Consolidate to a single schema source

## Common Pitfalls

### ❌ Wrong Import
```typescript
// Don't use lib/zodSchemas in index.ts
import { TimeInSchema } from "./lib/zodSchemas"; // ERROR: doesn't exist there
```

### ✅ Correct Import
```typescript
// Use schemas/ for index.ts
import { TimeInSchema } from "./schemas";
```

### ❌ Wrong Property Names
```typescript
// Using lib/zodSchemas property names with schemas/index.ts schema
const validated = ManualPaymentSchema.parse(data); // from schemas/
await db.collection("payments").add({
  paymentMethod: validated.paymentMethod, // ERROR: property is 'method'
  notes: validated.notes,                  // ERROR: property is 'note'
});
```

### ✅ Correct Property Names
```typescript
// Match the schema you're using
const validated = ManualPaymentSchema.parse(data); // from schemas/
await db.collection("payments").add({
  paymentMethod: validated.method,    // ✓
  notes: validated.note,              // ✓
});
```

## Troubleshooting

### Build Error: Module has no exported member

**Symptom**:
```
error TS2614: Module '"./lib/zodSchemas"' has no exported member 'TimeInSchema'
```

**Solution**: Check which schema file exports that schema and update your import.

### Build Error: Property does not exist on type

**Symptom**:
```
error TS2339: Property 'method' does not exist on type '{ paymentMethod: ... }'
```

**Solution**: You're using properties from one schema variant with another. Check the schema definition and use the correct property names.

## Future Work

- [ ] Consolidate schemas to single source of truth
- [ ] Add schema versioning for API evolution
- [ ] Generate TypeScript types from schemas
- [ ] Add runtime schema validation tests
- [ ] Document all schema changes in CHANGELOG

## References

- PRD: `docs/KickoffTicket.md`
- Main entry point: `src/index.ts`
- Primary schemas: `src/schemas/index.ts`
- Comprehensive schemas: `src/lib/zodSchemas.ts`
