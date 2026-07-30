// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paiement_dette.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaiementDetteAdapter extends TypeAdapter<PaiementDette> {
  @override
  final int typeId = 7;

  @override
  PaiementDette read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaiementDette(
      id: fields[0] as String,
      detteId: fields[1] as String,
      montant: fields[2] as double,
      date: fields[3] as DateTime,
      devise: fields[4] as String,
      montantMineur: fields[5] == null ? 0 : fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, PaiementDette obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.detteId)
      ..writeByte(2)
      ..write(obj.montant)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.devise)
      ..writeByte(5)
      ..write(obj.montantMineur);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaiementDetteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
