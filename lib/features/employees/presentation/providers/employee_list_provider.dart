/// Employee List Provider
///
/// PURPOSE:
/// Provides list of employees for the current company.
/// Uses Riverpod AsyncNotifier for reactive state management.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/employees/data/employee_repository.dart';
import 'package:sierra_painting/features/employees/domain/employee.dart';

/// Employee list provider
final employeeListProvider = FutureProvider<List<Employee>>((ref) async {
  final repository = ref.watch(employeeRepositoryProvider);

  // Get current user's company ID
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }

  final idTokenResult = await user.getIdTokenResult();
  final companyId = idTokenResult.claims?['companyId'] as String?;

  if (companyId == null) {
    throw Exception('No company assigned to user');
  }

  // Fetch employees
  final result = await repository.getEmployees(companyId: companyId);

  return result.when(
    success: (employees) => employees,
    failure: (error) => throw Exception(error),
  );
});

/// Provider for active employees only
final activeEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  final allEmployees = await ref.watch(employeeListProvider.future);
  return allEmployees.where((e) => e.isActive).toList();
});

/// Provider for workers only (for job assignments)
final workersProvider = FutureProvider<List<Employee>>((ref) async {
  final repository = ref.watch(employeeRepositoryProvider);

  // Get current user's company ID
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }

  final idTokenResult = await user.getIdTokenResult();
  final companyId = idTokenResult.claims?['companyId'] as String?;

  if (companyId == null) {
    throw Exception('No company assigned to user');
  }

  // Fetch workers
  final result = await repository.getEmployees(
    companyId: companyId,
    role: EmployeeRole.worker,
  );

  return result.when(
    success: (employees) => employees,
    failure: (error) => throw Exception(error),
  );
});
