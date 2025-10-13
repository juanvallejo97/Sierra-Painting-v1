// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingClockOpAdapter extends TypeAdapter<PendingClockOp> {
  @override
  final int typeId = 1;

  @override
  PendingClockOp read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingClockOp(
      op: fields[0] as String,
      jobId: fields[1] as String?,
      lat: fields[2] as double,
      lng: fields[3] as double,
      accuracy: fields[4] as double?,
      clientEventId: fields[5] as String,
      createdAt: fields[6] as DateTime,
      userId: fields[7] as String,
      retryCount: fields[8] as int,
      lastAttemptAt: fields[9] as DateTime?,
      lastError: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingClockOp obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.op)
      ..writeByte(1)
      ..write(obj.jobId)
      ..writeByte(2)
      ..write(obj.lat)
      ..writeByte(3)
      ..write(obj.lng)
      ..writeByte(4)
      ..write(obj.accuracy)
      ..writeByte(5)
      ..write(obj.clientEventId)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.retryCount)
      ..writeByte(9)
      ..write(obj.lastAttemptAt)
      ..writeByte(10)
      ..write(obj.lastError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingClockOpAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
