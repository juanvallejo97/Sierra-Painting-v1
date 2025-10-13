/// Domain model for customer
///
/// PURPOSE:
/// Type-safe domain entity for customers.
/// Separates domain logic from data layer representation.
///
/// FIELDS:
/// - id: Firestore document ID
/// - companyId: Company/organization ID for multi-tenant isolation
/// - name: Customer full name or business name
/// - email: Contact email
/// - phone: Contact phone number
/// - address: Physical address
/// - notes: Optional notes about the customer
/// - createdAt: Creation timestamp
/// - updatedAt: Last update timestamp
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String? id;
  final String companyId;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    this.id,
    required this.companyId,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      companyId: data['companyId'] as String,
      name: data['name'] as String,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Customer copyWith({
    String? id,
    String? companyId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get display name (email or phone as fallback)
  String get displayName {
    if (email != null && email!.isNotEmpty) {
      return '$name ($email)';
    } else if (phone != null && phone!.isNotEmpty) {
      return '$name ($phone)';
    }
    return name;
  }
}
