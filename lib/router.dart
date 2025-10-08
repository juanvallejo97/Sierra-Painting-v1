import 'package:flutter/material.dart';
import 'package:sierra_painting/features/auth/view/forgot_password_screen.dart';
import 'package:sierra_painting/features/auth/view/login_screen.dart';
import 'package:sierra_painting/features/auth/view/signup_screen.dart';
import 'package:sierra_painting/features/settings/privacy_screen.dart';

// Temporary placeholder until your real dashboard widget is wired
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext c) =>
      const Scaffold(body: Center(child: Text('Dashboard')));
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
    case '/settings/privacy':
      return _page(const PrivacyScreen());
    default:
      return _notFound(s.name);
  }
}
