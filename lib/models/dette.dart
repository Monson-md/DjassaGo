import 'package:hive/hive.dart';

part 'dette.g.dart';

@HiveType(typeId: 4)
enum StatutDette {
  @HiveField(0)
  enCours,
  @HiveField(1)
  payee,
  @HiveField(2)
  partiellementPayee,
}

@HiveType(typeId: 5)
class Dette extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nomClient;

  @HiveField(2)
  String telephone;

  @HiveField(3)
  double montantDu;

  @HiveField(4)
  DateTime dateDette;

  @HiveField(5)
  StatutDette statut;

  @HiveField(6)
  String devise;

  @HiveField(7)
  double montantInitial;

  @HiveField(8)
  String? note;

  @HiveField(9)
  bool synchronise;

  Dette({
    required this.id,
    required this.nomClient,
    required this.telephone,
    required this.montantDu,
    required this.dateDette,
    this.statut = StatutDette.enCours,
    required this.devise,
    double? montantInitial,
    this.note,
    this.synchronise = false,
  }) : montantInitial = montantInitial ?? montantDu;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomClient': nomClient,
      'telephone': telephone,
      'montantDu': montantDu,
      'montantInitial': montantInitial,
      'dateDette': dateDette.toIso8601String(),
      'statut': statut.name,
      'devise': devise,
      'note': note,
    };
  }
}
