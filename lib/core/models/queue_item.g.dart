// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueueItem _$QueueItemFromJson(Map<String, dynamic> json) => QueueItem(
  id: json['id'] as String,
  type: json['type'] as String,
  data: json['data'] as Map<String, dynamic>,
  timestamp: DateTime.parse(json['timestamp'] as String),
  processed: json['processed'] as bool? ?? false,
  retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
  error: json['error'] as String?,
);

Map<String, dynamic> _$QueueItemToJson(QueueItem instance) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'data': instance.data,
  'timestamp': instance.timestamp.toIso8601String(),
  'processed': instance.processed,
  'retryCount': instance.retryCount,
  'error': instance.error,
};
