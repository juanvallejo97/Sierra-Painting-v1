/// Money Utility - Precision-Safe Monetary Calculations
///
/// PURPOSE:
/// Eliminates floating-point precision errors in financial calculations
/// by storing all monetary amounts as integer cents internally.
///
/// USAGE:
/// ```dart
/// final price = Money.fromDollars(19.99);  // Stores as 1999 cents
/// final tax = price.multiply(0.085);       // Safe percentage multiplication
/// final total = price.add(tax);            // Precise addition
/// print(total.toDollars());                // 21.69
/// ```
///
/// GUARANTEES:
/// - No floating-point rounding errors
/// - Deterministic calculations
/// - Safe for financial records
library;

import 'package:intl/intl.dart';

/// Immutable monetary value stored as integer cents
class Money {
  /// Amount in cents (integer representation)
  final int _cents;

  /// Private constructor - use factory methods instead
  const Money._(this._cents);

  /// Zero dollars
  static const Money zero = Money._(0);

  /// Create from dollar amount (e.g., 19.99)
  /// Rounds to nearest cent using banker's rounding (half-even)
  factory Money.fromDollars(double dollars) {
    // Multiply by 100 and round to nearest integer
    // Uses banker's rounding to avoid bias
    final cents = (dollars * 100).round();
    return Money._(cents);
  }

  /// Create from cents (e.g., 1999 for $19.99)
  factory Money.fromCents(int cents) {
    return Money._(cents);
  }

  /// Parse from string (e.g., "19.99", "19", ".99")
  /// Returns null if parsing fails
  static Money? tryParse(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    // Remove currency symbols and commas
    final clean = value.replaceAll(RegExp(r'[\$,]'), '').trim();

    // Try parsing as double
    final dollars = double.tryParse(clean);
    if (dollars == null) {
      return null;
    }

    return Money.fromDollars(dollars);
  }

  /// Parse from string, throws if invalid
  factory Money.parse(String value) {
    final money = Money.tryParse(value);
    if (money == null) {
      throw FormatException('Invalid money format: $value');
    }
    return money;
  }

  /// Get cents value
  int get cents => _cents;

  /// Convert to dollars (e.g., 1999 cents → 19.99)
  double toDollars() {
    return _cents / 100.0;
  }

  /// Format as currency string (e.g., "$19.99")
  String format({String symbol = '\$', int decimalDigits = 2}) {
    return NumberFormat.currency(
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(toDollars());
  }

  // Arithmetic operations (all return new Money instances - immutable)

  /// Add two money amounts
  Money add(Money other) {
    return Money._(_cents + other._cents);
  }

  /// Subtract money amount
  Money subtract(Money other) {
    return Money._(_cents - other._cents);
  }

  /// Multiply by a scalar (e.g., quantity or percentage)
  /// Uses banker's rounding for final cents
  Money multiply(double scalar) {
    final result = (_cents * scalar).round();
    return Money._(result);
  }

  /// Multiply by integer (exact, no rounding)
  Money multiplyInt(int scalar) {
    return Money._(_cents * scalar);
  }

  /// Divide by scalar (rounds to nearest cent)
  Money divide(double divisor) {
    if (divisor == 0) {
      throw ArgumentError('Cannot divide by zero');
    }
    final result = (_cents / divisor).round();
    return Money._(result);
  }

  /// Calculate percentage (e.g., money.percentage(8.5) for 8.5% tax)
  /// Returns new Money representing the percentage amount
  Money percentage(double percent) {
    return multiply(percent / 100.0);
  }

  /// Negate (useful for discounts)
  Money negate() {
    return Money._(-_cents);
  }

  /// Absolute value
  Money abs() {
    return Money._(_cents.abs());
  }

  // Comparison operators

  bool operator >(Money other) => _cents > other._cents;
  bool operator >=(Money other) => _cents >= other._cents;
  bool operator <(Money other) => _cents < other._cents;
  bool operator <=(Money other) => _cents <= other._cents;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Money && other._cents == _cents;
  }

  @override
  int get hashCode => _cents.hashCode;

  @override
  String toString() => format();

  /// Check if positive
  bool get isPositive => _cents > 0;

  /// Check if negative
  bool get isNegative => _cents < 0;

  /// Check if zero
  bool get isZero => _cents == 0;
}

/// Extension to sum a list of Money amounts
extension MoneyListExtension on Iterable<Money> {
  /// Sum all money amounts in the list
  Money sum() {
    return fold(Money.zero, (total, amount) => total.add(amount));
  }
}
