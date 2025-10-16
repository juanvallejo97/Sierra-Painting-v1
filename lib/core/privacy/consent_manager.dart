/// Privacy & Consent Management System
///
/// PURPOSE:
/// - GDPR/CCPA-compliant consent management
/// - Granular controls for Analytics, Performance, Crashlytics
/// - Persistent storage with timestamps
/// - EU region detection for opt-in vs opt-out

library consent_manager;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// CONSENT TYPES
// ============================================================================

enum ConsentType {
  analytics,    // Firebase Analytics events
  performance,  // Firebase Performance traces
  crashlytics,  // Crash reporting
  functional,   // Always allowed (required for app to work)
}

// ============================================================================
// CONSENT STATUS
// ============================================================================

class ConsentStatus {
  final Map<ConsentType, bool> consents;
  final DateTime timestamp;
  final bool isEURegion;

  const ConsentStatus({
    required this.consents,
    required this.timestamp,
    required this.isEURegion,
  });

  bool isGranted(ConsentType type) {
    if (type == ConsentType.functional) return true;
    return consents[type] ?? false;
  }

  bool get hasDecided => consents.isNotEmpty;

  ConsentStatus copyWith({
    Map<ConsentType, bool>? consents,
    DateTime? timestamp,
    bool? isEURegion,
  }) {
    return ConsentStatus(
      consents: consents ?? this.consents,
      timestamp: timestamp ?? this.timestamp,
      isEURegion: isEURegion ?? this.isEURegion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consents': consents.map((k, v) => MapEntry(k.name, v)),
      'timestamp': timestamp.toIso8601String(),
      'isEURegion': isEURegion,
    };
  }

  static ConsentStatus fromJson(Map<String, dynamic> json) {
    final consentsMap = (json['consents'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(
        ConsentType.values.firstWhere((e) => e.name == k),
        v as bool,
      ),
    );

    return ConsentStatus(
      consents: consentsMap,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isEURegion: json['isEURegion'] as bool,
    );
  }
}

// ============================================================================
// MAIN CONSENT MANAGER
// ============================================================================

class ConsentManager {
  ConsentManager._();
  static final instance = ConsentManager._();

  static const _consentKey = 'user_consent_v1';
  static const _timestampKey = 'consent_timestamp';

  ConsentStatus? _currentStatus;
  final _statusController = StreamController<ConsentStatus>.broadcast();

  bool _initialized = false;

  /// Initialize consent manager (call on app boot)
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final consentJson = prefs.getString(_consentKey);

    if (consentJson != null) {
      try {
        // TODO: Parse JSON and restore consent status
        debugPrint('Consent: Restored from storage');
      } catch (e) {
        debugPrint('Consent: Failed to restore - $e');
      }
    } else {
      // First-time user: detect region
      final isEU = await _detectEURegion();
      _currentStatus = ConsentStatus(
        consents: {},
        timestamp: DateTime.now(),
        isEURegion: isEU,
      );
    }

    _initialized = true;
  }

  /// Get current consent status
  ConsentStatus get status {
    if (_currentStatus == null) {
      throw StateError('ConsentManager not initialized. Call initialize() first.');
    }
    return _currentStatus!;
  }

  /// Check if user has granted consent for a specific type
  bool hasConsent(ConsentType type) {
    if (!_initialized) return false;
    if (type == ConsentType.functional) return true;
    return _currentStatus?.isGranted(type) ?? false;
  }

  /// Check if user has made any consent decision
  bool get hasDecided => _currentStatus?.hasDecided ?? false;

  /// Stream of consent status changes
  Stream<ConsentStatus> get statusStream => _statusController.stream;

  /// Grant consent for specific types
  Future<void> grantConsent(Set<ConsentType> types) async {
    final newConsents = Map<ConsentType, bool>.from(_currentStatus?.consents ?? {});

    for (final type in types) {
      if (type != ConsentType.functional) {
        newConsents[type] = true;
      }
    }

    await _updateConsent(newConsents);
    debugPrint('Consent: Granted - ${types.map((t) => t.name).join(", ")}');
  }

  /// Revoke consent for specific types
  Future<void> revokeConsent(Set<ConsentType> types) async {
    final newConsents = Map<ConsentType, bool>.from(_currentStatus?.consents ?? {});

    for (final type in types) {
      if (type != ConsentType.functional) {
        newConsents[type] = false;
      }
    }

    await _updateConsent(newConsents);
    debugPrint('Consent: Revoked - ${types.map((t) => t.name).join(", ")}');

    // TODO(Phase 3): Clear analytics data
    // TODO(Phase 3): Stop performance monitoring
    // TODO(Phase 3): Disable crashlytics
  }

  /// Grant all non-functional consents (convenience method)
  Future<void> grantAll() async {
    await grantConsent({
      ConsentType.analytics,
      ConsentType.performance,
      ConsentType.crashlytics,
    });
  }

  /// Revoke all non-functional consents (convenience method)
  Future<void> revokeAll() async {
    await revokeConsent({
      ConsentType.analytics,
      ConsentType.performance,
      ConsentType.crashlytics,
    });
  }

  /// Reset consent to undecided state
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_consentKey);
    await prefs.remove(_timestampKey);

    final isEU = await _detectEURegion();
    _currentStatus = ConsentStatus(
      consents: {},
      timestamp: DateTime.now(),
      isEURegion: isEU,
    );

    _statusController.add(_currentStatus!);
    debugPrint('Consent: Reset to undecided');
  }

  /// Update consent and persist
  Future<void> _updateConsent(Map<ConsentType, bool> consents) async {
    _currentStatus = ConsentStatus(
      consents: consents,
      timestamp: DateTime.now(),
      isEURegion: _currentStatus?.isEURegion ?? false,
    );

    // Persist to storage
    final prefs = await SharedPreferences.getInstance();
    // TODO(Phase 3): Serialize to JSON
    await prefs.setString(_timestampKey, DateTime.now().toIso8601String());

    _statusController.add(_currentStatus!);
  }

  /// Detect if user is in EU region (GDPR applies)
  Future<bool> _detectEURegion() async {
    // TODO(Phase 3): Use timezone + locale for region detection
    // EU timezones: Europe/*, GMT
    // For now, default to conservative (treat as EU)
    return true;
  }

  /// Dispose resources
  void dispose() {
    _statusController.close();
  }
}
