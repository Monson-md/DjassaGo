// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'depense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DepenseAdapter extends TypeAdapter<Depense> {
  @override
  final int typeId = 9;

  @override
  Depense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Depense(
      id: fields[0] as String,
      libelle: fields[1] as String,
      montant: fields[2] as double,
      date: fields[3] as DateTime,
      categorie: fields[4] as CategorieDepense,
      devise: fields[5] as String,
      montantMineur: fields[6] == null ? 0 : fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Depense obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.libelle)
      ..writeByte(2)
      ..write(obj.montant)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.categorie)
      ..writeByte(5)
      ..write(obj.devise)
      ..writeByte(6)
      ..write(obj.montantMineur);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
