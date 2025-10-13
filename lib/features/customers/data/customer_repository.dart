/// Customer Repository - Data Layer
///
/// PURPOSE:
/// Repository pattern for customer CRUD operations.
/// Handles Firestore integration with company isolation.
///
/// FEATURES:
/// - Create/read/update/delete customers
/// - Company-scoped queries
/// - Search by name
/// - Result-based error handling
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/firestore_provider.dart';
import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/customers/domain/customer.dart';

/// Create customer request
class CreateCustomerRequest {
  final String companyId;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? notes;

  CreateCustomerRequest({
    required this.companyId,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.notes,
  });
}

/// Customer Repository
class CustomerRepository {
  final FirebaseFirestore _firestore;

  CustomerRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Create a new customer
  Future<Result<Customer, String>> createCustomer(
    CreateCustomerRequest request,
  ) async {
    try {
      final now = DateTime.now();
      final customer = Customer(
        companyId: request.companyId,
        name: request.name,
        email: request.email,
        phone: request.phone,
        address: request.address,
        notes: request.notes,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('customers')
          .add(customer.toFirestore());

      final createdCustomer = customer.copyWith(id: docRef.id);
      return Result.success(createdCustomer);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get customers for a company
  Future<Result<List<Customer>, String>> getCustomers({
    required String companyId,
    String? searchQuery,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('customers')
          .where('companyId', isEqualTo: companyId)
          .orderBy('name')
          .limit(limit);

      final snapshot = await query.get();
      var customers = snapshot.docs
          .map((doc) => Customer.fromFirestore(doc))
          .toList();

      // Client-side search if query provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        customers = customers.where((customer) {
          return customer.name.toLowerCase().contains(lowerQuery) ||
              (customer.email?.toLowerCase().contains(lowerQuery) ?? false) ||
              (customer.phone?.contains(searchQuery) ?? false);
        }).toList();
      }

      return Result.success(customers);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get a single customer by ID
  Future<Result<Customer, String>> getCustomer(String customerId) async {
    try {
      final doc = await _firestore
          .collection('customers')
          .doc(customerId)
          .get();

      if (!doc.exists) {
        return Result.failure('Customer not found');
      }

      final customer = Customer.fromFirestore(doc);
      return Result.success(customer);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Update customer
  Future<Result<Customer, String>> updateCustomer({
    required String customerId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (address != null) updates['address'] = address;
      if (notes != null) updates['notes'] = notes;

      await _firestore.collection('customers').doc(customerId).update(updates);

      // Fetch updated customer
      return await getCustomer(customerId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Delete customer
  Future<Result<void, String>> deleteCustomer(String customerId) async {
    try {
      await _firestore.collection('customers').doc(customerId).delete();
      return Result.success(null);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Map Firestore errors to user-friendly messages
  String _mapError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action.';
        case 'not-found':
          return 'Customer not found.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    return 'An unexpected error occurred: $error';
  }
}

/// Provider for CustomerRepository
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CustomerRepository(firestore: firestore);
});
