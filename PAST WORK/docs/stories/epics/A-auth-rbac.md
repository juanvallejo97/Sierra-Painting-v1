# Epic A: Authentication & RBAC

## Overview
Core security foundation providing authentication, role-based access control (RBAC), and App Check protection for all API endpoints.

## Goals
- Secure user authentication with Firebase Auth
- Role-based permissions (admin, painter)
- Protection against unauthorized API access
- Session management and persistence

## Stories

### V1 (MVP Foundation)
- **A1**: Sign-in/out + Reliable Sessions (P0, S, M)
  - Email/password authentication
  - Session persistence across app restarts
  - Sign-out functionality
  
- **A2**: Admin Sets User Roles (P0, S, M)
  - Admins can assign roles (admin/painter)
  - Custom claims for auth rules
  - Cross-org protection
  
- **A5**: App Check Enforcement (P0, S, M)
  - Protect Cloud Functions from abuse
  - Debug tokens for development
  - Play Integrity (Android) and DeviceCheck (iOS)

### Future Enhancements (V3-V4)
- **A3**: Password Reset Flow
- **A4**: Multi-factor Authentication (MFA)
- **A6**: SSO Integration (Google Workspace)

## Key Data Models

### User Document
```
users/{userId}
  email: string
  displayName: string
  role: 'admin' | 'painter'
  orgId: string
  createdAt: Timestamp
  updatedAt: Timestamp
  lastSignInAt: Timestamp
```

### Custom Claims
```json
{
  "role": "painter",
  "orgId": "org_abc123"
}
```

## Security Principles

1. **Defense in Depth**: Multiple layers (Auth, App Check, Firestore Rules)
2. **Least Privilege**: Users only see what they need
3. **Organization Isolation**: Data scoped to orgId
4. **Audit Trail**: All role changes logged

## Dependencies
- Firebase Authentication
- Firebase App Check
- Cloud Functions with App Check enforcement

## Success Metrics
- Sign-in success rate: >99%
- Sign-in latency: P95 <2s
- App Check rejection rate for malicious traffic: >95%
- Zero unauthorized cross-org access

## References
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
