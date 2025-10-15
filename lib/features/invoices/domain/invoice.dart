/// Domain model for invoice
///
/// PURPOSE:
/// Type-safe domain entity for invoices.
/// Separates domain logic from data layer representation.
///
/// FIELDS:
/// - id: Firestore document ID
/// - companyId: Company/organization ID for multi-tenant isolation
/// - estimateId: Optional reference to estimate (if invoice created from estimate)
/// - customerId: Customer ID
/// - jobId: Optional job ID
/// - status: pending, paid, overdue, cancelled
/// - amount: Total invoice amount
/// - currency: Currency code (default USD)
/// - items: List of line items
/// - notes: Optional notes
/// - dueDate: When payment is due
/// - paidAt: When payment was received
/// - createdAt: Creation timestamp
/// - updatedAt: Last update timestamp
library;

import 'package:cloud_firestore/cloud_firestore.dart';

enum InvoiceStatus {
  draft, // Initial state, not yet sent
  sent, // Sent to customer
  paid, // Paid (legacy - keep for backwards compatibility)
  paidCash, // Paid with cash
  overdue, // Overdue (computed from pending/sent + due date)
  cancelled, // Cancelled
  pending, // Legacy - keep for backwards compatibility
}

class InvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double? discount;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discount,
  });

  double get total {
    final subtotal = quantity * unitPrice;
    if (discount != null) {
      return subtotal - discount!;
    }
    return subtotal;
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      if (discount != null) 'discount': discount,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      description: map['description'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unitPrice'] as num).toDouble(),
      discount: map['discount'] != null
          ? (map['discount'] as num).toDouble()
          : null,
    );
  }
}

class Invoice {
  final String? id;
  final String companyId;
  final String? estimateId;
  final String customerId;
  final String customerName; // Added: friendly customer name
  final String? jobId;
  final InvoiceStatus status;
  final String?
  number; // Added: auto-generated invoice number (INV-YYYYMM-####)
  final double amount;
  final double subtotal; // Added: sum of items before tax
  final double tax; // Added: tax amount
  final String currency;
  final List<InvoiceItem> items;
  final String? notes;
  final DateTime dueDate;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Invoice({
    this.id,
    required this.companyId,
    this.estimateId,
    required this.customerId,
    required this.customerName,
    this.jobId,
    this.status = InvoiceStatus.draft,
    this.number,
    required this.amount,
    required this.subtotal,
    required this.tax,
    this.currency = 'USD',
    required this.items,
    this.notes,
    required this.dueDate,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if invoice is overdue
  bool get isOverdue {
    if (status == InvoiceStatus.paid ||
        status == InvoiceStatus.paidCash ||
        status == InvoiceStatus.cancelled) {
      return false;
    }
    return DateTime.now().isAfter(dueDate);
  }

  /// Create from Firestore document
  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Invoice(
      id: doc.id,
      companyId: data['companyId'] as String,
      estimateId: data['estimateId'] as String?,
      customerId: data['customerId'] as String,
      customerName:
          data['customerName'] as String? ??
          data['customerId']
              as String, // Fallback to ID for backwards compatibility
      jobId: data['jobId'] as String?,
      status: statusFromString(data['status'] as String),
      number: data['number'] as String?,
      amount: (data['amount'] as num).toDouble(),
      subtotal: data['subtotal'] != null
          ? (data['subtotal'] as num).toDouble()
          : (data['amount'] as num)
                .toDouble(), // Fallback for backwards compatibility
      tax: data['tax'] != null
          ? (data['tax'] as num).toDouble()
          : 0.0, // Default to 0 for backwards compatibility
      currency: data['currency'] as String? ?? 'USD',
      items: (data['items'] as List)
          .map((item) => InvoiceItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      notes: data['notes'] as String?,
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      paidAt: data['paidAt'] != null
          ? (data['paidAt'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      if (estimateId != null) 'estimateId': estimateId,
      'customerId': customerId,
      'customerName': customerName,
      if (jobId != null) 'jobId': jobId,
      'status': statusToString(status),
      if (number != null) 'number': number,
      'amount': amount,
      'subtotal': subtotal,
      'tax': tax,
      'currency': currency,
      'items': items.map((item) => item.toMap()).toList(),
      if (notes != null) 'notes': notes,
      'dueDate': Timestamp.fromDate(dueDate),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Invoice copyWith({
    String? id,
    String? companyId,
    String? estimateId,
    String? customerId,
    String? customerName,
    String? jobId,
    InvoiceStatus? status,
    String? number,
    double? amount,
    double? subtotal,
    double? tax,
    String? currency,
    List<InvoiceItem>? items,
    String? notes,
    DateTime? dueDate,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      estimateId: estimateId ?? this.estimateId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      number: number ?? this.number,
      amount: amount ?? this.amount,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static InvoiceStatus statusFromString(String status) {
    switch (status) {
      case 'draft':
        return InvoiceStatus.draft;
      case 'sent':
        return InvoiceStatus.sent;
      case 'paid':
        return InvoiceStatus.paid;
      case 'paid_cash':
      case 'paidCash':
        return InvoiceStatus.paidCash;
      case 'overdue':
        return InvoiceStatus.overdue;
      case 'cancelled':
        return InvoiceStatus.cancelled;
      case 'pending':
      default:
        return InvoiceStatus.pending;
    }
  }

  static String statusToString(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'draft';
      case InvoiceStatus.sent:
        return 'sent';
      case InvoiceStatus.paid:
        return 'paid';
      case InvoiceStatus.paidCash:
        return 'paid_cash';
      case InvoiceStatus.overdue:
        return 'overdue';
      case InvoiceStatus.cancelled:
        return 'cancelled';
      case InvoiceStatus.pending:
        return 'pending';
    }
  }
}
