/// Queue Item Model
///
/// PURPOSE:
/// Represents an operation queued for offline execution and synchronization.
/// Used by QueueService to persist pending operations when device is offline.
///
/// ARCHITECTURE:
/// - Uses Hive for efficient local storage and type-safe serialization
/// - Includes error tracking for failed sync attempts
/// - Supports both JSON and Hive serialization
///
/// FIELDS:
/// - id: Unique identifier for the queue item (UUID)
/// - type: Operation type (e.g., 'clockIn', 'clockOut', 'createInvoice')
/// - data: Operation-specific payload as JSON
/// - timestamp: Timestamp when item was queued (alias for createdAt)
/// - processed: Whether item has been successfully synced
/// - retryCount: Number of failed sync attempts
/// - error: Error message from last failed sync attempt (if any)
library;

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'queue_item.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class QueueItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String type;

  @HiveField(2)
  Map<String, dynamic> data;

  @HiveField(3)
  DateTime timestamp;

  @HiveField(4)
  bool processed;

  @HiveField(5)
  int retryCount;

  @HiveField(6)
  String? error;

  QueueItem({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.processed = false,
    this.retryCount = 0,
    this.error,
  });

  /// Legacy getter for backwards compatibility
  DateTime get createdAt => timestamp;

  Map<String, dynamic> toJson() => _$QueueItemToJson(this);

  factory QueueItem.fromJson(Map<String, dynamic> json) =>
      _$QueueItemFromJson(json);
}
