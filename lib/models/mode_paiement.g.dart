// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mode_paiement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ModePaiementAdapter extends TypeAdapter<ModePaiement> {
  @override
  final int typeId = 6;

  @override
  ModePaiement read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ModePaiement.especes;
      case 1:
        return ModePaiement.credit;
      case 2:
        return ModePaiement.mobileMoney;
      default:
        return ModePaiement.especes;
    }
  }

  @override
  void write(BinaryWriter writer, ModePaiement obj) {
    switch (obj) {
      case ModePaiement.especes:
        writer.writeByte(0);
        break;
      case ModePaiement.credit:
        writer.writeByte(1);
        break;
      case ModePaiement.mobileMoney:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModePaiementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
