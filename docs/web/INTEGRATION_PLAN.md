# Web Integration Plan - Next.js Implementation

> **Version:** 1.0.0  
> **Status:** In Progress  
> **Last Updated:** 2025  
> **Author:** Development Team

---

## Overview

This document outlines the comprehensive integration plan for bringing a Next.js web application into the existing Sierra Painting architecture, which currently consists of a Flutter mobile app and Firebase backend.

### Goals

1. **Seamless Integration**: Mount Next.js web app under the main domain with shared auth/session
2. **Zero Breakage**: Maintain all existing mobile and backend functionality
3. **Performance & SEO**: Implement SSR/SSG/ISR for optimal web performance
4. **Observability**: Full logging, metrics, and monitoring
5. **Safe Rollout**: Feature flags and canary deployment strategy

### Non-Goals

- No UI visual redesign (mobile design is source of truth)
- No backend contract changes
- No unnecessary dependency updates

---

## Architecture Strategy

### Domain Strategy

**Option 1: Path-Based Routing (Chosen)**
- Main domain serves both mobile (Flutter) and web (Next.js) assets
- `/api/**` → Firebase Cloud Functions (backend APIs)
- `/web/**` → Next.js app (web application)
- `/` → Flutter web build (mobile-first landing)

**Rationale**: 
- Simpler deployment model
- Single domain for auth cookies
- No CORS complications
- Easier SSL/CDN management

**Option 2: Subdomain (Alternative)**
- `web.sierrapainting.com` → Next.js
- `api.sierrapainting.com` → Backend APIs
- Requires shared cookie domain (`.sierrapainting.com`)
- More complex DNS/SSL setup

### SSR vs SSG/ISR Strategy

| Page Type | Strategy | Rationale |
|-----------|----------|-----------|
| `/login` | SSG | Static form, auth happens client-side |
| `/timeclock` | SSR | Personalized, real-time job data |
| `/invoices` | SSR | User-specific financial data |
| `/estimates` | SSR | User-specific quote data |
| `/admin` | SSR | Role-gated, personalized dashboard |
| Public Marketing | SSG + ISR | SEO-optimized, revalidate every 24h |

### Auth & Session Model

**Implementation**: Firebase Auth with server-side session validation

1. **Client Login**: Firebase Auth SDK handles authentication
2. **Session Token**: Store Firebase ID token in httpOnly cookie
3. **Server Middleware**: Verify token on protected routes
4. **Token Refresh**: Automatic refresh via Firebase SDK
5. **Shared State**: Same Firebase project as mobile app

**Security Headers**:
- `SameSite=Lax` for CSRF protection
- `HttpOnly` to prevent XSS
- `Secure` flag in production
- Cookie domain set appropriately for routing strategy

---

## Rollout Plan

### Phase 1: Internal Testing (Week 1)
- Deploy to staging environment
- Internal team testing
- Feature flag: `web.enabled = false` (default)

### Phase 2: Canary (Week 2)
- Enable for 5% of authenticated users
- Monitor error rates, latency, Core Web Vitals
- Feature flag: `web.canaryPercent = 5`

### Phase 3: Gradual Rollout (Week 3-4)
- Increase to 25%, 50%, 100% over 2 weeks
- Monitor metrics at each stage
- Rollback plan ready at each step

### Phase 4: General Availability (Week 5)
- 100% traffic to web app
- Remove feature flags
- Archive rollback artifacts

### Rollback Triggers

Automatic rollback if:
- Error rate > 5% increase
- P95 latency > 2s
- LCP > 2.5s
- Firebase quota exceeded

Manual rollback for:
- Critical security issue
- Data integrity concerns
- Business-critical functionality broken

---

## Performance Targets

### Core Web Vitals
- **LCP (Largest Contentful Paint)**: < 2.5s (Good)
- **FID (First Input Delay)**: < 100ms (Good)
- **CLS (Cumulative Layout Shift)**: < 0.1 (Good)
- **INP (Interaction to Next Paint)**: < 200ms (Good)

### Bundle Sizes
- **Initial JS**: < 150KB (gzipped)
- **Total JS**: < 400KB (gzipped)
- **CSS**: < 50KB (gzipped)

### API Response Times
- **SSR Time**: < 800ms (P95)
- **API Calls**: < 500ms (P95)
- **Cache Hit Rate**: > 80%

### Lighthouse Scores (Target: 90+)
- Performance: 90+
- Accessibility: 95+
- Best Practices: 95+
- SEO: 100

---

## Technology Stack

### Core Framework
- **Next.js 14**: App Router with React Server Components
- **React 18**: UI framework
- **TypeScript**: Type safety
- **Tailwind CSS**: Styling system

### Data & State
- **Firebase SDK**: Auth, Firestore client access
- **SWR**: Client-side data fetching and caching
- **Zod**: Runtime schema validation

### Development
- **ESLint**: Code quality
- **Prettier**: Code formatting
- **Bundle Analyzer**: Performance monitoring

### Testing (Planned)
- **Playwright**: E2E testing
- **Jest**: Unit testing
- **React Testing Library**: Component testing

---

## Security Considerations

### Authentication
- Server-side token verification on all protected routes
- Token refresh handling
- Automatic logout on token expiry
- RBAC enforcement matching mobile app

### Headers
```
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

### Data Protection
- No sensitive data in client bundles
- Environment variables server-side only
- Firestore security rules enforce access control
- API rate limiting via Firebase quota

---

## Monitoring & Observability

### Metrics to Track

**Application Metrics**:
- Request count (by route)
- Response time (P50, P95, P99)
- Error rate (by error type)
- Cache hit/miss ratio
- SSR duration

**User Metrics**:
- Core Web Vitals (RUM)
- Page views by route
- User sessions
- Auth success/failure rate

**Infrastructure Metrics**:
- Firebase quota usage
- CDN cache hit rate
- Function cold starts
- Memory usage

### Logging Strategy

**Structured Logging** with fields:
```json
{
  "timestamp": "ISO8601",
  "level": "info|warn|error",
  "requestId": "uuid",
  "route": "/timeclock",
  "operation": "fetch_jobs",
  "duration": 123,
  "userId": "uid",
  "error": null
}
```

**Log Levels**:
- `debug`: Development only
- `info`: Key operations, successful requests
- `warn`: Recoverable errors, slow operations
- `error`: Unrecoverable errors, system failures

---

## Dependencies & Integration Points

### Firebase Services Used
- **Authentication**: User login/logout
- **Firestore**: Read/write user data
- **Cloud Functions**: API calls via callable functions
- **Remote Config**: Feature flags
- **Analytics**: Usage tracking (optional)

### Shared with Mobile App
- Firebase Auth (same project)
- Firestore collections (read/write access)
- Cloud Functions (same endpoints)
- Feature flags (same config)

### New for Web
- Next.js API routes (middleware only)
- Server-side rendering
- Web-specific caching strategies

---

## Testing Strategy

### Contract Tests
- Verify all Cloud Function schemas
- Validate request/response formats
- Test error handling paths

### E2E Tests (Playwright)
- Login flow
- Protected route access
- Clock in/out flow
- Invoice viewing
- Admin operations (role-based)

### Performance Tests
- Lighthouse CI on preview deployments
- Bundle size limits enforced
- SSR time limits enforced

---

## Documentation Deliverables

1. **INTEGRATION_PLAN.md** (this doc): Overall strategy
2. **DOMAIN_ROUTING.md**: Proxy/routing configuration
3. **ROUTE_MAP.md**: Page inventory and SSR strategy
4. **OPERATIONS.md**: Runbooks, flags, rollback procedures
5. **QUALITY_GATE.md**: CI/CD checks and requirements

---

## Success Criteria

### Technical
- ✅ All existing tests pass (mobile + backend)
- ✅ Zero API contract changes
- ✅ Performance budgets met
- ✅ Security headers configured
- ✅ Feature flags operational

### User Experience
- ✅ Auth works seamlessly
- ✅ Protected routes enforce roles
- ✅ Deep links function correctly
- ✅ Core Web Vitals meet targets

### Operational
- ✅ Monitoring dashboards active
- ✅ Logs structured and searchable
- ✅ Canary rollout successful
- ✅ Rollback tested and documented

---

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| PR-01: Scaffolding | 1 day | Project structure, config |
| PR-02: Routing | 1 day | Domain/proxy setup |
| PR-03: Auth | 2 days | Session management |
| PR-04: Data Fetching | 2 days | API client, SSR/SSG |
| PR-05: Routes | 3 days | All pages implemented |
| PR-06: Performance | 2 days | Optimization, caching |
| PR-07: Observability | 2 days | Logging, flags, dashboards |
| PR-08: Tests | 3 days | Contract, E2E, CI |
| PR-09: Documentation | 1 day | Final docs, handover |
| **Total** | **17 days** | **Production-ready web app** |

---

## Risk Mitigation

### Risk: Auth Cookie Issues
- **Mitigation**: Test cookie domain thoroughly in staging
- **Fallback**: Use localStorage with refresh token flow

### Risk: SSR Performance
- **Mitigation**: Aggressive caching, edge functions
- **Fallback**: Fallback to CSR for non-critical routes

### Risk: Bundle Size Bloat
- **Mitigation**: Bundle analyzer in CI, strict limits
- **Fallback**: Dynamic imports, route-based splitting

### Risk: API Rate Limits
- **Mitigation**: Request batching, caching, quotas
- **Fallback**: Graceful degradation, retry with backoff

---

## Conclusion

This integration plan provides a comprehensive, low-risk path to adding a Next.js web application to Sierra Painting while maintaining the integrity of existing mobile and backend systems. The phased rollout with feature flags ensures we can monitor, iterate, and roll back if needed.

**Next Steps**: Begin PR-01 (Project Scaffolding) implementation.
