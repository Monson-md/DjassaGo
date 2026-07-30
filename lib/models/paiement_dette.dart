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

  /// Appareil ayant créé ce paiement (Phase 9, préparation — voir
  /// lib/services/device_id_service.dart). Un [PaiementDette] est immuable,
  /// ce champ n'est donc jamais réécrit après sa création.
  @HiveField(6, defaultValue: '')
  String deviceId;

  @HiveField(7)
  DateTime? lastModified;

  PaiementDette({
    required this.id,
    required this.detteId,
    required this.montant,
    required this.date,
    required this.devise,
    int? montantMineur,
    this.deviceId = '',
    this.lastModified,
  }) : montantMineur = montantMineur ??
            versUnitesMineures(montant, decimalesPourCodeIso(devise));

  Map<String, dynamic> versJson() => {
        'id': id,
        'detteId': detteId,
        'montant': montant,
        'date': date.toIso8601String(),
        'devise': devise,
        'montantMineur': montantMineur,
        'deviceId': deviceId,
        'lastModified': lastModified?.toIso8601String(),
      };

  factory PaiementDette.depuisJson(Map<String, dynamic> json) => PaiementDette(
        id: json['id'] as String,
        detteId: json['detteId'] as String,
        montant: (json['montant'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        devise: json['devise'] as String,
        montantMineur: json['montantMineur'] as int?,
        deviceId: json['deviceId'] as String? ?? '',
        lastModified: json['lastModified'] == null
            ? null
            : DateTime.parse(json['lastModified'] as String),
      );
}
