// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categorie_depense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategorieDepenseAdapter extends TypeAdapter<CategorieDepense> {
  @override
  final int typeId = 8;

  @override
  CategorieDepense read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CategorieDepense.loyer;
      case 1:
        return CategorieDepense.transport;
      case 2:
        return CategorieDepense.electricite;
      case 3:
        return CategorieDepense.reapprovisionnement;
      case 4:
        return CategorieDepense.autre;
      default:
        return CategorieDepense.autre;
    }
  }

  @override
  void write(BinaryWriter writer, CategorieDepense obj) {
    switch (obj) {
      case CategorieDepense.loyer:
        writer.writeByte(0);
        break;
      case CategorieDepense.transport:
        writer.writeByte(1);
        break;
      case CategorieDepense.electricite:
        writer.writeByte(2);
        break;
      case CategorieDepense.reapprovisionnement:
        writer.writeByte(3);
        break;
      case CategorieDepense.autre:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategorieDepenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
