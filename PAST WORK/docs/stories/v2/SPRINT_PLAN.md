# Sprint V2 - Invoicing & Timesheet

**Goal**: Enable invoice workflow and painter self-service timesheet viewing.

**Duration**: 2-3 weeks

**Priority**: All P0-P1 (must-ship to defer)

## Stories in Sprint

### Epic C: Invoicing (CORE FEATURE)
- 📋 **C1**: Create Quote + PDF (Est: L, Risk: M)
- 📋 **C2**: Quote → Invoice (Est: M, Risk: L)
- 📋 **C3**: Manual Mark Paid (Est: M, Risk: M)

### Epic B: Time Clock (ENHANCEMENTS)
- 📋 **B5**: Auto Clock-out Safety (Est: M, Risk: M)
- 📋 **B7**: My Timesheet (Weekly View) (Est: M, Risk: L)

**Legend**:
- 📋 To Do
- 🔄 In Progress
- ✅ Complete
- ⚠️ Blocked/At Risk

## Cut Line Strategy

### Must Ship
- C1, C2, C3: Core invoicing workflow (quote → invoice → paid)
- B5: Safety net for forgotten clock-outs

### Can Defer if Tight
- B7: Painters can view timesheets in V3 instead

### Cannot Defer
- C1-C3: Required for business operations (billing customers)
- B5: Prevents payroll issues from 24+ hour shifts

## Dependencies

```
V1 Complete ──┬──> C1 (Create Quote)
              │
              ├──> C2 (Quote → Invoice)
              │
              └──> C3 (Mark Paid)

B1, B2 (Clock in/out) ──> B5 (Auto Clock-out)
                        └──> B7 (My Timesheet)
```

## Definition of Ready (Sprint Level)

- [x] V1 stories completed
- [x] PDF generation library chosen (`pdfkit`)
- [x] Cloud Storage buckets configured
- [ ] Invoice templates designed
- [ ] Stripe account created (for future)

## Definition of Done (Sprint Level)

- [ ] All must-ship stories complete
- [ ] PDF generation working
- [ ] Invoice status tracking accurate
- [ ] Auto clock-out tested (12+ hour scenarios)
- [ ] Demo: create quote → convert → mark paid → PDF emailed

## Acceptance Criteria (Sprint)

### Quote Creation (C1)
**GIVEN** I am an admin  
**WHEN** I create a quote with line items  
**THEN** PDF is generated and emailed to customer within 30 seconds

### Invoice Workflow (C2, C3)
**GIVEN** customer accepts quote  
**WHEN** I convert to invoice and mark paid  
**THEN** status updates are tracked and audit logged

### Auto Clock-out (B5)
**GIVEN** a painter forgets to clock out  
**WHEN** 12 hours have passed  
**THEN** system automatically clocks them out with notification

## Risks & Mitigations

### Risk: PDF generation complexity
**Likelihood**: Medium  
**Impact**: High  
**Mitigation**:
- Use proven library (`pdfkit` or `puppeteer`)
- Start with simple template, iterate
- Test with various line item counts
- Timeout protection (30s max)

### Risk: Email delivery failures
**Likelihood**: Low  
**Impact**: Medium  
**Mitigation**:
- Use SendGrid or Firebase Extensions
- Retry logic for transient failures
- Log all email attempts
- Admin can manually resend

## Testing Strategy

### Integration Tests
- PDF generation: verify structure, content accuracy
- Quote → Invoice: verify data copied correctly
- Mark paid idempotency: same clientId returns cached result

### E2E Tests
- Admin creates quote → PDF downloaded → line items correct
- Convert quote → invoice created with same data
- Mark paid → status updates → audit log created

## Performance Targets

| Operation | Target (P95) | Metric |
|-----------|--------------|--------|
| PDF generation | ≤ 30s | Function execution time |
| Quote → Invoice | ≤ 2s | Conversion time |
| Mark paid | ≤ 2s | Status update time |
| Auto clock-out | Runs every 5 min | Cron schedule |

## Rollback Plan

1. **PDF issues**: Revert function, provide manual PDF creation
2. **Invoice corruption**: Restore from daily backup
3. **Auto clock-out issues**: Disable cron, manual clock-out only

## Next Sprint Preview (V3)

Focus shifts to **lead management and scheduling**:
- D1: Public lead form
- D2: Admin review lead
- D3: Schedule lite (job creation)

Cut line: Ship D1-D3, defer advanced scheduling to V4.
