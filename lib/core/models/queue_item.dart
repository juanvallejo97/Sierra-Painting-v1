import 'package:hive/hive.dart';

part 'queue_item.g.dart';

@HiveType(typeId: 0)
class QueueItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String type;

  @HiveField(2)
  Map<String, dynamic> data;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  bool processed;

  @HiveField(5)
  String? error;

  QueueItem({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.processed = false,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'processed': processed,
      'error': error,
    };
  }

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String,
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      processed: json['processed'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}
