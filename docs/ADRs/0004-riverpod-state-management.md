# ADR-0004: Riverpod over Bloc/Provider for State Management

**Status:** Accepted  
**Date:** 2025-01-15  
**Deciders:** Engineering Team  
**Tags:** flutter, state-management, riverpod, architecture  
**Context:** Need to select state management solution for Flutter app

---

## Context and Problem Statement

Flutter applications require a state management solution to handle:
- Authentication state (user session)
- Data fetching and caching (Firestore queries)
- UI state (loading, error states)
- Form state
- Dependency injection
- Testing and mocking

**Requirements:**
- Type safety and compile-time errors
- Easy testing and mocking
- Minimal boilerplate
- Good developer experience
- Scalable for growing app
- Community support and documentation
- Works well with async data (Firestore, Cloud Functions)

## Decision Drivers

- Compile-time safety over runtime errors
- Testability without complex setup
- Code generation for reduced boilerplate
- Async state handling (streams, futures)
- Dependency injection built-in
- Active maintenance and community
- Learning curve for team

## Considered Options

1. **Riverpod** (**selected**)
2. Bloc/Cubit (flutter_bloc)
3. Provider (original, legacy)
4. GetX
5. MobX

---

## Decision Outcome

**Chosen option:** **Riverpod**

### Why Riverpod?

**Compile-time Safety:**
- Type-safe providers (no `BuildContext` required)
- Compile-time dependency graph
- No runtime errors from missing providers
- Better IDE autocomplete and refactoring

**Code Generation:**
- `@riverpod` annotation generates providers
- Reduces boilerplate significantly
- Type-safe generated code
- Auto-disposes providers when not needed

**Testing:**
- Easy to override providers in tests
- No widget tree required for testing
- Mock dependencies cleanly
- Deterministic behavior

**Async Support:**
- `AsyncValue<T>` for loading/error/data states
- Built-in error handling
- Automatic retry logic
- Works seamlessly with Firestore streams

**Developer Experience:**
- Less boilerplate than Bloc
- More flexible than Provider
- Better error messages
- Good documentation

---

## Pros and Cons Summary

**Pros**
- ✅ Compile-time safety (catch errors early)
- ✅ Minimal boilerplate with code generation
- ✅ Excellent async state handling
- ✅ Easy testing and mocking
- ✅ Built-in dependency injection
- ✅ No `BuildContext` pollution
- ✅ Auto-dispose for memory efficiency
- ✅ Active development and community

**Cons**
- ⚠️ Learning curve (different mental model than Provider)
- ⚠️ Code generation adds build step
- ⚠️ Newer than Bloc (less enterprise adoption)
- ⚠️ Some advanced patterns require understanding of internals

---

## Consequences

**Positive**
1. Fewer runtime errors (compile-time checks)
2. Faster development (less boilerplate)
3. Easier testing (clean mocking)
4. Better async state management
5. Improved code maintainability

**Negative & Mitigations**
1. **Learning curve** → Team training, code examples, documentation
2. **Code generation step** → Integrated into CI/CD, watch mode for dev
3. **Less common in job market** → Document patterns, add inline comments
4. **Migration complexity** → Start fresh (greenfield project)

---

## Implementation Notes

### Provider Types

**Synchronous Providers:**
```dart
// lib/core/providers/auth_provider.dart
@riverpod
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) {
  return FirebaseAuth.instance;
}
```

**Async Providers:**
```dart
// lib/features/invoices/data/invoice_repository.dart
@riverpod
Stream<List<Invoice>> invoices(InvoicesRef ref) {
  final userId = ref.watch(currentUserIdProvider);
  return FirebaseFirestore.instance
    .collection('invoices')
    .where('userId', isEqualTo: userId)
    .snapshots()
    .map((snapshot) => snapshot.docs.map((doc) => 
      Invoice.fromJson(doc.data())
    ).toList());
}
```

**State Notifier Providers (for complex state):**
```dart
// lib/features/timeclock/presentation/timeclock_controller.dart
@riverpod
class TimeclockController extends _$TimeclockController {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> clockIn() async {
    state = const AsyncValue.loading();
    try {
      final result = await ref.read(timeclockRepositoryProvider).clockIn();
      state = AsyncValue.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
```

### Using AsyncValue in UI

```dart
// lib/features/invoices/presentation/invoices_screen.dart
class InvoicesScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
    
    return invoicesAsync.when(
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
      data: (invoices) => ListView.builder(
        itemCount: invoices.length,
        itemBuilder: (context, index) => InvoiceCard(invoices[index]),
      ),
    );
  }
}
```

### Testing

```dart
// test/features/invoices/invoices_test.dart
void main() {
  test('invoices provider returns data', () async {
    final container = ProviderContainer(
      overrides: [
        invoicesProvider.overrideWith((ref) => 
          Stream.value([Invoice(id: '1', amount: 100)])
        ),
      ],
    );

    final invoices = await container.read(invoicesProvider.future);
    expect(invoices, hasLength(1));
    expect(invoices[0].amount, 100);
  });
}
```

---

## Architecture Guidelines

### File Structure

```
lib/
├── core/
│   ├── providers/
│   │   ├── auth_provider.dart        # Firebase Auth instance
│   │   ├── firestore_provider.dart   # Firestore instance
│   │   └── queue_provider.dart       # Offline queue
│   └── services/
│       ├── auth_service.dart         # Auth business logic
│       └── queue_service.dart        # Queue management
└── features/
    └── invoices/
        ├── data/
        │   ├── invoice_repository.dart  # Data access (Firestore)
        │   └── models/
        │       └── invoice.dart
        ├── domain/
        │   └── usecases/
        │       └── mark_invoice_paid.dart
        └── presentation/
            ├── invoices_screen.dart
            └── controllers/
                └── invoice_controller.dart  # UI state
```

### Provider Naming Conventions

- **Data providers:** `xxxProvider` (e.g., `invoicesProvider`)
- **Controllers:** `xxxControllerProvider` (e.g., `invoiceControllerProvider`)
- **Services:** `xxxServiceProvider` (e.g., `authServiceProvider`)
- **Repositories:** `xxxRepositoryProvider` (e.g., `invoiceRepositoryProvider`)

### Best Practices

1. **Keep providers focused:** One responsibility per provider
2. **Use code generation:** Always use `@riverpod` annotation
3. **Handle errors explicitly:** Use `AsyncValue.when()` to handle all states
4. **Document dependencies:** Add comments for complex provider chains
5. **Dispose resources:** Riverpod auto-disposes, but be aware of `keepAlive`
6. **Test providers independently:** Override dependencies in tests
7. **Avoid global state:** Use providers instead of singletons

---

## Comparison with Alternatives

### Bloc/Cubit
**Pros:** Predictable state changes, great for complex state machines, well-documented  
**Cons:** More boilerplate (events, states, mappers), steeper learning curve  
**Why not chosen:** Overkill for our use case, more ceremony than needed

### Provider (original)
**Pros:** Simple, minimal boilerplate, good for small apps  
**Cons:** Runtime errors, lacks compile-time safety, no code generation  
**Why not chosen:** Superseded by Riverpod (created by same author)

### GetX
**Pros:** All-in-one (routing, state, DI), minimal boilerplate  
**Cons:** Service locator pattern, less type-safe, controversial in community  
**Why not chosen:** Prefer explicit dependencies, concerns about maintainability

### MobX
**Pros:** Reactive, minimal boilerplate, observable pattern  
**Cons:** Requires code generation, different paradigm, less Flutter-specific  
**Why not chosen:** Riverpod better suited for Flutter ecosystem

---

## Migration Path (Future)

If we need to migrate away from Riverpod:

1. **Repository pattern insulation:** All data access goes through repositories
2. **Business logic separation:** Keep logic in use cases, not providers
3. **Test coverage:** Comprehensive tests make refactoring safer
4. **Incremental migration:** Migrate feature-by-feature, not all at once

---

## Related Decisions

- ADR-0001: Technology Stack Selection (Flutter)
- ADR-0005: go_router for Navigation (works well with Riverpod)

## References

- [Riverpod Documentation](https://riverpod.dev)
- [Riverpod Code Generation](https://riverpod.dev/docs/concepts/about_code_generation)
- [Flutter State Management Options](https://docs.flutter.dev/development/data-and-backend/state-mgmt/options)
- [Riverpod vs Bloc Comparison](https://codewithandrea.com/articles/flutter-state-management-riverpod-vs-bloc/)

## Superseded By

None (current decision)

---

> **Note:** ADRs are immutable. Revisions require a new ADR that supersedes this one.
