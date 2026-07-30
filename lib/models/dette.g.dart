// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dette.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DetteAdapter extends TypeAdapter<Dette> {
  @override
  final int typeId = 5;

  @override
  Dette read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dette(
      id: fields[0] as String,
      nomClient: fields[1] as String,
      telephone: fields[2] as String,
      montantDu: fields[3] as double,
      dateDette: fields[4] as DateTime,
      statut: fields[5] as StatutDette,
      devise: fields[6] as String,
      montantInitial: fields[7] as double?,
      note: fields[8] as String?,
      synchronise: fields[9] as bool,
      montantDuMineur: fields[10] == null ? 0 : fields[10] as int?,
      montantInitialMineur: fields[11] == null ? 0 : fields[11] as int?,
      transactionId: fields[12] as String?,
      deviceId: fields[13] == null ? '' : fields[13] as String,
      lastModified: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Dette obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nomClient)
      ..writeByte(2)
      ..write(obj.telephone)
      ..writeByte(3)
      ..write(obj.montantDu)
      ..writeByte(4)
      ..write(obj.dateDette)
      ..writeByte(5)
      ..write(obj.statut)
      ..writeByte(6)
      ..write(obj.devise)
      ..writeByte(7)
      ..write(obj.montantInitial)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.synchronise)
      ..writeByte(10)
      ..write(obj.montantDuMineur)
      ..writeByte(11)
      ..write(obj.montantInitialMineur)
      ..writeByte(12)
      ..write(obj.transactionId)
      ..writeByte(13)
      ..write(obj.deviceId)
      ..writeByte(14)
      ..write(obj.lastModified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StatutDetteAdapter extends TypeAdapter<StatutDette> {
  @override
  final int typeId = 4;

  @override
  StatutDette read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StatutDette.enCours;
      case 1:
        return StatutDette.payee;
      case 2:
        return StatutDette.partiellementPayee;
      default:
        return StatutDette.enCours;
    }
  }

  @override
  void write(BinaryWriter writer, StatutDette obj) {
    switch (obj) {
      case StatutDette.enCours:
        writer.writeByte(0);
        break;
      case StatutDette.payee:
        writer.writeByte(1);
        break;
      case StatutDette.partiellementPayee:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatutDetteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
