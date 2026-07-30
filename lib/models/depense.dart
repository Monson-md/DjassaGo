import 'package:hive/hive.dart';

import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import 'categorie_depense.dart';

part 'depense.g.dart';

/// Une charge du commerce (loyer, transport, électricité,
/// réapprovisionnement, autre) — distincte du prix d'achat des produits
/// vendus, déjà pris en compte dans la marge brute (voir
/// CaisseService.margeBruteDuJour). Sert au calcul du résultat net :
/// marge brute - dépenses (Phase 7 de docs/PHASES.md).
@HiveType(typeId: 9)
class Depense extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String libelle;

  @HiveField(2)
  double montant;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  CategorieDepense categorie;

  @HiveField(5)
  String devise;

  /// Montant en unités mineures de la devise (lib/utils/money.dart).
  @HiveField(6, defaultValue: 0)
  int montantMineur;

  Depense({
    required this.id,
    required this.libelle,
    required this.montant,
    required this.date,
    required this.categorie,
    required this.devise,
    int? montantMineur,
  }) : montantMineur = montantMineur ??
            versUnitesMineures(montant, decimalesPourCodeIso(devise));

  Map<String, dynamic> versJson() => {
        'id': id,
        'libelle': libelle,
        'montant': montant,
        'date': date.toIso8601String(),
        'categorie': categorie.name,
        'devise': devise,
        'montantMineur': montantMineur,
      };

  factory Depense.depuisJson(Map<String, dynamic> json) => Depense(
        id: json['id'] as String,
        libelle: json['libelle'] as String,
        montant: (json['montant'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        categorie: CategorieDepense.values.byName(json['categorie'] as String),
        devise: json['devise'] as String,
        montantMineur: json['montantMineur'] as int?,
      );
}
