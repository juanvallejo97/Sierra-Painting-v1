/// PHASE 2: SKELETON CODE - Invoice Calculator V2
///
/// PURPOSE:
/// - Precise currency calculations (no floating point errors)
/// - Support for multiple tax modes (inclusive, exclusive, compound)
/// - Line item discounts with percentage or flat amount
/// - Rounding strategies (half-up, half-even, banker's rounding)
/// - Breakdown generation for display

library invoice_calculator_v2;

import 'dart:math' as math;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

enum TaxMode {
  exclusive, // Tax added on top of subtotal (US standard)
  inclusive, // Tax already included in price (EU standard)
  compound, // Tax on tax (Canadian GST+PST)
  none, // No tax
}

enum RoundingMode {
  halfUp, // 0.5 rounds up (commercial rounding)
  halfEven, // 0.5 rounds to nearest even (banker's rounding)
  down, // Always round down
  up, // Always round up
}

enum DiscountType {
  percentage, // Discount as percentage (e.g., 10%)
  flatAmount, // Discount as fixed amount (e.g., $50)
}

// ============================================================================
// LINE ITEM
// ============================================================================

class LineItem {
  final String id;
  final String description;
  final int quantity;
  final int unitPriceCents; // Store as cents to avoid float errors
  final DiscountType? discountType;
  final double? discountValue;
  final bool taxable;

  const LineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    this.discountType,
    this.discountValue,
    this.taxable = true,
  });

  /// Calculate line total before tax
  int calculateSubtotalCents() {
    final baseAmount = quantity * unitPriceCents;

    if (discountType == null || discountValue == null) {
      return baseAmount;
    }

    switch (discountType!) {
      case DiscountType.percentage:
        final discountAmount = (baseAmount * discountValue! / 100).round();
        return baseAmount - discountAmount;
      case DiscountType.flatAmount:
        final discountCents = (discountValue! * 100).round();
        return math.max(0, baseAmount - discountCents);
    }
  }

  /// Get discount amount in cents
  int getDiscountCents() {
    if (discountType == null || discountValue == null) {
      return 0;
    }

    final baseAmount = quantity * unitPriceCents;

    switch (discountType!) {
      case DiscountType.percentage:
        return (baseAmount * discountValue! / 100).round();
      case DiscountType.flatAmount:
        return (discountValue! * 100).round();
    }
  }
}

// ============================================================================
// INVOICE CALCULATION RESULT
// ============================================================================

class InvoiceCalculation {
  final int subtotalCents;
  final int discountCents;
  final int taxableAmountCents;
  final int taxCents;
  final int totalCents;
  final List<TaxBreakdown> taxBreakdowns;
  final List<LineItemBreakdown> lineItemBreakdowns;

  const InvoiceCalculation({
    required this.subtotalCents,
    required this.discountCents,
    required this.taxableAmountCents,
    required this.taxCents,
    required this.totalCents,
    required this.taxBreakdowns,
    required this.lineItemBreakdowns,
  });

  /// Convert cents to dollars for display
  double get subtotal => subtotalCents / 100.0;
  double get discount => discountCents / 100.0;
  double get taxableAmount => taxableAmountCents / 100.0;
  double get tax => taxCents / 100.0;
  double get total => totalCents / 100.0;
}

class TaxBreakdown {
  final String label;
  final double rate;
  final int amountCents;

  const TaxBreakdown({
    required this.label,
    required this.rate,
    required this.amountCents,
  });

  double get amount => amountCents / 100.0;
}

class LineItemBreakdown {
  final String lineItemId;
  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;

  const LineItemBreakdown({
    required this.lineItemId,
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
  });
}

// ============================================================================
// MAIN INVOICE CALCULATOR
// ============================================================================

class InvoiceCalculator {
  InvoiceCalculator._();

  /// Calculate invoice totals with precise currency handling
  static InvoiceCalculation calculate({
    required List<LineItem> lineItems,
    required TaxMode taxMode,
    required double taxRate,
    double? secondaryTaxRate, // For compound tax
    RoundingMode roundingMode = RoundingMode.halfUp,
  }) {
    // TODO(Phase 3): Validate inputs
    if (lineItems.isEmpty) {
      return const InvoiceCalculation(
        subtotalCents: 0,
        discountCents: 0,
        taxableAmountCents: 0,
        taxCents: 0,
        totalCents: 0,
        taxBreakdowns: [],
        lineItemBreakdowns: [],
      );
    }

    // Calculate subtotals
    int subtotalCents = 0;
    int totalDiscountCents = 0;
    final lineItemBreakdowns = <LineItemBreakdown>[];

    for (final item in lineItems) {
      final itemSubtotal = item.calculateSubtotalCents();
      final itemDiscount = item.getDiscountCents();

      subtotalCents += itemSubtotal;
      totalDiscountCents += itemDiscount;

      lineItemBreakdowns.add(LineItemBreakdown(
        lineItemId: item.id,
        subtotalCents: itemSubtotal,
        discountCents: itemDiscount,
        taxCents: 0, // Calculated later
        totalCents: itemSubtotal,
      ));
    }

    // Calculate taxable amount (only taxable items)
    int taxableAmountCents = 0;
    for (final item in lineItems) {
      if (item.taxable) {
        taxableAmountCents += item.calculateSubtotalCents();
      }
    }

    // Calculate tax based on mode
    int taxCents = 0;
    final taxBreakdowns = <TaxBreakdown>[];

    switch (taxMode) {
      case TaxMode.exclusive:
        taxCents = _calculateExclusiveTax(taxableAmountCents, taxRate, roundingMode);
        taxBreakdowns.add(TaxBreakdown(
          label: 'Tax',
          rate: taxRate,
          amountCents: taxCents,
        ));
        break;

      case TaxMode.inclusive:
        taxCents = _calculateInclusiveTax(taxableAmountCents, taxRate, roundingMode);
        taxBreakdowns.add(TaxBreakdown(
          label: 'Tax (included)',
          rate: taxRate,
          amountCents: taxCents,
        ));
        break;

      case TaxMode.compound:
        if (secondaryTaxRate == null) {
          throw ArgumentError('Compound tax requires secondaryTaxRate');
        }
        final primaryTax = _calculateExclusiveTax(taxableAmountCents, taxRate, roundingMode);
        final secondaryTax = _calculateExclusiveTax(
          taxableAmountCents + primaryTax,
          secondaryTaxRate,
          roundingMode,
        );
        taxCents = primaryTax + secondaryTax;

        taxBreakdowns.addAll([
          TaxBreakdown(label: 'Primary Tax', rate: taxRate, amountCents: primaryTax),
          TaxBreakdown(
            label: 'Secondary Tax',
            rate: secondaryTaxRate,
            amountCents: secondaryTax,
          ),
        ]);
        break;

      case TaxMode.none:
        taxCents = 0;
        break;
    }

    // Calculate total
    final totalCents = subtotalCents + taxCents;

    return InvoiceCalculation(
      subtotalCents: subtotalCents,
      discountCents: totalDiscountCents,
      taxableAmountCents: taxableAmountCents,
      taxCents: taxCents,
      totalCents: totalCents,
      taxBreakdowns: taxBreakdowns,
      lineItemBreakdowns: lineItemBreakdowns,
    );
  }

  /// Calculate tax for exclusive mode (tax on top)
  static int _calculateExclusiveTax(int amountCents, double taxRate, RoundingMode mode) {
    final taxAmount = amountCents * (taxRate / 100.0);
    return _roundCents(taxAmount, mode);
  }

  /// Calculate tax for inclusive mode (extract tax from total)
  static int _calculateInclusiveTax(int amountCents, double taxRate, RoundingMode mode) {
    // Formula: tax = amount * (taxRate / (100 + taxRate))
    final taxAmount = amountCents * (taxRate / (100.0 + taxRate));
    return _roundCents(taxAmount, mode);
  }

  /// Round cents based on rounding mode
  static int _roundCents(double value, RoundingMode mode) {
    switch (mode) {
      case RoundingMode.halfUp:
        return value.round();
      case RoundingMode.halfEven:
        // Banker's rounding: round to nearest even
        final floor = value.floor();
        final ceil = value.ceil();
        final diff = value - floor;

        if (diff < 0.5) {
          return floor;
        } else if (diff > 0.5) {
          return ceil;
        } else {
          // Exactly 0.5 - round to even
          return floor.isEven ? floor : ceil;
        }
      case RoundingMode.down:
        return value.floor();
      case RoundingMode.up:
        return value.ceil();
    }
  }
}
