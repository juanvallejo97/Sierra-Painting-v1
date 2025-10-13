<!-- Please describe the change and why it was made -->

Checklist
- [ ] I ran npm ci and verified the project builds
- [ ] Validator passed locally (validator-v12)
- [ ] Artifacts (logs/report) attached if relevant
- [ ] Conventional commit message used

What I changed
- ...
## Pull Request

### Description
<!-- Provide a brief description of the changes in this PR -->

### Type of Change
<!-- Mark the relevant option with an [x] -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Code refactoring
- [ ] Performance improvement
- [ ] Security enhancement
- [ ] CI/CD improvement

### Related Issues
<!-- Link to related issues using #issue_number -->

Fixes #
Related to #

### Changes Made
<!-- Provide a detailed list of changes -->

- 
- 
- 

### Testing
<!-- Describe the testing you've performed -->

#### Manual Testing
- [ ] Tested locally with Firebase emulators
- [ ] Tested Flutter app on Android
- [ ] Tested Flutter app on iOS
- [ ] Tested Cloud Functions locally
- [ ] Tested with production build

#### Automated Testing
- [ ] All Flutter tests pass (`flutter test`)
- [ ] All Functions tests pass (`npm test`)
- [ ] Linting passes (`dart format`, `npm run lint`)
- [ ] Build succeeds (`flutter build apk`, `npm run build`)

### Schema Changes (Option B Canonical v2.0)
<!-- If this PR changes canonical schemas, complete this section. Otherwise, delete it. -->

#### Collections Affected
- [ ] `jobs` (geofence structure)
- [ ] `time_entries` (field names)
- [ ] `users` (custom claims)
- [ ] `assignments`
- [ ] `estimates`
- [ ] `invoices`
- [ ] Other: _______

#### Breaking Schema Changes
- [ ] Job geofence: flat → nested structure (`geofence.{lat,lng,radiusM}`)
- [ ] TimeEntry fields: renamed (`userId` not `workerId`, `clockInAt` not `clockIn`)
- [ ] User claims: Firestore → JWT custom claims only
- [ ] Firestore indexes modified
- [ ] Security rules immutability constraints added

#### Migration Required
- [ ] Yes - migration script: `tools/migrate_v1_to_v2.cjs`
- [ ] No - backward compatible with legacy schemas

#### Migration Plan
<!-- If migration required, describe plan and timeline -->

**Timeline**:
- Deployment date: ___
- Legacy support window: 2 weeks
- Legacy removal date: ___

**Steps**:
1. Backup database
2. Run migration script (dry-run)
3. Run actual migration
4. Set custom claims
5. Deploy rules & indexes
6. Deploy functions with fallbacks
7. Monitor for 24h
8. Remove fallbacks after 2 weeks

#### Verification
<!-- How to verify migration success -->

```bash
# Verify job nested geofence
firebase firestore:get jobs/{jobId}

# Verify time entry canonical fields
firebase firestore:get time_entries/{entryId}

# Verify user custom claims
firebase auth:get {uid}
```

### Security Considerations
<!-- Answer these questions for security-related changes -->

- [ ] Does this PR modify Firestore security rules?
- [ ] Does this PR modify Cloud Functions authentication/authorization?
- [ ] Does this PR handle sensitive data (PII, payment info)?
- [ ] Have you reviewed the security implications?
- [ ] Does this PR enforce immutability of core fields?
- [ ] Does this PR validate geofence boundaries correctly?

If yes to any above, explain:


### Deployment Notes
<!-- Any special instructions for deployment -->

#### Pre-Deployment Checklist
<!-- Complete before merging to main (staging) or creating version tag (production) -->

**Code Quality:**
- [ ] All tests pass locally (`flutter test` && `cd functions && npm test`)
- [ ] Linting passes (`flutter analyze` && `cd functions && npm run lint`)
- [ ] Build succeeds (`flutter build apk --debug` && `cd functions && npm run build`)

**Security:**
- [ ] No hardcoded secrets or API keys
- [ ] Firestore security rules tested
- [ ] Authentication/authorization checks in place

**Configuration:**
- [ ] Environment variables updated (if needed)
- [ ] Remote Config flags configured
- [ ] Database indexes created (if needed): `firebase deploy --only firestore:indexes`

**Planning:**
- [ ] Rollback plan documented
- [ ] Monitoring dashboards prepared
- [ ] Team notified of deployment

#### Required Secrets
<!-- List any new secrets that need to be configured -->

- 
- 

#### Database Migrations
<!-- List any database schema changes or migrations needed -->

- 
- 

#### Configuration Changes
<!-- List any configuration changes needed -->

- 
- 

### Screenshots
<!-- If applicable, add screenshots to help explain your changes -->

### Checklist
<!-- Mark completed items with an [x] -->

#### Code Quality
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code where necessary
- [ ] My changes generate no new warnings or errors
- [ ] I have kept changes minimal and focused

#### Documentation
- [ ] I have updated relevant documentation (README, docs/)
- [ ] I have updated inline code comments where needed
- [ ] I have added/updated JSDoc/DartDoc comments for new functions

#### Testing & CI
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] GitHub Actions CI checks pass
- [ ] I have tested with Firebase emulators

#### Security (if applicable)
- [ ] I have followed secure coding practices
- [ ] I have not introduced any security vulnerabilities
- [ ] I have validated all user inputs
- [ ] I have reviewed Firestore rules changes

### Breaking Changes
<!-- If this PR includes breaking changes, list them here -->

- 
- 

### Migration Guide
<!-- If breaking changes exist, provide a migration guide -->

```
// Before
...

// After
...
```

### Performance Impact
<!-- Describe any performance implications -->

- [ ] No performance impact
- [ ] Performance improved
- [ ] Performance decreased (explain below)

#### Performance Checklist (for all PRs)
<!-- Mark completed items with an [x] -->

**Flutter/Dart:**
- [ ] Added `const` to all static widgets
- [ ] State changes localized (minimal rebuild scope)
- [ ] Heavy work offloaded to isolates (`compute()`)
- [ ] Lists use `.builder()` pattern
- [ ] Images cached appropriately (cached_network_image)
- [ ] Controllers disposed properly
- [ ] Network calls have timeouts (30s default)
- [ ] Optimistic updates for writes where appropriate

**Firestore:**
- [ ] Queries have necessary indexes
- [ ] Queries use `.limit()` for pagination
- [ ] No unbounded queries (N+1 patterns avoided)
- [ ] Offline persistence enabled where needed

**Performance Testing:**
- [ ] No frame drops in profile mode (DevTools checked)
- [ ] Memory leaks checked
- [ ] APK size within budget (≤50MB)
- [ ] Startup time measured if changed (P90 <2s)

**Backend (if applicable):**
- [ ] Functions have timeout limits
- [ ] Functions use minInstances for critical paths
- [ ] Payloads compressed (gzip/Brotli)
- [ ] Batch operations used where possible

### Rollback Plan
<!-- How can this change be rolled back if issues arise? -->


### Additional Context
<!-- Add any other context about the PR here -->


---

## For Reviewers

### Review Checklist
<!-- Reviewers should verify these items -->

- [ ] Code follows project standards and best practices
- [ ] Changes are well-tested
- [ ] Documentation is updated
- [ ] Security implications have been considered
- [ ] Performance impact is acceptable
- [ ] No unnecessary dependencies added
- [ ] Commit messages are clear and descriptive

### Approval
<!-- Add any notes for approval -->


---

### Post-Merge Actions
<!-- List any actions needed after merging -->

- [ ] Deploy to staging environment
- [ ] Run smoke tests
- [ ] Update project board
- [ ] Notify stakeholders
- [ ] Monitor error logs for 24h
