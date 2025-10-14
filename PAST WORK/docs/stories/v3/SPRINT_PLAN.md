# Sprint V3 - Lead Management & Scheduling

**Goal**: Enable lead capture and basic job scheduling.

**Duration**: 2-3 weeks

## Stories in Sprint

### Epic D: Lead Management & Scheduling
- 📋 **D1**: Public Lead Form (Est: M, Risk: L)
- 📋 **D2**: Admin Review Lead (Est: M, Risk: M)
- 📋 **D3**: Schedule Lite (Basic Job Creation) (Est: M, Risk: M)

## Cut Line Strategy

### Must Ship
- D1, D2, D3: Complete lead-to-job workflow

### Can Defer if Tight
- Advanced scheduling features (drag-and-drop, calendar view)

## Dependencies

```
V2 Complete ──> D1 (Public Lead Form)
                └──> D2 (Review Lead)
                     └──> D3 (Schedule Job)

D3 ──> B3 (Jobs Today integration)
```

## Acceptance Criteria (Sprint)

### Lead Capture (D1)
**GIVEN** a potential customer visits our website  
**WHEN** they submit the lead form  
**THEN** lead is created and admin is notified

### Lead Workflow (D2, D3)
**GIVEN** a new lead is submitted  
**WHEN** admin reviews and qualifies it  
**THEN** admin can convert it to a scheduled job  
**AND** assigned painters see it in Jobs Today

## Performance Targets

| Operation | Target (P95) |
|-----------|--------------|
| Lead form submission | ≤ 5s |
| Lead review load | ≤ 2s |
| Job creation | ≤ 3s |
