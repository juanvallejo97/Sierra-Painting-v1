/// PII Sanitization for Telemetry & Analytics
///
/// PURPOSE:
/// - Strip personally identifiable information from all logs/events
/// - Hash user IDs before logging
/// - Redact sensitive form fields
/// - Comply with GDPR/CCPA requirements

library pii_sanitizer;

import 'dart:convert';
import 'package:crypto/crypto.dart';

// ============================================================================
// PII PATTERNS
// ============================================================================

class PIIPatterns {
  PIIPatterns._();

  // Email pattern: RFC 5322 simplified
  static final email = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    caseSensitive: false,
  );

  // Phone patterns: various formats
  static final phone = RegExp(
    r'(?:\+?\d{1,3})?[-.\s]?(?:\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}',
  );

  // Credit card pattern: 13-19 digits with optional separators
  static final creditCard = RegExp(
    r'\b(?:\d{4}[-\s]?){3}\d{4}\b',
  );

  // SSN pattern: XXX-XX-XXXX
  static final ssn = RegExp(
    r'\b\d{3}-\d{2}-\d{4}\b',
  );

  // IP addresses
  static final ipAddress = RegExp(
    r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
  );

  // Common PII field names (case-insensitive)
  static const sensitiveFields = {
    'email',
    'phone',
    'phoneNumber',
    'ssn',
    'socialSecurity',
    'creditCard',
    'cardNumber',
    'password',
    'address',
    'street',
    'city',
    'zip',
    'zipCode',
    'postalCode',
    'firstName',
    'lastName',
    'fullName',
    'dob',
    'dateOfBirth',
    'passport',
    'license',
    'bankAccount',
    'routing',
  };
}

// ============================================================================
// MAIN PII SANITIZER
// ============================================================================

class PIISanitizer {
  PIISanitizer._();

  /// Sanitize a map of parameters (for Analytics events)
  static Map<String, Object> sanitizeParams(Map<String, dynamic> params) {
    final sanitized = <String, Object>{};

    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if field name is sensitive
      if (_isSensitiveField(key)) {
        sanitized[key] = '[REDACTED]';
        continue;
      }

      // Sanitize string values
      if (value is String) {
        sanitized[key] = sanitizeString(value);
      } else if (value is num || value is bool) {
        // Numbers and booleans are safe
        sanitized[key] = value;
      } else if (value is Map) {
        // Recursively sanitize nested maps
        sanitized[key] = sanitizeParams(value.cast<String, dynamic>());
      } else if (value is List) {
        // Sanitize list elements
        sanitized[key] = value
            .map((e) => e is String ? sanitizeString(e) : e)
            .toList();
      } else {
        // Default: convert to string and sanitize
        sanitized[key] = sanitizeString(value.toString());
      }
    }

    return sanitized;
  }

  /// Sanitize a single string value
  static String sanitizeString(String value) {
    var sanitized = value;

    // Replace emails
    if (PIIPatterns.email.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(PIIPatterns.email, '[EMAIL]');
    }

    // Replace phone numbers
    if (PIIPatterns.phone.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(PIIPatterns.phone, '[PHONE]');
    }

    // Replace credit cards
    if (PIIPatterns.creditCard.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(PIIPatterns.creditCard, '[CARD]');
    }

    // Replace SSNs
    if (PIIPatterns.ssn.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(PIIPatterns.ssn, '[SSN]');
    }

    // Replace IP addresses
    if (PIIPatterns.ipAddress.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(PIIPatterns.ipAddress, '[IP]');
    }

    return sanitized;
  }

  /// Hash a user ID for logging (one-way, consistent)
  static String hashUserId(String userId) {
    final bytes = utf8.encode(userId);
    final digest = sha256.convert(bytes);
    // Return first 16 characters of hex digest
    return digest.toString().substring(0, 16);
  }

  /// Check if a field name indicates sensitive data
  static bool _isSensitiveField(String fieldName) {
    final lowerName = fieldName.toLowerCase();
    return PIIPatterns.sensitiveFields.any((sensitive) =>
        lowerName.contains(sensitive));
  }

  /// Sanitize error messages (for Crashlytics)
  static String sanitizeErrorMessage(String message) {
    return sanitizeString(message);
  }

  /// Sanitize stack traces (for Crashlytics)
  static String sanitizeStackTrace(String stackTrace) {
    var sanitized = stackTrace;

    // Remove file paths that might contain usernames
    // Example: /Users/john.doe/... → /Users/[USER]/...
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'/Users/[^/]+/'),
      (match) => '/Users/[USER]/',
    );

    sanitized = sanitized.replaceAllMapped(
      RegExp(r'/home/[^/]+/'),
      (match) => '/home/[USER]/',
    );

    return sanitized;
  }

  /// Create a sanitized user properties map for Analytics
  static Map<String, String> sanitizeUserProperties(
    Map<String, dynamic> properties,
  ) {
    final sanitized = <String, String>{};

    for (final entry in properties.entries) {
      if (_isSensitiveField(entry.key)) {
        // Skip sensitive fields entirely
        continue;
      }

      final value = entry.value;
      if (value is String) {
        sanitized[entry.key] = sanitizeString(value);
      } else {
        sanitized[entry.key] = value.toString();
      }
    }

    return sanitized;
  }

  /// Mask partial values (show last 4 digits)
  static String maskPartial(String value, {int visibleChars = 4}) {
    if (value.length <= visibleChars) {
      return '*' * value.length;
    }

    final masked = '*' * (value.length - visibleChars);
    final visible = value.substring(value.length - visibleChars);
    return masked + visible;
  }

  /// Validate that params are safe to log
  static bool isSafeToLog(Map<String, dynamic> params) {
    // Check for obvious PII patterns
    final jsonString = params.toString();

    if (PIIPatterns.email.hasMatch(jsonString)) return false;
    if (PIIPatterns.creditCard.hasMatch(jsonString)) return false;
    if (PIIPatterns.ssn.hasMatch(jsonString)) return false;

    // Check field names
    for (final key in params.keys) {
      if (_isSensitiveField(key)) return false;
    }

    return true;
  }
}
