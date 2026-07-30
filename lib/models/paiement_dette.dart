import 'package:hive/hive.dart';

import '../utils/devises_disponibles.dart';
import '../utils/money.dart';

part 'paiement_dette.g.dart';

/// Historique d'un paiement partiel ou total effectué contre une [Dette]
/// (via DetteService.enregistrerPaiement). Contrairement à `Dette.montantDu`
/// qui ne garde que le solde courant, chaque enregistrement ici trace un
/// encaissement daté et immuable — nécessaire pour distinguer le chiffre
/// d'affaires (reconnu à la vente) des encaissements réels du jour.
@HiveType(typeId: 7)
class PaiementDette extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String detteId;

  @HiveField(2)
  double montant;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String devise;

  @HiveField(5, defaultValue: 0)
  int montantMineur;

  PaiementDette({
    required this.id,
    required this.detteId,
    required this.montant,
    required this.date,
    required this.devise,
    int? montantMineur,
  }) : montantMineur = montantMineur ??
            versUnitesMineures(montant, decimalesPourCodeIso(devise));

  Map<String, dynamic> versJson() => {
        'id': id,
        'detteId': detteId,
        'montant': montant,
        'date': date.toIso8601String(),
        'devise': devise,
        'montantMineur': montantMineur,
      };

  factory PaiementDette.depuisJson(Map<String, dynamic> json) => PaiementDette(
        id: json['id'] as String,
        detteId: json['detteId'] as String,
        montant: (json['montant'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        devise: json['devise'] as String,
        montantMineur: json['montantMineur'] as int?,
      );
}
