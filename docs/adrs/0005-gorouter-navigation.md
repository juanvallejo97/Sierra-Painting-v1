# ADR-0005: go_router over Navigator 2.0 for Routing

**Status:** Accepted  
**Date:** 2025-01-15  
**Deciders:** Engineering Team  
**Tags:** flutter, routing, navigation, rbac  
**Context:** Need declarative routing with RBAC support

---

## Context and Problem Statement

The application requires:
- Declarative routing configuration
- Role-based access control (RBAC) for routes
- Deep linking support (web URLs, push notifications)
- Type-safe navigation
- Authentication-based redirects
- Nested navigation (tabs, bottom nav)
- Guard routes (admin-only screens)

**Requirements:**
- Redirect unauthenticated users to login
- Redirect authenticated users away from login
- Restrict admin routes to admin users only
- Support deep links (e.g., `/invoices/123`)
- Handle 404 errors gracefully
- Work with Riverpod state management

## Decision Drivers

- Declarative routing (config-based)
- Type safety for routes
- Deep linking out-of-the-box
- RBAC/guard support
- Good developer experience
- Community support
- Integration with Riverpod

## Considered Options

1. **go_router** (**selected**)
2. Navigator 2.0 (manual implementation)
3. AutoRoute
4. Beamer
5. VRouter

---

## Decision Outcome

**Chosen option:** **go_router**

### Why go_router?

**Declarative Configuration:**
- Routes defined in one place
- Easy to understand app structure
- Clear navigation hierarchy
- Simple path parameters

**RBAC Support:**
- Built-in `redirect` callback for guards
- Access to auth state in redirects
- Can check roles before navigation
- Clean separation of concerns

**Deep Linking:**
- Automatic URL parsing
- Web-friendly URLs
- Push notification handling
- App links and universal links

**Type Safety:**
- Path parameters are type-safe
- Route names as constants
- Compile-time errors for invalid routes

**Developer Experience:**
- Less boilerplate than Navigator 2.0
- Good documentation
- Active maintenance
- Works with Riverpod

---

## Pros and Cons Summary

**Pros**
- ✅ Declarative routing configuration
- ✅ Built-in RBAC/guard support
- ✅ Deep linking out-of-the-box
- ✅ Type-safe navigation
- ✅ Error handling (404 pages)
- ✅ Great documentation
- ✅ Works seamlessly with Riverpod
- ✅ Web-friendly URLs

**Cons**
- ⚠️ Learning curve for complex nested routes
- ⚠️ Some edge cases require workarounds
- ⚠️ Breaking changes between major versions

---

## Consequences

**Positive**
1. Simplified routing logic
2. Centralized RBAC configuration
3. Better deep linking support
4. Improved testability
5. Web-ready navigation

**Negative & Mitigations**
1. **Learning curve** → Code examples, documentation
2. **Version migrations** → Pin major version, test upgrades
3. **Complex nested routes** → Keep navigation hierarchy simple

---

## Implementation Notes

### Basic Router Configuration

```dart
// lib/app/router.dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoginRoute = state.matchedLocation == '/login';

      // Redirect to login if not authenticated
      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }
      
      // Redirect to timeclock if authenticated and on login
      if (isLoggedIn && isLoginRoute) {
        return '/timeclock';
      }
      
      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/timeclock',
        builder: (context, state) => const TimeclockScreen(),
      ),
      GoRoute(
        path: '/estimates',
        builder: (context, state) => const EstimatesScreen(),
      ),
      GoRoute(
        path: '/invoices',
        builder: (context, state) => const InvoicesScreen(),
        routes: [
          // Nested route: /invoices/:id
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return InvoiceDetailScreen(invoiceId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
        redirect: (context, state) {
          // RBAC guard for admin routes
          final user = ref.read(currentUserProvider);
          final isAdmin = user?.isAdmin ?? false;
          return isAdmin ? null : '/timeclock';
        },
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(
      error: state.error,
    ),
  );
});
```

### Usage in App

```dart
// lib/app/app.dart
class App extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Sierra Painting',
      theme: ThemeData.light(),
      routerConfig: router,
    );
  }
}
```

### Navigation Methods

```dart
// Programmatic navigation
context.go('/invoices');           // Replace current route
context.push('/invoices/123');     // Push new route
context.pop();                     // Pop current route

// Named parameters
context.goNamed('invoice-detail', pathParameters: {'id': '123'});

// Query parameters
context.go('/invoices?status=paid');
final status = state.uri.queryParameters['status'];
```

### RBAC Guards

```dart
// lib/app/guards.dart
String? adminGuard(BuildContext context, GoRouterState state, WidgetRef ref) {
  final user = ref.read(currentUserProvider);
  final isAdmin = user?.isAdmin ?? false;
  
  if (!isAdmin) {
    return '/unauthorized'; // Redirect to unauthorized page
  }
  
  return null; // Allow navigation
}

// Usage in route
GoRoute(
  path: '/admin',
  builder: (context, state) => const AdminScreen(),
  redirect: (context, state) => adminGuard(context, state, ref),
)
```

### Deep Linking

```dart
// Handle incoming links (Android/iOS)
// Android: Add intent filters in AndroidManifest.xml
// iOS: Add URL schemes in Info.plist

// Example deep link: sierrapainting://invoices/123
// go_router automatically handles this if route exists
```

### Error Handling

```dart
// Global error handler
errorBuilder: (context, state) {
  final error = state.error;
  
  if (error is RouteNotFoundException) {
    return NotFoundScreen(path: state.location);
  }
  
  return ErrorScreen(error: error);
}

// Custom 404 page
class NotFoundScreen extends StatelessWidget {
  final String path;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Page not found: $path'),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Architecture Guidelines

### Route Organization

```dart
// lib/app/routes/
├── auth_routes.dart       # Login, signup, forgot password
├── timeclock_routes.dart  # Time tracking routes
├── invoice_routes.dart    # Invoice-related routes
├── admin_routes.dart      # Admin-only routes
└── routes.dart            # Main router configuration
```

### Route Guards Pattern

```dart
// lib/core/guards/
├── auth_guard.dart        # Require authentication
├── admin_guard.dart       # Require admin role
├── org_guard.dart         # Check organization membership
└── feature_flag_guard.dart # Check feature flag
```

### Best Practices

1. **Centralize routes:** Define all routes in one place
2. **Use path parameters:** Prefer `/invoices/:id` over query params
3. **Guard sensitive routes:** Always check permissions
4. **Handle 404s:** Provide custom error page
5. **Test navigation:** Write tests for route guards
6. **Deep link testing:** Test all deep link paths
7. **Avoid nested redirects:** Can cause infinite loops

---

## Testing

```dart
// test/app/router_test.dart
void main() {
  testWidgets('redirects unauthenticated users to login', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(routerProvider),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Should redirect to login
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('admin guard redirects non-admin users', (tester) async {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => 
          User(id: '1', isAdmin: false)
        ),
      ],
    );

    final router = container.read(routerProvider);
    router.go('/admin');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    // Should redirect away from admin
    expect(find.byType(AdminScreen), findsNothing);
  });
}
```

---

## Comparison with Alternatives

### Navigator 2.0 (manual)
**Pros:** Full control, no dependencies  
**Cons:** Lots of boilerplate, complex implementation  
**Why not chosen:** Too much effort for diminishing returns

### AutoRoute
**Pros:** Code generation, type-safe  
**Cons:** More complex setup, less flexible  
**Why not chosen:** go_router is simpler and more maintainable

### Beamer
**Pros:** Nested navigation support  
**Cons:** Less popular, smaller community  
**Why not chosen:** go_router has better documentation and support

### VRouter
**Pros:** Declarative, web-focused  
**Cons:** Less active, fewer features  
**Why not chosen:** go_router is the recommended solution by Flutter team

---

## Related Decisions

- ADR-0001: Technology Stack Selection (Flutter)
- ADR-0004: Riverpod for State Management (works with go_router)

## References

- [go_router Documentation](https://pub.dev/packages/go_router)
- [Flutter Navigation and Routing](https://docs.flutter.dev/development/ui/navigation)
- [Deep Linking in Flutter](https://docs.flutter.dev/development/ui/navigation/deep-linking)

## Superseded By

None (current decision)

---

> **Note:** ADRs are immutable. Revisions require a new ADR that supersedes this one.
