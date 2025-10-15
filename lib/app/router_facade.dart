/// Router Facade
///
/// PURPOSE:
/// Provides a consistent navigation API to eliminate mixed router usage.
/// Wraps Navigator calls to prepare for future go_router migration.
///
/// STRATEGY:
/// - Use this facade for ALL navigation calls
/// - Simplifies future migration to go_router
/// - Centralizes navigation logic for easier debugging
///
/// USAGE:
/// ```dart
/// // Instead of:
/// Navigator.pushNamed(context, '/invoices');
///
/// // Use:
/// RouterFacade.push(context, '/invoices');
/// ```
library;

import 'package:flutter/material.dart';

/// Centralized router facade for consistent navigation
class RouterFacade {
  /// Navigate to a route by name (replaces Navigator.pushNamed)
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  /// Navigate to a route and remove all previous routes (replaces pushNamedAndRemoveUntil)
  static Future<T?> pushAndRemoveAll<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamedAndRemoveUntil<T>(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Replace the current route (replaces pushReplacementNamed)
  static Future<T?> replace<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    TO? result,
  }) {
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      routeName,
      arguments: arguments,
      result: result,
    );
  }

  /// Go back to the previous route (replaces Navigator.pop)
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.pop<T>(context, result);
  }

  /// Check if we can pop (replaces Navigator.canPop)
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  /// Pop until a specific route (replaces popUntil)
  static void popUntil(BuildContext context, bool Function(Route) predicate) {
    Navigator.popUntil(context, predicate);
  }

  /// Pop until a specific route name
  static void popUntilNamed(BuildContext context, String routeName) {
    Navigator.popUntil(context, (route) {
      return route.settings.name == routeName || !Navigator.canPop(context);
    });
  }

  /// Check the current route name
  static String? getCurrentRouteName(BuildContext context) {
    return ModalRoute.of(context)?.settings.name;
  }

  /// Safe navigation helper - checks if context is mounted before navigating
  static Future<T?> pushSafe<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    required bool mounted,
  }) {
    if (!mounted) {
      return Future.value(null);
    }
    return push<T>(context, routeName, arguments: arguments);
  }

  /// Safe pop helper - checks if context is mounted before popping
  static void popSafe<T extends Object?>(
    BuildContext context,
    bool mounted, [
    T? result,
  ]) {
    if (!mounted) return;
    pop<T>(context, result);
  }

  // ============================================================================
  // FUTURE: go_router migration helpers
  // When migrating to go_router, we can update these methods internally
  // without changing call sites throughout the app.
  // ============================================================================

  // /// Go to a route (go_router style)
  // static void go(BuildContext context, String location, {Object? extra}) {
  //   GoRouter.of(context).go(location, extra: extra);
  // }

  // /// Push a route (go_router style)
  // static Future<T?> goPush<T extends Object?>(
  //   BuildContext context,
  //   String location, {
  //   Object? extra,
  // }) {
  //   return GoRouter.of(context).push<T>(location, extra: extra);
  // }
}
