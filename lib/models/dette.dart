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

  /// Id de la [Transaction] à l'origine de cette dette, si elle provient
  /// d'une vente à crédit (bouton « Mettre en dette » du panier). `null`
  /// pour une dette saisie manuellement depuis le carnet.
  @HiveField(12)
  String? transactionId;

  /// Appareil ayant écrit la dernière version connue de cette dette (Phase
  /// 9, préparation — voir lib/services/device_id_service.dart).
  @HiveField(13, defaultValue: '')
  String deviceId;

  /// Horodatage de la dernière modification, utilisé pour la résolution
  /// « dernier écrit gagne » (voir lib/services/sync_conflict_resolver.dart).
  @HiveField(14)
  DateTime? lastModified;

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
    this.transactionId,
    this.deviceId = '',
    this.lastModified,
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
    lastModified = DateTime.now();
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

  /// Sérialisation complète et sans perte pour l'export/import de
  /// sauvegarde (lib/services/backup_service.dart) — distincte de
  /// [toMap] qui ne sert qu'à la synchronisation Firestore.
  Map<String, dynamic> versJson() => {
        'id': id,
        'nomClient': nomClient,
        'telephone': telephone,
        'montantDu': montantDu,
        'dateDette': dateDette.toIso8601String(),
        'statut': statut.name,
        'devise': devise,
        'montantInitial': montantInitial,
        'note': note,
        'synchronise': synchronise,
        'montantDuMineur': montantDuMineur,
        'montantInitialMineur': montantInitialMineur,
        'transactionId': transactionId,
        'deviceId': deviceId,
        'lastModified': lastModified?.toIso8601String(),
      };

  factory Dette.depuisJson(Map<String, dynamic> json) => Dette(
        id: json['id'] as String,
        nomClient: json['nomClient'] as String,
        telephone: json['telephone'] as String,
        montantDu: (json['montantDu'] as num).toDouble(),
        dateDette: DateTime.parse(json['dateDette'] as String),
        statut: StatutDette.values.byName(json['statut'] as String),
        devise: json['devise'] as String,
        montantInitial: (json['montantInitial'] as num?)?.toDouble(),
        note: json['note'] as String?,
        synchronise: json['synchronise'] as bool? ?? false,
        montantDuMineur: json['montantDuMineur'] as int?,
        montantInitialMineur: json['montantInitialMineur'] as int?,
        transactionId: json['transactionId'] as String?,
        deviceId: json['deviceId'] as String? ?? '',
        lastModified: json['lastModified'] == null
            ? null
            : DateTime.parse(json['lastModified'] as String),
      );
}
