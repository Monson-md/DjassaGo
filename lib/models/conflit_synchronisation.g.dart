// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conflit_synchronisation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConflitSynchronisationAdapter
    extends TypeAdapter<ConflitSynchronisation> {
  @override
  final int typeId = 10;

  @override
  ConflitSynchronisation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConflitSynchronisation(
      id: fields[0] as String,
      entiteType: fields[1] as String,
      entiteId: fields[2] as String,
      dateConflit: fields[3] as DateTime,
      resolutionRetenue: fields[4] as String,
      resumeLocal: fields[5] as String?,
      resumeDistant: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ConflitSynchronisation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.entiteType)
      ..writeByte(2)
      ..write(obj.entiteId)
      ..writeByte(3)
      ..write(obj.dateConflit)
      ..writeByte(4)
      ..write(obj.resolutionRetenue)
      ..writeByte(5)
      ..write(obj.resumeLocal)
      ..writeByte(6)
      ..write(obj.resumeDistant);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflitSynchronisationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
