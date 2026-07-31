// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conditionnement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConditionnementAdapter extends TypeAdapter<Conditionnement> {
  @override
  final int typeId = 11;

  @override
  Conditionnement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Conditionnement(
      id: fields[0] as String,
      produitId: fields[1] as String,
      nom: fields[2] as String,
      quantiteEnUniteBase: fields[3] as int,
      prixVente: fields[4] as double,
      parDefaut: fields[5] as bool,
      devise: fields[6] as String,
      prixVenteMineur: fields[7] == null ? 0 : fields[7] as int?,
      deviceId: fields[8] == null ? '' : fields[8] as String,
      lastModified: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Conditionnement obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.produitId)
      ..writeByte(2)
      ..write(obj.nom)
      ..writeByte(3)
      ..write(obj.quantiteEnUniteBase)
      ..writeByte(4)
      ..write(obj.prixVente)
      ..writeByte(5)
      ..write(obj.parDefaut)
      ..writeByte(6)
      ..write(obj.devise)
      ..writeByte(7)
      ..write(obj.prixVenteMineur)
      ..writeByte(8)
      ..write(obj.deviceId)
      ..writeByte(9)
      ..write(obj.lastModified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConditionnementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
