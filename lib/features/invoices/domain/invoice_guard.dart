/// Invoice Immutability Guards
///
/// PURPOSE:
/// - Enforce invoice immutability after sending
/// - Require revisions for changes to sent invoices
/// - Audit trail for all modifications
/// - Void invoices with mandatory reason

library invoice_guard;

// ============================================================================
// INVOICE STATUS
// ============================================================================

class InvoiceStatus {
  InvoiceStatus._();

  // Mutable statuses
  static const String draft = 'draft';

  // Immutable statuses (require revision)
  static const String sent = 'sent';
  static const String paid = 'paid';
  static const String payPaidCash = 'paid_cash';
  static const String overdue = 'overdue';

  // Terminal statuses
  static const String voided = 'voided';
  static const String cancelled = 'cancelled';

  /// Check if status is mutable
  static bool isMutable(String status) {
    return status == draft;
  }

  /// Check if status is immutable (requires revision)
  static bool isImmutable(String status) {
    return [sent, paid, payPaidCash, overdue].contains(status);
  }

  /// Check if status is terminal (cannot be changed at all)
  static bool isTerminal(String status) {
    return [voided, cancelled].contains(status);
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class ImmutableInvoiceException implements Exception {
  final String message;
  final String currentStatus;

  const ImmutableInvoiceException(this.message, this.currentStatus);

  @override
  String toString() => 'ImmutableInvoiceException: $message (status: $currentStatus)';
}

class TerminalInvoiceException implements Exception {
  final String message;
  final String currentStatus;

  const TerminalInvoiceException(this.message, this.currentStatus);

  @override
  String toString() => 'TerminalInvoiceException: $message (status: $currentStatus)';
}

// ============================================================================
// AUDIT TRAIL ENTRY
// ============================================================================

class InvoiceAuditEntry {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String action;
  final String? reason;
  final Map<String, dynamic>? changes;

  const InvoiceAuditEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.action,
    this.reason,
    this.changes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'action': action,
      if (reason != null) 'reason': reason,
      if (changes != null) 'changes': changes,
    };
  }
}

// ============================================================================
// MAIN INVOICE GUARD
// ============================================================================

class InvoiceGuard {
  InvoiceGuard._();

  /// Check if invoice can be modified
  /// Throws ImmutableInvoiceException if immutable
  /// Throws TerminalInvoiceException if terminal
  static void checkMutable(String status) {
    if (InvoiceStatus.isTerminal(status)) {
      throw TerminalInvoiceException(
        'Cannot modify $status invoice. This status is final.',
        status,
      );
    }

    if (InvoiceStatus.isImmutable(status)) {
      throw ImmutableInvoiceException(
        'Cannot modify $status invoice. Create a revision instead.',
        status,
      );
    }
  }

  /// Check if invoice can transition to new status
  static bool canTransitionTo(String currentStatus, String newStatus) {
    // Terminal statuses cannot transition
    if (InvoiceStatus.isTerminal(currentStatus)) {
      return false;
    }

    // Valid state transitions
    final validTransitions = {
      InvoiceStatus.draft: [InvoiceStatus.sent, InvoiceStatus.voided],
      InvoiceStatus.sent: [
        InvoiceStatus.paid,
        InvoiceStatus.payPaidCash,
        InvoiceStatus.overdue,
        InvoiceStatus.voided,
      ],
      InvoiceStatus.overdue: [
        InvoiceStatus.paid,
        InvoiceStatus.payPaidCash,
        InvoiceStatus.voided,
      ],
      InvoiceStatus.paid: [InvoiceStatus.voided],
      InvoiceStatus.payPaidCash: [InvoiceStatus.voided],
    };

    return validTransitions[currentStatus]?.contains(newStatus) ?? false;
  }

  /// Create revision of an immutable invoice
  /// Returns new invoice ID with revision suffix
  static String createRevision({
    required String originalId,
    required String currentStatus,
    required Map<String, dynamic> changes,
    required String userId,
  }) {
    // Check if invoice is actually immutable
    if (!InvoiceStatus.isImmutable(currentStatus)) {
      throw ArgumentError(
        'Cannot create revision of mutable invoice. Just modify it directly.',
      );
    }

    // Generate revision ID: original_id_rev_N
    final revisionNumber = _getNextRevisionNumber(originalId);
    final revisionId = '${originalId}_rev_$revisionNumber';

    // TODO(Phase 3): Store audit trail entry
    final auditEntry = InvoiceAuditEntry(
      id: revisionId,
      timestamp: DateTime.now(),
      userId: userId,
      action: 'revision_created',
      reason: 'Modified immutable invoice',
      changes: changes,
    );

    return revisionId;
  }

  /// Void an invoice with reason
  static InvoiceAuditEntry voidInvoice({
    required String invoiceId,
    required String currentStatus,
    required String userId,
    required String reason,
  }) {
    // Check if invoice can be voided
    if (!canTransitionTo(currentStatus, InvoiceStatus.voided)) {
      throw ArgumentError(
        'Invoice in $currentStatus status cannot be voided',
      );
    }

    // Require non-empty reason
    if (reason.trim().isEmpty) {
      throw ArgumentError('Void reason is required');
    }

    // Create audit entry
    return InvoiceAuditEntry(
      id: invoiceId,
      timestamp: DateTime.now(),
      userId: userId,
      action: 'voided',
      reason: reason,
    );
  }

  /// Get next revision number for an invoice
  static int _getNextRevisionNumber(String invoiceId) {
    // TODO(Phase 3): Query Firestore for existing revisions
    // For now, assume revision 1
    return 1;
  }

  /// Validate invoice number format
  /// Format: INV-YYYYMM-####
  static bool isValidInvoiceNumber(String number) {
    final pattern = RegExp(r'^INV-\d{6}-\d{4}$');
    return pattern.hasMatch(number);
  }

  /// Generate invoice number
  /// Format: INV-YYYYMM-####
  static String generateInvoiceNumber(DateTime date, int sequence) {
    final yearMonth = date.year.toString() + date.month.toString().padLeft(2, '0');
    final seqStr = sequence.toString().padLeft(4, '0');
    return 'INV-$yearMonth-$seqStr';
  }
}
