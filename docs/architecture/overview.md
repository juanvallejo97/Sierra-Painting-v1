# Architecture Overview
- **UI**: Flutter (Material 3), Riverpod for state.
- **Routing**: GoRouter (or MaterialApp routes) with AnalyticsRouteObserver.
- **Backend**: Firebase (Auth, Firestore, Functions).
- **Security**: Firestore rules locked down; App Check enforced in staging/prod.
- **Testing**: Widget tests for web parity; Android integration for end-to-end smoke.
- **Observability**: Analytics events, Perf traces, Crashlytics (consent-gated).