import 'package:flutter/material.dart';
import 'features/auth/view/signup_screen.dart';
import 'features/auth/view/login_screen.dart';
import 'features/auth/view/forgot_password_screen.dart';

// TODO: replace with your real dashboard widget
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext c) => const Scaffold(body: Center(child: Text('Dashboard')));
}

Route<dynamic>? onGenerateRoute(RouteSettings s) {
  switch (s.name) {
    case '/signup':
      return MaterialPageRoute(builder: (_) => const SignUpScreen());
    case '/login':
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    case '/forgot':
      return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
    case '/dashboard':
      return MaterialPageRoute(builder: (_) => const DashboardScreen());
  }
  return null;
}
