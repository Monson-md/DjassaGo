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
      beneficeNet: fields[4] as double,
      devise: fields[5] as String,
      synchronise: fields[6] as bool,
      montantTotalMineur: fields[7] == null ? 0 : fields[7] as int?,
      beneficeNetMineur: fields[8] == null ? 0 : fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.itemsVendus)
      ..writeByte(3)
      ..write(obj.montantTotal)
      ..writeByte(4)
      ..write(obj.beneficeNet)
      ..writeByte(5)
      ..write(obj.devise)
      ..writeByte(6)
      ..write(obj.synchronise)
      ..writeByte(7)
      ..write(obj.montantTotalMineur)
      ..writeByte(8)
      ..write(obj.beneficeNetMineur);
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
