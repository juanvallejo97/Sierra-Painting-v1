/// Time Entry Card Widget
///
/// PURPOSE:
/// Display time entry in Admin Review with visual indicators for issues.
///
/// FEATURES:
/// - Selection checkbox for bulk actions
/// - Badges: geoOkIn/Out, invoiced, approved, >12h, overlapping, disputed
/// - Worker and job info (resolved from IDs)
/// - Time duration with visual indicators
/// - Quick actions: edit, approve, reject
/// - Tap for detail view
///
/// BADGES:
/// - Geofence In: Red if geoOkIn=false
/// - Geofence Out: Orange if geoOkOut=false
/// - >12h: Red if durationHours > 12
/// - Auto Clock-Out: Purple if has auto_clockout tag
/// - Overlapping: Orange if has overlap tag
/// - Disputed: Red if disputeNote != null
/// - Invoiced: Green if invoiceId != null (read-only)
/// - Approved: Green checkmark if approved=true
library;

import 'package:flutter/material.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

/// Time Entry Card for Admin Review
class TimeEntryCard extends StatelessWidget {
  final TimeEntry entry;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onEdit;

  const TimeEntryCard({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onTap,
    this.onApprove,
    this.onReject,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Add invoiceId tracking to TimeEntry model
    // ignore: dead_code
    final isInvoiced = false;
    final isApproved = entry.isApproved;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection checkbox
              Checkbox(
                value: isSelected,
                onChanged: (value) => onSelectionChanged(value ?? false),
              ),

              // Entry details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Worker and job info
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Worker: ${entry.workerId}', // TODO: Resolve to name
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Job: ${entry.jobId}', // TODO: Resolve to job name
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status badges (top right)
                        if (isInvoiced)
                          _buildStatusBadge(
                            'Invoiced',
                            Colors.green,
                            Icons.receipt,
                          ),
                        if (isApproved && !isInvoiced)
                          _buildStatusBadge(
                            'Approved',
                            Colors.green,
                            Icons.check_circle,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Time info
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTime(entry.clockIn)} - ${entry.clockOut != null ? _formatTime(entry.clockOut!) : 'In Progress'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${entry.durationHours?.toStringAsFixed(1) ?? '0.0'}h',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getDurationColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Exception badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (!entry.clockInGeofenceValid)
                          _buildExceptionBadge('Geo In', Colors.red),
                        if (entry.clockOutGeofenceValid == false)
                          _buildExceptionBadge('Geo Out', Colors.orange),
                        if (_exceedsTwelveHours)
                          _buildExceptionBadge('>12h', Colors.red),
                        if (_hasExceptionTag('auto_clockout'))
                          _buildExceptionBadge('Auto', Colors.purple),
                        if (_hasExceptionTag('overlap'))
                          _buildExceptionBadge('Overlap', Colors.deepOrange),
                        if (entry.disputeReason != null &&
                            entry.disputeReason!.isNotEmpty)
                          _buildExceptionBadge('Disputed', Colors.red.shade700),
                      ],
                    ),

                    // Dispute note preview
                    if (entry.disputeReason != null &&
                        entry.disputeReason!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.disputeReason!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade900,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Quick actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: isInvoiced ? null : onEdit,
                      tooltip: isInvoiced ? 'Invoiced (locked)' : 'Edit',
                      color: Colors.blue,
                    ),
                  if (onApprove != null && !isApproved)
                    IconButton(
                      icon: const Icon(Icons.check, size: 20),
                      onPressed: isInvoiced ? null : onApprove,
                      tooltip: 'Approve',
                      color: Colors.green,
                    ),
                  if (onReject != null && !isApproved)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: isInvoiced ? null : onReject,
                      tooltip: 'Reject',
                      color: Colors.red,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build exception badge (issues requiring attention)
  Widget _buildExceptionBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build status badge (invoiced, approved)
  Widget _buildStatusBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Get duration color (red if >12h)
  Color _getDurationColor() {
    if (_exceedsTwelveHours) return Colors.red;
    return Colors.grey.shade700;
  }

  /// Check if duration exceeds 12 hours
  bool get _exceedsTwelveHours {
    final duration = entry.durationHours ?? 0;
    return duration > 12;
  }

  /// Check if entry has specific exception tag
  /// TODO: Implement exception tags in TimeEntry model
  // ignore: unused_element
  bool _hasExceptionTag(String tag) {
    // ignore: dead_code
    return false; // Exception tags not yet implemented
  }

  /// Format time for display
  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }
}

/// Compact Time Entry Card (for summary views)
class CompactTimeEntryCard extends StatelessWidget {
  final TimeEntry entry;
  final VoidCallback onTap;

  const CompactTimeEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          entry.clockOut != null ? Icons.check_circle : Icons.pending,
          color: entry.clockOut != null ? Colors.green : Colors.orange,
          size: 20,
        ),
        title: Text(
          '${entry.workerId} • ${entry.jobId}',
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          '${entry.durationHours?.toStringAsFixed(1) ?? '0.0'}h',
          style: const TextStyle(fontSize: 11),
        ),
        trailing:
            null, // TODO: Add invoiceId tracking (show lock icon when invoiced)
        onTap: onTap,
      ),
    );
  }
}
