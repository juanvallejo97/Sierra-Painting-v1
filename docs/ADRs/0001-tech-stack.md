# ADR-0001: Technology Stack Selection

**Status**: Accepted  
**Date**: 2024-01-15  
**Deciders**: Engineering Team  
**Tags**: architecture, stack, mobile, backend

## Context

Sierra Painting needs a mobile-first application for managing painting business operations (estimates, invoices, time tracking) with the following requirements:

1. **Offline-first**: Field workers often have limited connectivity
2. **Cross-platform**: Must work on iOS and Android
3. **Fast development**: MVP needed in 4 weeks
4. **Scalable backend**: Handle growing user base and data
5. **Security**: Protect sensitive financial data
6. **Budget-conscious**: Minimize infrastructure costs for startup

We evaluated several technology stacks:

### Option 1: Flutter + Firebase
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Functions, Auth, Storage)
- **State**: Riverpod
- **Routing**: go_router

### Option 2: React Native + AWS
- **Frontend**: React Native (JavaScript/TypeScript)
- **Backend**: AWS (DynamoDB, Lambda, Cognito, S3)
- **State**: Redux Toolkit
- **Routing**: React Navigation

### Option 3: Native (Swift + Kotlin) + Custom Backend
- **Frontend**: Swift (iOS) + Kotlin (Android)
- **Backend**: Node.js + PostgreSQL + Express
- **Infrastructure**: Self-managed on DigitalOcean/Heroku

## Decision

**We chose Flutter + Firebase (Option 1)** for the following reasons:

### Frontend: Flutter

**Pros**:
- Single codebase for iOS and Android
- Excellent offline support (Hive, Drift)
- Strong Material Design 3 implementation
- Hot reload for fast development
- Good performance (compiled to native ARM)
- Growing ecosystem and community
- Built-in accessibility support

**Cons**:
- Dart language learning curve
- Larger app size than native
- Some platform-specific features require plugins

**Why not React Native?**
- Flutter has better offline capabilities out-of-box
- Fewer bridge issues between JS and native code
- Better animation performance
- Stronger typing with Dart

**Why not Native?**
- 2x development effort (separate iOS and Android codebases)
- Slower feature development
- Requires two specialist developers

### Backend: Firebase

**Pros**:
- Serverless (no infrastructure management)
- Built-in authentication and security rules
- Real-time database with offline persistence
- File storage with CDN
- Pay-as-you-go pricing (cost-effective for MVP)
- Excellent integration with Flutter
- Automatic scaling
- Cloud Functions for business logic

**Cons**:
- Vendor lock-in (difficult to migrate away)
- Limited query capabilities (no JOINs)
- Potentially expensive at scale
- Less control over infrastructure

**Why not AWS?**
- Steeper learning curve
- More manual configuration required
- Higher upfront complexity
- Less integrated with Flutter

**Why not Custom Backend?**
- Infrastructure management overhead
- Deployment complexity
- Scaling challenges
- Security configuration burden

### State Management: Riverpod

**Pros**:
- Compile-time safety
- Better testability than Provider
- Supports code generation
- Flexible dependency injection
- Good documentation

**Why not Bloc?**
- More boilerplate code
- Steeper learning curve
- Overkill for our use case

### Routing: go_router

**Pros**:
- Declarative routing
- Deep linking support
- Type-safe navigation
- URL-based routing (web support)
- Easy RBAC integration

**Why not Navigator 2.0 directly?**
- Too low-level
- More complex implementation
- go_router provides nice abstractions

## Consequences

### Positive

1. **Fast MVP Development**: Single codebase, serverless backend → 4-week target achievable
2. **Offline-First**: Flutter + Firestore offline persistence is battle-tested
3. **Cost-Effective**: Firebase free tier covers MVP, pay-as-you-go scales with usage
4. **Security**: Firebase security rules provide server-side validation
5. **Developer Experience**: Hot reload, strong typing, good tooling
6. **Scalability**: Firebase scales automatically, no manual infrastructure work

### Negative

1. **Vendor Lock-in**: Migration from Firebase would be expensive
   - **Mitigation**: Abstract Firebase dependencies behind repository pattern
2. **Query Limitations**: Firestore NoSQL has limited query capabilities
   - **Mitigation**: Design data model to minimize complex queries
3. **Dart Ecosystem**: Smaller than JavaScript/TypeScript
   - **Mitigation**: Most critical packages exist, can write platform channels if needed
4. **Future Costs**: Firebase can become expensive at scale
   - **Mitigation**: Monitor usage, optimize queries, consider caching strategies

### Risks

1. **Firebase Pricing**: Unpredictable costs if usage spikes
   - **Mitigation**: Set budget alerts, implement rate limiting
2. **Firestore Limitations**: Complex reports might require exports to BigQuery
   - **Mitigation**: Plan for BigQuery integration in V3
3. **Platform-Specific Issues**: Some device-specific bugs
   - **Mitigation**: Comprehensive testing on both platforms

## Implementation Notes

### Code Organization

```
lib/
├── core/
│   ├── services/        # Firebase service abstractions
│   └── providers/       # Riverpod providers
├── features/            # Feature modules
└── app/
    └── router.dart      # go_router configuration
```

### Dependency Abstraction

All Firebase calls go through service layers (e.g., `AuthService`, `FirestoreService`) to minimize coupling and enable future migration if needed.

### Testing Strategy

- Unit tests for business logic (no Firebase)
- Integration tests with Firebase emulators
- Widget tests for UI components
- E2E tests for critical user flows

## Alternatives Considered

See "Context" section above for detailed comparison.

## Related Decisions

- ADR-0002: Offline-First Architecture
- ADR-0003: Manual Payments as Primary
- ADR-0004: TypeScript + Zod for Cloud Functions

## References

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [go_router Documentation](https://pub.dev/packages/go_router)

## Superseded By

None (current decision)

---

**Note**: This ADR is immutable. If we need to change this decision in the future, we'll create a new ADR that supersedes this one.
