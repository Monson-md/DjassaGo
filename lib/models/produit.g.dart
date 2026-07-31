// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'produit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProduitAdapter extends TypeAdapter<Produit> {
  @override
  final int typeId = 1;

  @override
  Produit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Produit(
      id: fields[0] as String,
      nom: fields[1] as String,
      prixAchat: fields[2] as double,
      prixVente: fields[3] as double,
      stockActuel: fields[4] as int,
      devise: fields[5] as String,
      dateCreation: fields[6] as DateTime?,
      dateModification: fields[7] as DateTime?,
      synchronise: fields[8] as bool,
      prixAchatMineur: fields[9] == null ? 0 : fields[9] as int?,
      prixVenteMineur: fields[10] == null ? 0 : fields[10] as int?,
      deviceId: fields[11] == null ? '' : fields[11] as String,
      lastModified: fields[12] as DateTime?,
      uniteBase: fields[13] == null ? 'unité' : fields[13] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Produit obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nom)
      ..writeByte(2)
      ..write(obj.prixAchat)
      ..writeByte(3)
      ..write(obj.prixVente)
      ..writeByte(4)
      ..write(obj.stockActuel)
      ..writeByte(5)
      ..write(obj.devise)
      ..writeByte(6)
      ..write(obj.dateCreation)
      ..writeByte(7)
      ..write(obj.dateModification)
      ..writeByte(8)
      ..write(obj.synchronise)
      ..writeByte(9)
      ..write(obj.prixAchatMineur)
      ..writeByte(10)
      ..write(obj.prixVenteMineur)
      ..writeByte(11)
      ..write(obj.deviceId)
      ..writeByte(12)
      ..write(obj.lastModified)
      ..writeByte(13)
      ..write(obj.uniteBase);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProduitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
