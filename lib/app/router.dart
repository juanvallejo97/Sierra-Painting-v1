// Centralized router using GoRouter and Riverpod.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';
import 'package:sierra_painting/core/telemetry/performance_monitor.dart';
import 'package:sierra_painting/core/widgets/error_screen.dart';
import 'package:sierra_painting/features/admin/presentation/admin_screen.dart';
import 'package:sierra_painting/features/auth/presentation/login_screen.dart';
import 'package:sierra_painting/features/estimates/presentation/estimates_screen.dart';
import 'package:sierra_painting/features/invoices/presentation/invoices_screen.dart';
import 'package:sierra_painting/features/jobs/presentation/jobs_screen.dart';
import 'package:sierra_painting/features/timeclock/presentation/timeclock_screen.dart';
import 'package:sierra_painting/core/feature_flags/feature_flags_debug_screen.dart';

// Initialize PerformanceMonitor instance
final PerformanceMonitor monitor = PerformanceMonitor();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    // A simple redirect that inspects the Auth state. In production you may
    // want to provide a refreshListenable so GoRouter re-evaluates on auth changes.
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/timeclock';
      return null;
    },
    errorBuilder: (context, state) =>
        ErrorScreen(error: state.error, path: state.uri.toString()),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final trace = monitor.startTrace('login_screen_load');
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => monitor.stopTrace(trace.name),
          );
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/timeclock',
        builder: (context, state) {
          final trace = monitor.startTrace('timeclock_screen_load');
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => monitor.stopTrace(trace.name),
          );
          return const TimeclockScreen();
        },
      ),
      GoRoute(
        path: '/estimates',
        builder: (context, state) => const EstimatesScreen(),
      ),
      GoRoute(path: '/jobs', builder: (context, state) => const JobsScreen()),
      GoRoute(
        path: '/invoices',
        builder: (context, state) => const InvoicesScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
        redirect: (context, state) {
          final user = ref.read(authStateProvider).value;
          final isAdmin = user?.email?.contains('admin') ?? false;
          return isAdmin ? null : '/timeclock';
        },
      ),
      GoRoute(
        path: '/admin/feature-flags',
        builder: (context, state) => const FeatureFlagsDebugScreen(),
        redirect: (context, state) {
          final user = ref.read(authStateProvider).value;
          final isAdmin = user?.email?.contains('admin') ?? false;
          return isAdmin ? null : '/timeclock';
        },
      ),
    ],
  );
});
