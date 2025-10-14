# Sprint V4 - Polish & Advanced Features

**Goal**: Add payment processing, refunds, and business intelligence.

**Duration**: 2-3 weeks

## Stories in Sprint

### Epic C: Invoicing (Advanced)
- 📋 **C5**: Stripe Checkout (Est: L, Risk: H)
- 📋 **C6**: Refund/Void (Est: M, Risk: M)

### Epic E: Operations (Advanced)
- 📋 **E4**: KPI Dashboard Tiles (Est: L, Risk: M)
- 📋 **E5**: Cost Alerts (Est: M, Risk: L)

## Cut Line Strategy

### Must Ship
- C5: Stripe integration (high value feature)
- E4: KPI dashboard (business visibility)

### Can Defer if Tight
- C6: Refunds (admin can handle manually)
- E5: Cost alerts (nice-to-have monitoring)

## Dependencies

```
V2 Complete (C1-C3) ──> C5 (Stripe Checkout)
                       └──> C6 (Refund/Void)

V1-V3 Telemetry ──> E4 (KPI Dashboard)
                   └──> E5 (Cost Alerts)
```

## Performance Targets

| Operation | Target (P95) |
|-----------|--------------|
| Stripe checkout creation | ≤ 5s |
| Dashboard load | ≤ 3s |
| Refund processing | ≤ 5s |
