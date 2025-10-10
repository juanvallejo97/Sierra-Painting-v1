/// Network Status Service
///
/// PURPOSE:
/// Provides real-time network connectivity status using connectivity_plus.
/// Supports reactive UI updates and offline mode detection.
///
/// USAGE:
/// ```dart
/// final networkStatus = ref.read(networkStatusProvider);
///
/// // Check if online
/// final isOnline = await networkStatus.isOnline();
///
/// // Listen to connectivity changes
/// networkStatus.onlineStream.listen((isOnline) {
///   if (isOnline) {
///     // Trigger sync operations
///   }
/// });
/// ```
///
/// FEATURES:
/// - Real-time connectivity status
/// - Stream-based reactive updates
/// - Supports mobile, web, and desktop
/// - Distinguishes between wifi, mobile, ethernet, etc.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network Status Service
class NetworkStatus {
  final Connectivity _connectivity;

  /// Stream controller for online/offline status
  final _onlineController = StreamController<bool>.broadcast();

  /// Current connectivity status
  List<ConnectivityResult> _currentStatus = [];

  /// Subscription to connectivity changes
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkStatus({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _initializeConnectivity();
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    try {
      // Get initial status
      _currentStatus = await _connectivity.checkConnectivity();

      if (kDebugMode) {
        debugPrint('[NetworkStatus] Initial connectivity: $_currentStatus');
      }

      // Listen to connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          debugPrint('[NetworkStatus] Error monitoring connectivity: $error');
        },
      );
    } catch (e) {
      debugPrint('[NetworkStatus] Failed to initialize: $e');
      // Assume online if we can't determine connectivity
      _currentStatus = [ConnectivityResult.wifi];
    }
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnlineFromResults(_currentStatus);
    final isNowOnline = _isOnlineFromResults(results);

    _currentStatus = results;

    if (kDebugMode) {
      debugPrint('[NetworkStatus] Connectivity changed: $results');
      debugPrint('[NetworkStatus] Online: $isNowOnline');
    }

    // Only emit if status changed
    if (wasOnline != isNowOnline) {
      _onlineController.add(isNowOnline);
    }
  }

  /// Check if currently online
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _isOnlineFromResults(results);
    } catch (e) {
      debugPrint('[NetworkStatus] Error checking connectivity: $e');
      // Assume online if we can't determine
      return true;
    }
  }

  /// Get current connectivity type
  Future<List<ConnectivityResult>> getConnectivityType() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('[NetworkStatus] Error getting connectivity type: $e');
      return [ConnectivityResult.none];
    }
  }

  /// Stream of online/offline status changes
  Stream<bool> get onlineStream => _onlineController.stream;

  /// Determine if online from connectivity results
  bool _isOnlineFromResults(List<ConnectivityResult> results) {
    // Consider online if any connection type is available
    return results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);
  }

  /// Check if on WiFi
  Future<bool> isOnWifi() async {
    final results = await getConnectivityType();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Check if on mobile data
  Future<bool> isOnMobile() async {
    final results = await getConnectivityType();
    return results.contains(ConnectivityResult.mobile);
  }

  /// Check if on ethernet
  Future<bool> isOnEthernet() async {
    final results = await getConnectivityType();
    return results.contains(ConnectivityResult.ethernet);
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }
}

/// Provider for NetworkStatus
final networkStatusProvider = Provider<NetworkStatus>((ref) {
  final networkStatus = NetworkStatus();

  // Ensure cleanup when provider is disposed
  ref.onDispose(() {
    networkStatus.dispose();
  });

  return networkStatus;
});

/// Stream provider for online status
final onlineStatusStreamProvider = StreamProvider<bool>((ref) {
  final networkStatus = ref.watch(networkStatusProvider);
  return networkStatus.onlineStream;
});

/// Future provider for current online status
final isOnlineProvider = FutureProvider<bool>((ref) {
  final networkStatus = ref.watch(networkStatusProvider);
  return networkStatus.isOnline();
});
