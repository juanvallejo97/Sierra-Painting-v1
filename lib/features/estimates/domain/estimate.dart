/// Domain model for estimate
///
/// PURPOSE:
/// Type-safe domain entity for estimates/quotes.
/// Separates domain logic from data layer representation.
///
/// FIELDS:
/// - id: Firestore document ID
/// - companyId: Company/organization ID for multi-tenant isolation
/// - customerId: Customer ID
/// - jobId: Optional job ID
/// - status: draft, sent, accepted, rejected, expired
/// - amount: Total estimate amount
/// - currency: Currency code (default USD)
/// - items: List of line items
/// - notes: Optional notes
/// - validUntil: Expiration date
/// - acceptedAt: When estimate was accepted
/// - createdAt: Creation timestamp
/// - updatedAt: Last update timestamp
library;

import 'package:cloud_firestore/cloud_firestore.dart';

enum EstimateStatus { draft, sent, accepted, rejected, expired }

class EstimateItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double? discount;

  EstimateItem({
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

  factory EstimateItem.fromMap(Map<String, dynamic> map) {
    return EstimateItem(
      description: map['description'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unitPrice'] as num).toDouble(),
      discount: map['discount'] != null
          ? (map['discount'] as num).toDouble()
          : null,
    );
  }
}

class Estimate {
  final String? id;
  final String companyId;
  final String customerId;
  final String? jobId;
  final EstimateStatus status;
  final double amount;
  final String currency;
  final List<EstimateItem> items;
  final String? notes;
  final DateTime validUntil;
  final DateTime? acceptedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Estimate({
    this.id,
    required this.companyId,
    required this.customerId,
    this.jobId,
    this.status = EstimateStatus.draft,
    required this.amount,
    this.currency = 'USD',
    required this.items,
    this.notes,
    required this.validUntil,
    this.acceptedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if estimate is expired
  bool get isExpired {
    if (status == EstimateStatus.accepted ||
        status == EstimateStatus.rejected) {
      return false;
    }
    return DateTime.now().isAfter(validUntil);
  }

  /// Create from Firestore document
  factory Estimate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Estimate(
      id: doc.id,
      companyId: data['companyId'] as String,
      customerId: data['customerId'] as String,
      jobId: data['jobId'] as String?,
      status: statusFromString(data['status'] as String),
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'USD',
      items: (data['items'] as List)
          .map((item) => EstimateItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      notes: data['notes'] as String?,
      validUntil: (data['validUntil'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'customerId': customerId,
      if (jobId != null) 'jobId': jobId,
      'status': statusToString(status),
      'amount': amount,
      'currency': currency,
      'items': items.map((item) => item.toMap()).toList(),
      if (notes != null) 'notes': notes,
      'validUntil': Timestamp.fromDate(validUntil),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Estimate copyWith({
    String? id,
    String? companyId,
    String? customerId,
    String? jobId,
    EstimateStatus? status,
    double? amount,
    String? currency,
    List<EstimateItem>? items,
    String? notes,
    DateTime? validUntil,
    DateTime? acceptedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Estimate(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      customerId: customerId ?? this.customerId,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      validUntil: validUntil ?? this.validUntil,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static EstimateStatus statusFromString(String status) {
    switch (status) {
      case 'sent':
        return EstimateStatus.sent;
      case 'accepted':
        return EstimateStatus.accepted;
      case 'rejected':
        return EstimateStatus.rejected;
      case 'expired':
        return EstimateStatus.expired;
      case 'draft':
      default:
        return EstimateStatus.draft;
    }
  }

  static String statusToString(EstimateStatus status) {
    switch (status) {
      case EstimateStatus.sent:
        return 'sent';
      case EstimateStatus.accepted:
        return 'accepted';
      case EstimateStatus.rejected:
        return 'rejected';
      case EstimateStatus.expired:
        return 'expired';
      case EstimateStatus.draft:
        return 'draft';
    }
  }
}
