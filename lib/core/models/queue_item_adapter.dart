import 'package:hive/hive.dart';
import 'package:sierra_painting/core/models/queue_item.dart';

/// Manual Hive TypeAdapter for QueueItem to avoid requiring code generation.
class QueueItemAdapter extends TypeAdapter<QueueItem> {
  @override
  final int typeId = 0;

  @override
  QueueItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return QueueItem(
      id: fields[0] as String,
      type: fields[1] as String,
      data: Map<String, dynamic>.from(fields[2] as Map),
      timestamp: fields[3] as DateTime,
      processed: fields[4] as bool? ?? false,
      retryCount: fields[5] as int? ?? 0,
      error: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, QueueItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.data)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.processed)
      ..writeByte(5)
      ..write(obj.retryCount)
      ..writeByte(6)
      ..write(obj.error);
  }
}
