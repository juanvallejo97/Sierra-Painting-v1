/// Job Assign Screen
///
/// PURPOSE:
/// Allow admin to assign workers to a job with shift details.
///
/// FEATURES:
/// - Select multiple workers
/// - Set shift start/end times
/// - Add notes
/// - Create assignments in Firestore
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/employees/presentation/providers/employee_list_provider.dart';
import 'package:sierra_painting/features/jobs/domain/assignment.dart';

class JobAssignScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobAssignScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobAssignScreen> createState() => _JobAssignScreenState();
}

class _JobAssignScreenState extends ConsumerState<JobAssignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final Set<String> _selectedWorkerIds = {};
  DateTime _shiftStart = DateTime.now();
  DateTime _shiftEnd = DateTime.now().add(const Duration(hours: 8));
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _shiftStart,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_shiftStart),
    );

    if (time == null) return;

    setState(() {
      _shiftStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      // Auto-adjust end time to be 8 hours after start
      if (_shiftEnd.isBefore(_shiftStart)) {
        _shiftEnd = _shiftStart.add(const Duration(hours: 8));
      }
    });
  }

  Future<void> _selectEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _shiftEnd,
      firstDate: _shiftStart,
      lastDate: _shiftStart.add(const Duration(days: 2)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_shiftEnd),
    );

    if (time == null) return;

    setState(() {
      _shiftEnd = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one worker'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_shiftEnd.isBefore(_shiftStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get company ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final idTokenResult = await user.getIdTokenResult();
      final companyId = idTokenResult.claims?['companyId'] as String?;
      if (companyId == null) throw Exception('No company assigned');

      // Create assignments for each selected worker
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final now = DateTime.now();

      for (final workerId in _selectedWorkerIds) {
        final assignmentRef = firestore.collection('assignments').doc();
        final assignment = Assignment(
          companyId: companyId,
          userId: workerId,
          jobId: widget.jobId,
          active: true,
          startDate: _shiftStart,
          endDate: _shiftEnd,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          createdAt: now,
          updatedAt: now,
        );

        batch.set(assignmentRef, assignment.toFirestore());
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Assigned ${_selectedWorkerIds.length} worker(s) successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
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
    final workersAsync = ref.watch(workersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Workers')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: workersAsync.when(
                data: (workers) {
                  if (workers.isEmpty) {
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
                            'No workers available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add workers first before assigning them to jobs',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Shift times section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shift Details',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.calendar_today),
                                title: const Text('Start Time'),
                                subtitle: Text(_formatDateTime(_shiftStart)),
                                trailing: const Icon(Icons.edit),
                                onTap: _selectStartTime,
                              ),
                              ListTile(
                                leading: const Icon(Icons.event),
                                title: const Text('End Time'),
                                subtitle: Text(_formatDateTime(_shiftEnd)),
                                trailing: const Icon(Icons.edit),
                                onTap: _selectEndTime,
                              ),
                              const SizedBox(height: 8),
                              // Duration display
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Duration: ${_calculateDuration()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes field
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'Add notes about this assignment',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Workers selection header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Workers',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_selectedWorkerIds.isNotEmpty)
                            Chip(
                              label: Text(
                                '${_selectedWorkerIds.length} selected',
                              ),
                              backgroundColor: Colors.blue.shade100,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Workers list
                      ...workers.map((worker) {
                        final isSelected = _selectedWorkerIds.contains(
                          worker.id,
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedWorkerIds.add(worker.id!);
                                } else {
                                  _selectedWorkerIds.remove(worker.id);
                                }
                              });
                            },
                            title: Text(worker.displayName),
                            subtitle: Text(worker.phone),
                            secondary: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              child: Icon(
                                Icons.person,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Error loading workers'),
                      const SizedBox(height: 8),
                      Text(error.toString()),
                    ],
                  ),
                ),
              ),
            ),

            // Submit button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Assign Workers',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/$year at $hour:$minute $period';
  }

  String _calculateDuration() {
    final duration = _shiftEnd.difference(_shiftStart);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
