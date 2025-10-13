/// Job Create Screen
///
/// PURPOSE:
/// Admin/Manager interface to create new job sites with geofence settings.
/// Essential for geofence-enforced timeclock system.
///
/// FEATURES:
/// - Job name and customer selection
/// - Address input with geocoding (or manual lat/lng)
/// - Geofence radius configuration (75m-250m)
/// - Environment type selection (urban/suburban/rural)
/// - Worker assignment
/// - Start/end date scheduling
///
/// VALIDATION:
/// - Required: name, address, geofence settings
/// - Radius: 75m minimum, 250m maximum
/// - Must have valid coordinates before saving
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';

/// Job Create Screen - Skeleton
class JobCreateScreen extends ConsumerStatefulWidget {
  const JobCreateScreen({super.key});

  @override
  ConsumerState<JobCreateScreen> createState() => _JobCreateScreenState();
}

class _JobCreateScreenState extends ConsumerState<JobCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  // Form state
  String? _selectedCustomerId;
  JobEnvironment _environment = JobEnvironment.suburban;
  double? _customRadius;
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _assignedWorkerIds = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Job'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info Section
            _buildSectionHeader('Basic Information'),
            const SizedBox(height: 12),
            _buildJobNameField(),
            const SizedBox(height: 16),
            _buildCustomerSelector(),
            const SizedBox(height: 24),

            // Location Section
            _buildSectionHeader('Job Site Location'),
            const SizedBox(height: 12),
            _buildAddressField(),
            const SizedBox(height: 16),
            _buildManualCoordinatesFields(),
            const SizedBox(height: 24),

            // Geofence Section
            _buildSectionHeader('Geofence Settings'),
            const SizedBox(height: 12),
            _buildEnvironmentSelector(),
            const SizedBox(height: 16),
            _buildGeofenceRadiusField(),
            const SizedBox(height: 16),
            _buildGeofenceInfoCard(),
            const SizedBox(height: 24),

            // Schedule Section
            _buildSectionHeader('Schedule'),
            const SizedBox(height: 12),
            _buildDateFields(),
            const SizedBox(height: 24),

            // Worker Assignment Section
            _buildSectionHeader('Assigned Workers'),
            const SizedBox(height: 12),
            _buildWorkerAssignment(),
            const SizedBox(height: 24),

            // Notes Section
            _buildSectionHeader('Notes'),
            const SizedBox(height: 12),
            _buildNotesField(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildJobNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Job Name',
        hintText: 'e.g., Smith Residence - Exterior Paint',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.work),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Job name is required';
        }
        return null;
      },
    );
  }

  Widget _buildCustomerSelector() {
    // TODO: Replace with actual customer provider
    return DropdownButtonFormField<String>(
      initialValue: _selectedCustomerId,
      decoration: const InputDecoration(
        labelText: 'Customer',
        hintText: 'Select customer',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      items: const [
        // TODO: Load from customer repository
        DropdownMenuItem(value: null, child: Text('Select customer...')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCustomerId = value;
        });
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      decoration: InputDecoration(
        labelText: 'Address',
        hintText: '123 Main St, San Francisco, CA 94102',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.location_on),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // TODO: Implement geocoding lookup
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Geocoding not implemented yet')),
            );
          },
          tooltip: 'Geocode Address',
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Address is required';
        }
        return null;
      },
    );
  }

  Widget _buildManualCoordinatesFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or enter coordinates manually:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '37.7749',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final lat = double.tryParse(value);
                    if (lat == null || lat < -90 || lat > 90) {
                      return 'Invalid latitude';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '-122.4194',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final lng = double.tryParse(value);
                    if (lng == null || lng < -180 || lng > 180) {
                      return 'Invalid longitude';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnvironmentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Environment Type', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        SegmentedButton<JobEnvironment>(
          segments: const [
            ButtonSegment(
              value: JobEnvironment.urban,
              label: Text('Urban\n100m'),
            ),
            ButtonSegment(
              value: JobEnvironment.suburban,
              label: Text('Suburban\n150m'),
            ),
            ButtonSegment(
              value: JobEnvironment.rural,
              label: Text('Rural\n250m'),
            ),
          ],
          selected: {_environment},
          onSelectionChanged: (Set<JobEnvironment> selected) {
            setState(() {
              _environment = selected.first;
              // Clear custom radius when environment changes
              _customRadius = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildGeofenceRadiusField() {
    final defaultRadius = _environment.defaultRadius;

    return TextFormField(
      initialValue: _customRadius?.toStringAsFixed(0),
      decoration: InputDecoration(
        labelText: 'Geofence Radius (meters)',
        hintText: 'Default: ${defaultRadius.toStringAsFixed(0)}m',
        helperText: 'Range: 75m - 250m',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.circle_outlined),
        suffixText: 'm',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        if (value.isEmpty) {
          setState(() {
            _customRadius = null;
          });
        } else {
          final radius = double.tryParse(value);
          if (radius != null) {
            setState(() {
              _customRadius = radius;
            });
          }
        }
      },
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final radius = double.tryParse(value);
          if (radius == null) {
            return 'Invalid number';
          }
          if (radius < 75 || radius > 250) {
            return 'Radius must be between 75m and 250m';
          }
        }
        return null;
      },
    );
  }

  Widget _buildGeofenceInfoCard() {
    final effectiveRadius = _customRadius ?? _environment.defaultRadius;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Workers can only clock in/out within ${effectiveRadius.toStringAsFixed(0)}m of the job site. GPS accuracy buffer of 15m is automatically applied.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFields() {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            title: const Text('Start Date'),
            subtitle: Text(
              _startDate != null ? _formatDate(_startDate!) : 'Not set',
            ),
            leading: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _startDate = date;
                });
              }
            },
          ),
        ),
        Expanded(
          child: ListTile(
            title: const Text('End Date'),
            subtitle: Text(
              _endDate != null ? _formatDate(_endDate!) : 'Not set',
            ),
            leading: const Icon(Icons.event),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _endDate ?? _startDate ?? DateTime.now(),
                firstDate: _startDate ?? DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _endDate = date;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerAssignment() {
    // TODO: Replace with actual worker provider
    return Card(
      child: ListTile(
        title: Text(
          _assignedWorkerIds.isEmpty
              ? 'No workers assigned'
              : '${_assignedWorkerIds.length} worker(s) assigned',
        ),
        subtitle: const Text('Tap to assign workers'),
        leading: const Icon(Icons.people),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Show worker selection dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Worker assignment not implemented yet'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes',
        hintText: 'Additional details about the job...',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 4,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // TODO: Implement job creation
    // 1. Validate coordinates (either from geocoding or manual entry)
    // 2. Create JobLocation with lat/lng/radius
    // 3. Create Job object
    // 4. Call JobRepository.createJob()
    // 5. Create assignments for selected workers
    // 6. Navigate back with success message

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1)); // Simulate API call

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job creation not fully implemented yet'),
          backgroundColor: Colors.orange,
        ),
      );

      Navigator.of(context).pop();
    }
  }
}
