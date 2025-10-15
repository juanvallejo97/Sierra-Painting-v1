/// Employees List Screen
///
/// PURPOSE:
/// Shows list of all employees for admins to manage.
///
/// FEATURES:
/// - List of employees with status, role, and contact info
/// - Filter by status (all, invited, active, inactive)
/// - Tap to call or text employee
/// - Add new employee button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/widgets/admin_scaffold.dart';
import 'package:sierra_painting/features/employees/domain/employee.dart';
import 'package:sierra_painting/features/employees/presentation/providers/employee_list_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class EmployeesListScreen extends ConsumerStatefulWidget {
  const EmployeesListScreen({super.key});

  @override
  ConsumerState<EmployeesListScreen> createState() =>
      _EmployeesListScreenState();
}

class _EmployeesListScreenState extends ConsumerState<EmployeesListScreen> {
  EmployeeStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);

    return AdminScaffold(
      title: 'Employees',
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
          onPressed: _showFilterDialog,
        ),
      ],
      body: employeesAsync.when(
        data: (employees) {
          // Apply filter
          var filteredEmployees = employees;
          if (_statusFilter != null) {
            filteredEmployees = employees
                .where((employee) => employee.status == _statusFilter)
                .toList();
          }

          if (filteredEmployees.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    employees.isEmpty
                        ? 'No employees yet'
                        : 'No matching employees',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    employees.isEmpty
                        ? 'Add your first employee to get started'
                        : 'Try adjusting your filters',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredEmployees.length,
            itemBuilder: (context, index) {
              return _buildEmployeeCard(filteredEmployees[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error loading employees',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(employeeListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/employees/new'),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
    );
  }

  Widget _buildEmployeeCard(Employee employee) {
    Color statusColor;
    IconData statusIcon;

    switch (employee.status) {
      case EmployeeStatus.active:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case EmployeeStatus.invited:
        statusColor = Colors.orange;
        statusIcon = Icons.mail_outline;
        break;
      case EmployeeStatus.inactive:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          employee.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(employee.phone),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    employee.status.displayName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    employee.role.displayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () => _callEmployee(employee.phone),
              tooltip: 'Call',
            ),
            IconButton(
              icon: const Icon(Icons.message, color: Colors.blue),
              onPressed: () => _textEmployee(employee.phone),
              tooltip: 'Text',
            ),
          ],
        ),
      ),
    );
  }

  void _callEmployee(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _textEmployee(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Employees'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Status:'),
            const SizedBox(height: 8),
            ...EmployeeStatus.values.map((status) {
              return RadioListTile<EmployeeStatus?>(
                title: Text(status.displayName),
                value: status,
                groupValue: _statusFilter,
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                  Navigator.pop(context);
                },
              );
            }),
            RadioListTile<EmployeeStatus?>(
              title: const Text('All'),
              value: null,
              groupValue: _statusFilter,
              onChanged: (value) {
                setState(() {
                  _statusFilter = null;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
