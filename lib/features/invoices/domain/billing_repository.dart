/// Billing Repository Interface
///
/// PURPOSE:
/// Defines contracts for converting approved time entries to invoices.
/// Streamlines the time → billing workflow for MVP.
///
/// WORKFLOW:
/// 1. Admin reviews time entries in Admin Review screen
/// 2. Bulk-approves entries for a job/customer
/// 3. Clicks "Create Invoice from Time"
/// 4. System aggregates hours by job/customer
/// 5. Creates invoice with line items: "Labor - N hours @ $rate"
/// 6. Locks time entries by setting invoiceId
/// 7. Prevents further edits (unless forced with audit trail)
///
/// ACCEPTANCE GATES:
/// - Approve 100 entries and create invoice in ≤5s
/// - Editing invoice doesn't mutate timeEntries (references only)
/// - Locked entries show "Invoiced" badge in UI
library;

import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

/// Money value object for safe currency handling
class Money {
  final double amount;
  final String currency;

  const Money({required this.amount, this.currency = 'USD'});

  @override
  String toString() => '\$$amount $currency';
}

/// Customer reference for invoice creation
class CustomerRef {
  final String id;
  final String name;
  final String? email;

  const CustomerRef({required this.id, required this.name, this.email});
}

/// Request to create invoice from time entries
class CreateInvoiceFromTimeRequest {
  final String companyId;
  final String jobId; // Group by job for aggregation
  final List<String> timeEntryIds; // Selected approved entries
  final Money hourlyRate; // Billing rate for labor
  final CustomerRef customer; // Who gets billed
  final DateTime dueDate; // Invoice payment due date
  final String? notes; // Optional invoice notes

  CreateInvoiceFromTimeRequest({
    required this.companyId,
    required this.jobId,
    required this.timeEntryIds,
    required this.hourlyRate,
    required this.customer,
    required this.dueDate,
    this.notes,
  });
}

/// Result of invoice creation from time
class InvoiceFromTimeResult {
  final Invoice invoice; // Created invoice
  final List<TimeEntry> lockedEntries; // Time entries that were locked
  final double totalHours; // Total hours billed
  final Money totalAmount; // Total invoice amount

  InvoiceFromTimeResult({
    required this.invoice,
    required this.lockedEntries,
    required this.totalHours,
    required this.totalAmount,
  });
}

/// Abstract repository for billing operations
///
/// Implementation should:
/// 1. Validate all entries are approved and not already invoiced
/// 2. Aggregate duration across all entries
/// 3. Create invoice with line items
/// 4. Atomically set invoiceId on all time entries (transaction)
/// 5. Write audit record for the operation
abstract class BillingRepository {
  /// Create invoice from approved time entries
  ///
  /// This is a critical operation that must be atomic:
  /// - Either all time entries are locked with invoiceId, or none
  /// - Use Firestore batch writes or transaction
  ///
  /// Validations:
  /// - All entries must be approved (approved == true)
  /// - All entries must not be invoiced (invoiceId == null)
  /// - All entries must belong to the same company
  /// - Hourly rate must be > 0
  /// - Must have at least one time entry
  ///
  /// Error cases:
  /// - "invalid-state": If any entry is not approved or already invoiced
  /// - "permission-denied": If user doesn't have admin/manager role
  /// - "not-found": If any time entry doesn't exist
  Future<Result<InvoiceFromTimeResult, String>> createInvoiceFromTime(
    CreateInvoiceFromTimeRequest request,
  );

  /// Fetch invoice with populated time entry references
  ///
  /// Resolves invoice.timeEntryIds to actual TimeEntry objects
  /// for display in invoice detail view.
  Future<Result<(Invoice, List<TimeEntry>), String>> getInvoiceWithTimeEntries(
    String invoiceId,
  );

  /// Unlock time entries from invoice (admin-only, rare operation)
  ///
  /// Use case: Invoice was created in error and needs to be deleted.
  /// This removes invoiceId from time entries so they can be re-invoiced.
  ///
  /// Requires:
  /// - Admin role
  /// - Audit reason
  /// - Invoice must not be paid
  ///
  /// Creates audit trail for the unlock operation.
  Future<Result<void, String>> unlockTimeEntries({
    required String invoiceId,
    required String auditReason,
  });
}
