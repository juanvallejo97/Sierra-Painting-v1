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

### Security Considerations
<!-- Answer these questions for security-related changes -->

- [ ] Does this PR modify Firestore security rules?
- [ ] Does this PR modify Cloud Functions authentication/authorization?
- [ ] Does this PR handle sensitive data (PII, payment info)?
- [ ] Have you reviewed the security implications?

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
