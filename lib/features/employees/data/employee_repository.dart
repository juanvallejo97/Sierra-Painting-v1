/// Employee Repository - Data Layer
///
/// PURPOSE:
/// Repository pattern implementation for employee operations.
/// Centralizes all employee API calls with:
/// - Type-safe Firestore operations
/// - Company isolation (multi-tenant)
/// - Result-based error handling
///
/// RESPONSIBILITIES:
/// - Create employees (invite)
/// - Fetch employees with filters
/// - Update employee status
/// - Link employee to Firebase Auth UID
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/firestore_provider.dart';
import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/employees/domain/employee.dart';

/// Create employee request
class CreateEmployeeRequest {
  final String companyId;
  final String displayName;
  final String phone; // E.164 format
  final EmployeeRole role;
  final String? email;

  CreateEmployeeRequest({
    required this.companyId,
    required this.displayName,
    required this.phone,
    this.role = EmployeeRole.worker,
    this.email,
  });
}

/// Employee Repository
class EmployeeRepository {
  final FirebaseFirestore _firestore;

  EmployeeRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Create a new employee (invite)
  ///
  /// SECURITY: Requires companyId to be set (enforced by Firestore rules)
  /// Only admin/manager roles can create employees.
  Future<Result<Employee, String>> createEmployee(
    CreateEmployeeRequest request,
  ) async {
    try {
      final now = DateTime.now();
      final employee = Employee(
        companyId: request.companyId,
        displayName: request.displayName,
        phone: request.phone,
        role: request.role,
        status: EmployeeStatus.invited,
        email: request.email,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('employees')
          .add(employee.toFirestore());

      final createdEmployee = employee.copyWith(id: docRef.id);
      return Result.success(createdEmployee);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get employees for a company
  Future<Result<List<Employee>, String>> getEmployees({
    required String companyId,
    EmployeeStatus? status,
    EmployeeRole? role,
  }) async {
    try {
      Query query = _firestore
          .collection('employees')
          .where('companyId', isEqualTo: companyId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.toFirestore());
      }

      if (role != null) {
        query = query.where('role', isEqualTo: role.toFirestore());
      }

      query = query.orderBy('displayName');

      final snapshot = await query.get();
      final employees = snapshot.docs
          .map((doc) => Employee.fromFirestore(doc))
          .toList();

      return Result.success(employees);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get a single employee by ID
  Future<Result<Employee, String>> getEmployee(String employeeId) async {
    try {
      final doc = await _firestore
          .collection('employees')
          .doc(employeeId)
          .get();

      if (!doc.exists) {
        return Result.failure('Employee not found');
      }

      final employee = Employee.fromFirestore(doc);
      return Result.success(employee);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get employee by phone number
  Future<Result<Employee?, String>> getEmployeeByPhone({
    required String companyId,
    required String phone,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('employees')
          .where('companyId', isEqualTo: companyId)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return Result.success(null);
      }

      final employee = Employee.fromFirestore(snapshot.docs.first);
      return Result.success(employee);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Update employee status
  Future<Result<Employee, String>> updateStatus({
    required String employeeId,
    required EmployeeStatus status,
  }) async {
    try {
      await _firestore.collection('employees').doc(employeeId).update({
        'status': status.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Fetch updated employee
      return await getEmployee(employeeId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Link employee to Firebase Auth UID (after onboarding)
  Future<Result<Employee, String>> linkToAuthUser({
    required String employeeId,
    required String uid,
  }) async {
    try {
      await _firestore.collection('employees').doc(employeeId).update({
        'uid': uid,
        'status': EmployeeStatus.active.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Fetch updated employee
      return await getEmployee(employeeId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Update employee details
  Future<Result<Employee, String>> updateEmployee({
    required String employeeId,
    String? displayName,
    String? phone,
    String? email,
    EmployeeRole? role,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) updates['displayName'] = displayName;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (role != null) updates['role'] = role.toFirestore();

      await _firestore.collection('employees').doc(employeeId).update(updates);

      // Fetch updated employee
      return await getEmployee(employeeId);
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
          return 'Employee not found.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    return 'An unexpected error occurred: $error';
  }
}

/// Provider for EmployeeRepository
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return EmployeeRepository(firestore: firestore);
});
