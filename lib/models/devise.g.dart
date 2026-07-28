// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devise.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviseAdapter extends TypeAdapter<Devise> {
  @override
  final int typeId = 0;

  @override
  Devise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Devise(
      id: fields[0] as String,
      symbole: fields[1] as String,
      nom: fields[2] as String,
      codeIso: fields[3] as String,
      codePays: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Devise obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.symbole)
      ..writeByte(2)
      ..write(obj.nom)
      ..writeByte(3)
      ..write(obj.codeIso)
      ..writeByte(4)
      ..write(obj.codePays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
