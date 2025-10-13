import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/features/auth/presentation/forgot_password_screen.dart';
import 'package:sierra_painting/features/auth/presentation/login_screen.dart';
import 'package:sierra_painting/features/auth/presentation/signup_screen.dart';
import 'package:sierra_painting/features/estimates/presentation/estimate_create_screen.dart';
import 'package:sierra_painting/features/estimates/presentation/estimate_detail_screen.dart';
import 'package:sierra_painting/features/invoices/presentation/invoice_create_screen.dart';
import 'package:sierra_painting/features/invoices/presentation/invoice_detail_screen.dart';
import 'package:sierra_painting/features/settings/privacy_screen.dart';
import 'package:sierra_painting/features/timeclock/presentation/worker_dashboard_screen.dart';
import 'package:sierra_painting/features/admin/presentation/admin_review_screen.dart';

/// Role-Based Dashboard Router
/// Routes users to appropriate dashboard based on their role
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the claims provider for async loading state
    final claimsAsync = ref.watch(userClaimsProvider);

    return claimsAsync.when(
      data: (claims) {
        final role = claims?['role'] as String?;

        // Route based on user role
        if (role == null) {
          // No role assigned - show error
          return _buildNoRoleScreen(context, ref);
        }

        switch (role.toLowerCase()) {
          case 'worker':
          case 'crew':
          case 'staff':
            return const WorkerDashboardScreen();
          case 'admin':
          case 'manager':
            return const AdminReviewScreen();
          default:
            return _buildUnknownRoleScreen(context, role);
        }
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading dashboard: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoRoleScreen(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sierra Painting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'No Role Assigned',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your account does not have a role assigned yet.\nPlease contact your administrator.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                // Force refresh ID token and invalidate claims provider
                await FirebaseAuth.instance.currentUser?.getIdToken(true);
                ref.invalidate(userClaimsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Claims'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnknownRoleScreen(BuildContext context, String role) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sierra Painting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Unknown Role',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your role "$role" is not recognized.\nPlease contact your administrator.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

Route<dynamic> _page(Widget child) => MaterialPageRoute(builder: (_) => child);

Route<dynamic> _notFound(String? name) => MaterialPageRoute(
  builder: (_) => Scaffold(
    body: Center(child: Text('Route not found: ${name ?? "(null)"}')),
  ),
);

Route<dynamic> onGenerateRoute(RouteSettings s) {
  debugPrint('Navigating to route: ${s.name}'); // Debug print
  switch (s.name) {
    case '/': // <- important: default route
      return _page(const LoginScreen());
    case '/login':
      return _page(const LoginScreen());
    case '/signup':
      return _page(const SignUpScreen());
    case '/forgot':
      return _page(const ForgotPasswordScreen());
    case '/dashboard':
      return _page(const DashboardScreen());
    case '/invoices/create':
      return _page(const InvoiceCreateScreen());
    case '/estimates/create':
      return _page(const EstimateCreateScreen());
    case '/settings/privacy':
      return _page(const PrivacyScreen());
    default:
      // Handle parameterized routes
      if (s.name?.startsWith('/invoices/') == true) {
        final invoiceId = s.name!.split('/').last;
        return _page(InvoiceDetailScreen(invoiceId: invoiceId));
      }
      if (s.name?.startsWith('/estimates/') == true &&
          s.name != '/estimates/create') {
        final estimateId = s.name!.split('/').last;
        return _page(EstimateDetailScreen(estimateId: estimateId));
      }
      return _notFound(s.name);
  }
}
