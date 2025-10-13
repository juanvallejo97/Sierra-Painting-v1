/// Company Claims Helper
///
/// PURPOSE:
/// Provides a cached, timeout-guarded way to retrieve companyId from Firebase Auth custom claims.
/// Eliminates hardcoded test company IDs and enforces proper multi-tenant isolation.
///
/// USAGE:
/// ```dart
/// final companyId = await resolveCompanyId();
/// if (companyId == null) throw Exception('No company claim - user not assigned to company');
/// ```
///
/// CACHING STRATEGY:
/// - Caches claims in SharedPreferences with 5-minute TTL
/// - Reduces auth token refresh calls
/// - Falls back to cached value if refresh fails (network issues)
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default TTL for cached company claims (5 minutes)
const Duration kDefaultClaimsCacheTTL = Duration(minutes: 5);

/// Cache keys
const String _kCompanyIdKey = 'cached_company_id';
const String _kCompanyIdTTLKey = 'cached_company_id_ttl';

/// Resolve company ID from Firebase Auth custom claims with caching
///
/// Returns:
/// - `String` companyId if user has valid claim
/// - `null` if user is not authenticated or has no companyId claim
///
/// Throws:
/// - `TimeoutException` if token refresh times out (after fallback to cache)
Future<String?> resolveCompanyId({
  Duration ttl = kDefaultClaimsCacheTTL,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('⚠️ resolveCompanyId: No authenticated user');
    return null;
  }

  // Try to fetch fresh claims from Firebase Auth token
  try {
    final idTokenResult = await user
        .getIdTokenResult(true) // Force refresh
        .timeout(timeout);

    final companyId = idTokenResult.claims?['companyId'] as String?;

    if (companyId != null && companyId.isNotEmpty) {
      // Cache the fresh value
      await _cacheCompanyId(companyId, ttl);
      debugPrint('✅ resolveCompanyId: Fresh claim retrieved: $companyId');
      return companyId;
    }

    debugPrint('⚠️ resolveCompanyId: User has no companyId claim');
    return null;
  } on TimeoutException {
    debugPrint(
      '⚠️ resolveCompanyId: Token refresh timed out, falling back to cache',
    );
    // Fall back to cached value if timeout
    return await _getCachedCompanyId();
  } catch (e) {
    debugPrint('⚠️ resolveCompanyId: Error fetching claims: $e');
    // Fall back to cached value on any error
    return await _getCachedCompanyId();
  }
}

/// Resolve company ID from Firebase Auth custom claims (sync version using cached value)
///
/// Returns cached value if available and not expired, otherwise returns null.
/// Use this for synchronous contexts where you've previously called [resolveCompanyId].
Future<String?> getCachedCompanyId() async {
  return await _getCachedCompanyId();
}

/// Clear cached company ID (call on logout)
Future<void> clearCompanyIdCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCompanyIdKey);
    await prefs.remove(_kCompanyIdTTLKey);
    debugPrint('✅ Cleared company ID cache');
  } catch (e) {
    debugPrint('⚠️ Error clearing company ID cache: $e');
  }
}

/// Cache company ID with TTL
Future<void> _cacheCompanyId(String companyId, Duration ttl) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = DateTime.now().add(ttl).millisecondsSinceEpoch;

    await prefs.setString(_kCompanyIdKey, companyId);
    await prefs.setInt(_kCompanyIdTTLKey, expiryMs);
  } catch (e) {
    debugPrint('⚠️ Error caching company ID: $e');
    // Non-fatal: just log and continue without cache
  }
}

/// Get cached company ID if not expired
Future<String?> _getCachedCompanyId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_kCompanyIdTTLKey);
    final cachedId = prefs.getString(_kCompanyIdKey);

    if (expiryMs != null && cachedId != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < expiryMs) {
        debugPrint('✅ resolveCompanyId: Using cached value: $cachedId');
        return cachedId;
      } else {
        debugPrint('⚠️ resolveCompanyId: Cached value expired');
      }
    }

    return null;
  } catch (e) {
    debugPrint('⚠️ Error reading cached company ID: $e');
    return null;
  }
}

/// Riverpod provider for company ID (async)
///
/// Usage:
/// ```dart
/// final companyIdAsync = ref.watch(companyIdProvider);
/// companyIdAsync.when(
///   data: (id) => id != null ? Text('Company: $id') : Text('No company'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```

final companyIdProvider = FutureProvider<String?>((ref) async {
  return await resolveCompanyId();
});
