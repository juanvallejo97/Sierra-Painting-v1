# Epic D: Lead Management & Scheduling

## Overview
Public lead capture form, admin lead review, and lightweight job scheduling to bridge the gap between customer inquiry and time tracking.

## Goals
- Capture leads from public website form
- Admin review and qualification
- Basic job scheduling
- Crew assignment to jobs
- Integration with time clock (B1, B2)

## Stories

### V3 (Lead & Schedule Foundation)
- **D1**: Public Lead Form (P0, M, L)
  - Public-facing form (no auth required)
  - Customer info: name, email, phone, address
  - Service details: type, description
  - File uploads (photos)
  - reCAPTCHA spam protection
  
- **D2**: Admin Review Lead (P0, M, M)
  - View submitted leads
  - Qualify/disqualify
  - Add notes
  - Convert to job
  
- **D3**: Schedule Lite (Basic Job Creation) (P0, M, M)
  - Create job with date, address, crew
  - Assign painters to crew
  - Set job status (scheduled, in_progress, completed)
  - View in Jobs Today (B3)

### Future Enhancements (V4+)
- **D4**: Calendar View
- **D5**: Drag-and-Drop Scheduling
- **D6**: Automatic Lead Assignment
- **D7**: Lead Scoring

## Key Data Models

### Lead Document
```
leads/{leadId}
  customerName: string
  email: string
  phone: string
  address: string
  serviceType: 'interior' | 'exterior' | 'commercial' | 'other'
  description: string
  photoUrls: string[]
  status: 'new' | 'reviewed' | 'qualified' | 'disqualified' | 'converted'
  notes: string | null
  reviewedBy: string | null  // Admin UID
  reviewedAt: Timestamp | null
  convertedToJobId: string | null
  createdAt: Timestamp
  updatedAt: Timestamp
```

### Job Document (Extended)
```
jobs/{jobId}
  orgId: string
  name: string
  address: string
  scheduledDate: string  // 'YYYY-MM-DD'
  crewIds: string[]      // Array of assigned painter UIDs
  status: 'scheduled' | 'in_progress' | 'completed' | 'cancelled'
  leadId: string | null  // If created from lead
  notes: string | null
  createdAt: Timestamp
  updatedAt: Timestamp
```

## Technical Approach

### Public Lead Form
- Hosted on Firebase Hosting or subdomain
- No authentication required
- reCAPTCHA v3 for spam protection
- Cloud Function validates and creates lead document
- Email notification to admin

### Lead Review Workflow
1. Admin sees new leads in dashboard
2. Reviews details and photos
3. Adds notes (e.g., pricing estimate)
4. Qualifies or disqualifies
5. Converts qualified lead to scheduled job

### Job Scheduling
1. Admin creates job with date and address
2. Assigns painters to crew (multi-select)
3. Job appears in each painter's "Jobs Today" (B3)
4. Painters can clock in/out for the job (B1, B2)

## Success Metrics
- Lead form submission rate: Track completion vs abandonment
- Lead spam rate: <5% (reCAPTCHA effectiveness)
- Lead-to-job conversion rate: Target >40%
- Job creation time: P95 <2 minutes (admin efficiency)
- Crew assignment accuracy: 100% (no missed assignments)

## Dependencies
- Epic A: Authentication (admin access for D2, D3)
- Epic B: Time Clock (job integration for B3, B1, B2)
- Firebase Hosting for public form
- Cloud Storage for photo uploads
- reCAPTCHA Enterprise

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
- [reCAPTCHA Documentation](https://developers.google.com/recaptcha)
