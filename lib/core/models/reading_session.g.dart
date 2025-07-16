// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReadingSessionAdapter extends TypeAdapter<ReadingSession> {
  @override
  final int typeId = 1;

  @override
  ReadingSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingSession(
      page: fields[0] as int,
      openedAt: fields[1] as DateTime,
      closedAt: fields[2] as DateTime,
      previousPage: fields[3] as int?,
      date: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingSession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.page)
      ..writeByte(1)
      ..write(obj.openedAt)
      ..writeByte(2)
      ..write(obj.closedAt)
      ..writeByte(3)
      ..write(obj.previousPage)
      ..writeByte(4)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
