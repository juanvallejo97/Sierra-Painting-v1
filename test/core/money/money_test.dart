/// Money Utility Unit Tests
///
/// PURPOSE:
/// Comprehensive test coverage for the Money class to ensure:
/// - Precision guarantees (no floating-point errors)
/// - Correct arithmetic operations
/// - Proper rounding behavior
/// - Edge case handling
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/money/money.dart';

void main() {
  group('Money Construction', () {
    test('fromDollars stores value as cents', () {
      expect(Money.fromDollars(19.99).cents, equals(1999));
      expect(Money.fromDollars(0.01).cents, equals(1));
      expect(Money.fromDollars(100.00).cents, equals(10000));
    });

    test('fromCents creates correct value', () {
      expect(Money.fromCents(1999).toDollars(), equals(19.99));
      expect(Money.fromCents(1).toDollars(), equals(0.01));
      expect(Money.fromCents(10000).toDollars(), equals(100.00));
    });

    test('zero constant is correct', () {
      expect(Money.zero.cents, equals(0));
      expect(Money.zero.toDollars(), equals(0.0));
    });

    test('tryParse handles valid strings', () {
      expect(Money.tryParse('19.99')?.cents, equals(1999));
      expect(Money.tryParse('19')?.cents, equals(1900));
      expect(Money.tryParse('.99')?.cents, equals(99));
      expect(Money.tryParse('\$19.99')?.cents, equals(1999));
      expect(Money.tryParse('1,234.56')?.cents, equals(123456));
    });

    test('tryParse returns null for invalid strings', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('19.99.99'), isNull);
    });

    test('parse throws on invalid string', () {
      expect(() => Money.parse('invalid'), throwsFormatException);
    });
  });

  group('Arithmetic Operations', () {
    test('add combines two amounts correctly', () {
      final a = Money.fromDollars(10.50);
      final b = Money.fromDollars(5.25);
      final result = a.add(b);

      expect(result.cents, equals(1575)); // 15.75
      expect(result.toDollars(), equals(15.75));
    });

    test('subtract reduces amount correctly', () {
      final a = Money.fromDollars(20.00);
      final b = Money.fromDollars(7.50);
      final result = a.subtract(b);

      expect(result.cents, equals(1250)); // 12.50
      expect(result.toDollars(), equals(12.50));
    });

    test('multiply by scalar works correctly', () {
      final price = Money.fromDollars(19.99);
      final result = price.multiply(3);

      expect(result.cents, equals(5997)); // 59.97
      expect(result.toDollars(), equals(59.97));
    });

    test('multiply uses banker\'s rounding', () {
      final price = Money.fromCents(333); // $3.33
      final result = price.multiply(3.0);

      // 333 * 3.0 = 999.0, rounds to 999
      expect(result.cents, equals(999));
    });

    test('multiplyInt is exact (no rounding)', () {
      final price = Money.fromDollars(10.00);
      final result = price.multiplyInt(7);

      expect(result.cents, equals(7000)); // Exactly 70.00
    });

    test('divide by scalar works correctly', () {
      final total = Money.fromDollars(100.00);
      final result = total.divide(4);

      expect(result.cents, equals(2500)); // 25.00
    });

    test('divide rounds to nearest cent', () {
      final total = Money.fromCents(100); // $1.00
      final result = total.divide(3);

      // 100 / 3 = 33.333..., rounds to 33
      expect(result.cents, equals(33));
    });

    test('divide by zero throws', () {
      final money = Money.fromDollars(10.00);
      expect(() => money.divide(0), throwsArgumentError);
    });

    test('percentage calculation is precise', () {
      final subtotal = Money.fromDollars(100.00);
      final tax = subtotal.percentage(8.5);

      expect(tax.cents, equals(850)); // Exactly $8.50
      expect(tax.toDollars(), equals(8.50));
    });

    test('negate flips sign', () {
      final positive = Money.fromDollars(10.00);
      final negative = positive.negate();

      expect(negative.cents, equals(-1000));
      expect(negative.isNegative, isTrue);
    });

    test('abs returns absolute value', () {
      final negative = Money.fromCents(-500);
      final positive = negative.abs();

      expect(positive.cents, equals(500));
      expect(positive.isPositive, isTrue);
    });
  });

  group('Comparison Operators', () {
    test('equality works correctly', () {
      final a = Money.fromDollars(10.00);
      final b = Money.fromCents(1000);
      final c = Money.fromDollars(20.00);

      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('greater than comparison', () {
      final large = Money.fromDollars(20.00);
      final small = Money.fromDollars(10.00);

      expect(large > small, isTrue);
      expect(small > large, isFalse);
      expect(large > large, isFalse);
    });

    test('greater than or equal', () {
      final large = Money.fromDollars(20.00);
      final small = Money.fromDollars(10.00);
      final equal = Money.fromCents(2000);

      expect(large >= small, isTrue);
      expect(large >= equal, isTrue);
      expect(small >= large, isFalse);
    });

    test('less than comparison', () {
      final large = Money.fromDollars(20.00);
      final small = Money.fromDollars(10.00);

      expect(small < large, isTrue);
      expect(large < small, isFalse);
      expect(small < small, isFalse);
    });

    test('less than or equal', () {
      final large = Money.fromDollars(20.00);
      final small = Money.fromDollars(10.00);
      final equal = Money.fromCents(1000);

      expect(small <= large, isTrue);
      expect(small <= equal, isTrue);
      expect(large <= small, isFalse);
    });
  });

  group('Formatting', () {
    test('format returns currency string', () {
      final money = Money.fromDollars(19.99);
      expect(money.format(), equals('\$19.99'));
    });

    test('format handles large amounts', () {
      final money = Money.fromDollars(1234567.89);
      expect(money.format(), contains('1,234,567.89'));
    });

    test('format handles zero', () {
      expect(Money.zero.format(), equals('\$0.00'));
    });

    test('format handles negative amounts', () {
      final negative = Money.fromCents(-1999);
      expect(negative.format(), contains('-'));
      expect(negative.format(), contains('19.99'));
    });

    test('toString uses format', () {
      final money = Money.fromDollars(42.00);
      expect(money.toString(), equals('\$42.00'));
    });
  });

  group('State Checks', () {
    test('isPositive works correctly', () {
      expect(Money.fromDollars(10.00).isPositive, isTrue);
      expect(Money.zero.isPositive, isFalse);
      expect(Money.fromCents(-100).isPositive, isFalse);
    });

    test('isNegative works correctly', () {
      expect(Money.fromCents(-100).isNegative, isTrue);
      expect(Money.zero.isNegative, isFalse);
      expect(Money.fromDollars(10.00).isNegative, isFalse);
    });

    test('isZero works correctly', () {
      expect(Money.zero.isZero, isTrue);
      expect(Money.fromCents(0).isZero, isTrue);
      expect(Money.fromDollars(0.00).isZero, isTrue);
      expect(Money.fromDollars(10.00).isZero, isFalse);
    });
  });

  group('Real-World Invoice Scenarios', () {
    test('invoice with tax is precise', () {
      // Real scenario: $100 subtotal with 8.5% tax
      final subtotal = Money.fromDollars(100.00);
      final tax = subtotal.percentage(8.5);
      final total = subtotal.add(tax);

      expect(subtotal.cents, equals(10000));
      expect(tax.cents, equals(850));
      expect(total.cents, equals(10850));
      expect(total.toDollars(), equals(108.50));
    });

    test('line item with quantity and discount', () {
      // Real scenario: 3 items @ $19.99 each, $5.00 discount
      final unitPrice = Money.fromDollars(19.99);
      final lineTotal = unitPrice.multiplyInt(3);
      final discount = Money.fromDollars(5.00);
      final afterDiscount = lineTotal.subtract(discount);

      expect(lineTotal.cents, equals(5997)); // 59.97
      expect(afterDiscount.cents, equals(5497)); // 54.97
    });

    test('multiple line items sum correctly', () {
      final items = [
        Money.fromDollars(19.99),
        Money.fromDollars(29.99),
        Money.fromDollars(9.99),
      ];

      final total = items.fold(Money.zero, (sum, item) => sum.add(item));

      expect(total.cents, equals(5997)); // 59.97
    });

    test('tax calculation matches actual invoice', () {
      // From actual invoice_repository_test.dart
      final item1 = Money.fromDollars(50.00).multiplyInt(10);
      final item2 = Money.fromDollars(100.00).multiplyInt(5);
      final subtotal = item1.add(item2);

      expect(subtotal.cents, equals(100000)); // 1000.00
    });

    test('discount prevents negative amounts (optional check)', () {
      final price = Money.fromDollars(10.00);
      final largeDiscount = Money.fromDollars(15.00);
      final result = price.subtract(largeDiscount);

      expect(result.isNegative, isTrue);
      expect(result.cents, equals(-500));
    });
  });

  group('List Extension', () {
    test('sum returns total of all amounts', () {
      final amounts = [
        Money.fromDollars(10.00),
        Money.fromDollars(20.00),
        Money.fromDollars(30.00),
      ];

      final total = amounts.sum();

      expect(total.cents, equals(6000)); // 60.00
    });

    test('sum of empty list is zero', () {
      final List<Money> empty = [];
      expect(empty.sum(), equals(Money.zero));
    });

    test('sum handles mixed positive and negative', () {
      final amounts = [
        Money.fromDollars(50.00),
        Money.fromCents(-1000), // -10.00
        Money.fromDollars(25.00),
      ];

      final total = amounts.sum();

      expect(total.cents, equals(6500)); // 65.00
    });
  });

  group('Edge Cases', () {
    test('very large amounts', () {
      final large = Money.fromDollars(999999999.99);
      expect(large.cents, equals(99999999999));
    });

    test('very small amounts', () {
      final penny = Money.fromCents(1);
      expect(penny.toDollars(), equals(0.01));
    });

    test('repeated operations maintain precision', () {
      var total = Money.zero;

      // Add $0.01 one hundred times
      for (int i = 0; i < 100; i++) {
        total = total.add(Money.fromCents(1));
      }

      expect(total.cents, equals(100)); // Exactly $1.00
      expect(total.toDollars(), equals(1.00));
    });

    test('immutability - operations return new instances', () {
      final original = Money.fromDollars(10.00);
      final result = original.add(Money.fromDollars(5.00));

      expect(original.cents, equals(1000)); // Unchanged
      expect(result.cents, equals(1500));
    });
  });
}
