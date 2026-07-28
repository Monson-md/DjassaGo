import 'package:hive/hive.dart';

import '../utils/devises_disponibles.dart';
import '../utils/money.dart';

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

  /// Montants en unités mineures de la devise (lib/utils/money.dart).
  /// Valeur par défaut 0 pour les dettes enregistrées avant l'introduction
  /// de ce champ.
  @HiveField(10, defaultValue: 0)
  int montantDuMineur;

  @HiveField(11, defaultValue: 0)
  int montantInitialMineur;

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
    int? montantDuMineur,
    int? montantInitialMineur,
  })  : montantInitial = montantInitial ?? montantDu,
        montantDuMineur = montantDuMineur ??
            versUnitesMineures(montantDu, decimalesPourCodeIso(devise)),
        montantInitialMineur = montantInitialMineur ??
            versUnitesMineures(
                montantInitial ?? montantDu, decimalesPourCodeIso(devise));

  /// Met à jour le montant dû en gardant le champ en unités mineures
  /// synchronisé. À utiliser à la place d'une affectation directe de
  /// [montantDu].
  void definirMontantDu(double montant) {
    montantDu = montant;
    montantDuMineur = versUnitesMineures(montant, decimalesPourCodeIso(devise));
  }

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
