/// Employee New Screen
///
/// PURPOSE:
/// Form to create/invite a new employee.
///
/// FEATURES:
/// - Simple form with name, phone, role
/// - Phone number validation (E.164 format)
/// - Creates employee with "invited" status
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/employees/data/employee_repository.dart';
import 'package:sierra_painting/features/employees/domain/employee.dart';
import 'package:sierra_painting/features/employees/presentation/providers/employee_list_provider.dart';

class EmployeeNewScreen extends ConsumerStatefulWidget {
  const EmployeeNewScreen({super.key});

  @override
  ConsumerState<EmployeeNewScreen> createState() => _EmployeeNewScreenState();
}

class _EmployeeNewScreenState extends ConsumerState<EmployeeNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  EmployeeRole _selectedRole = EmployeeRole.worker;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get company ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final idTokenResult = await user.getIdTokenResult();
      final companyId = idTokenResult.claims?['companyId'] as String?;

      if (companyId == null) {
        throw Exception('No company assigned to user');
      }

      // Create employee
      final repository = ref.read(employeeRepositoryProvider);
      final request = CreateEmployeeRequest(
        companyId: companyId,
        displayName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
      );

      final result = await repository.createEmployee(request);

      if (!mounted) return;

      result.when(
        success: (employee) {
          // Invalidate list to refresh
          ref.invalidate(employeeListProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee created successfully'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.of(context).pop(true);
        },
        failure: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create employee: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Employee')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter employee name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+15551234567 (E.164 format)',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                // Basic E.164 validation
                if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value.trim())) {
                  return 'Invalid phone format (use +15551234567)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email (optional)
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    !RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                  return 'Invalid email format';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Role
            DropdownButtonFormField<EmployeeRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.work),
                border: OutlineInputBorder(),
              ),
              items: EmployeeRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Employee'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
