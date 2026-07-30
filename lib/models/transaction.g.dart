// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 3;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      itemsVendus: (fields[2] as List).cast<ItemVendu>(),
      montantTotal: fields[3] as double,
      margeBrute: fields[4] as double,
      devise: fields[5] as String,
      synchronise: fields[6] as bool,
      montantTotalMineur: fields[7] == null ? 0 : fields[7] as int?,
      margeBruteMineur: fields[8] == null ? 0 : fields[8] as int?,
      modePaiement:
          fields[9] == null ? ModePaiement.especes : fields[9] as ModePaiement,
      annulee: fields[10] == null ? false : fields[10] as bool,
      dateAnnulation: fields[11] as DateTime?,
      motifAnnulation: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.itemsVendus)
      ..writeByte(3)
      ..write(obj.montantTotal)
      ..writeByte(4)
      ..write(obj.margeBrute)
      ..writeByte(5)
      ..write(obj.devise)
      ..writeByte(6)
      ..write(obj.synchronise)
      ..writeByte(7)
      ..write(obj.montantTotalMineur)
      ..writeByte(8)
      ..write(obj.margeBruteMineur)
      ..writeByte(9)
      ..write(obj.modePaiement)
      ..writeByte(10)
      ..write(obj.annulee)
      ..writeByte(11)
      ..write(obj.dateAnnulation)
      ..writeByte(12)
      ..write(obj.motifAnnulation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
