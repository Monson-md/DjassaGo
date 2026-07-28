// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_vendu.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemVenduAdapter extends TypeAdapter<ItemVendu> {
  @override
  final int typeId = 2;

  @override
  ItemVendu read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemVendu(
      produitId: fields[0] as String,
      nomProduit: fields[1] as String,
      quantite: fields[2] as int,
      prixUnitaireVente: fields[3] as double,
      prixUnitaireAchat: fields[4] as double,
      prixUnitaireVenteMineur: fields[5] == null ? 0 : fields[5] as int,
      prixUnitaireAchatMineur: fields[6] == null ? 0 : fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ItemVendu obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.produitId)
      ..writeByte(1)
      ..write(obj.nomProduit)
      ..writeByte(2)
      ..write(obj.quantite)
      ..writeByte(3)
      ..write(obj.prixUnitaireVente)
      ..writeByte(4)
      ..write(obj.prixUnitaireAchat)
      ..writeByte(5)
      ..write(obj.prixUnitaireVenteMineur)
      ..writeByte(6)
      ..write(obj.prixUnitaireAchatMineur);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemVenduAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
