import 'package:hive/hive.dart';

import '../utils/devises_disponibles.dart';
import '../utils/money.dart';

part 'produit.g.dart';

@HiveType(typeId: 1)
class Produit extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nom;

  @HiveField(2)
  double prixAchat;

  @HiveField(3)
  double prixVente;

  @HiveField(4)
  int stockActuel;

  @HiveField(5)
  String devise;

  @HiveField(6)
  DateTime dateCreation;

  @HiveField(7)
  DateTime? dateModification;

  @HiveField(8)
  bool synchronise;

  /// Prix d'achat en unités mineures de la devise (voir lib/utils/money.dart).
  /// Source de vérité pour tout nouveau calcul : évite les erreurs
  /// d'arrondi flottant accumulées sur [prixAchat]. Les enregistrements
  /// créés avant l'introduction de ce champ ont une valeur par défaut de
  /// 0 ; [prixAchat] reste donc conservé et ne doit jamais être supprimé.
  @HiveField(9, defaultValue: 0)
  int prixAchatMineur;

  @HiveField(10, defaultValue: 0)
  int prixVenteMineur;

  /// Appareil ayant écrit la dernière version connue de cet enregistrement
  /// (Phase 9, préparation — voir lib/services/device_id_service.dart).
  /// Chaîne vide pour tout enregistrement créé avant l'introduction de ce
  /// champ ou en l'absence de synchronisation.
  @HiveField(11, defaultValue: '')
  String deviceId;

  /// Horodatage de la dernière modification, utilisé pour la résolution
  /// « dernier écrit gagne » (voir lib/services/sync_conflict_resolver.dart).
  /// `null` tant qu'aucune synchronisation n'a jamais touché cet
  /// enregistrement.
  @HiveField(12)
  DateTime? lastModified;

  /// Nom de la plus petite unité vendable du produit (« bouteille »,
  /// « sachet », « pièce », « kg »...) : [stockActuel] et [prixAchat]
  /// (coût d'une unité de base, pas d'un conditionnement) s'expriment
  /// toujours dans cette unité. Les façons de vendre le produit — à
  /// l'unité, au casier, au carton — sont des [Conditionnement] séparés,
  /// chacun un multiple de cette unité de base (voir
  /// lib/models/conditionnement.dart). Valeur par défaut « unité » pour les
  /// produits créés avant l'introduction des conditionnements.
  @HiveField(13, defaultValue: 'unité')
  String uniteBase;

  Produit({
    required this.id,
    required this.nom,
    required this.prixAchat,
    required this.prixVente,
    required this.stockActuel,
    required this.devise,
    DateTime? dateCreation,
    this.dateModification,
    this.synchronise = false,
    int? prixAchatMineur,
    int? prixVenteMineur,
    this.deviceId = '',
    this.lastModified,
    this.uniteBase = 'unité',
  })  : dateCreation = dateCreation ?? DateTime.now(),
        prixAchatMineur = prixAchatMineur ??
            versUnitesMineures(prixAchat, decimalesPourCodeIso(devise)),
        prixVenteMineur = prixVenteMineur ??
            versUnitesMineures(prixVente, decimalesPourCodeIso(devise));

  /// Met à jour les prix d'achat et de vente en gardant les champs en
  /// unités mineures synchronisés. À utiliser à la place d'une affectation
  /// directe de [prixAchat]/[prixVente].
  void definirPrix({required double prixAchat, required double prixVente}) {
    this.prixAchat = prixAchat;
    this.prixVente = prixVente;
    final decimales = decimalesPourCodeIso(devise);
    prixAchatMineur = versUnitesMineures(prixAchat, decimales);
    prixVenteMineur = versUnitesMineures(prixVente, decimales);
    lastModified = DateTime.now();
  }

  double get margeUnitaire => prixVente - prixAchat;

  bool get stockFaible => stockActuel <= 5;

  bool get enRupture => stockActuel <= 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prixAchat': prixAchat,
      'prixVente': prixVente,
      'stockActuel': stockActuel,
      'devise': devise,
      'dateCreation': dateCreation.toIso8601String(),
      'dateModification': dateModification?.toIso8601String(),
    };
  }

  /// Sérialisation complète et sans perte pour l'export/import de
  /// sauvegarde (lib/services/backup_service.dart) — distincte de
  /// [toMap] qui ne sert qu'à la synchronisation Firestore.
  Map<String, dynamic> versJson() => {
        'id': id,
        'nom': nom,
        'prixAchat': prixAchat,
        'prixVente': prixVente,
        'stockActuel': stockActuel,
        'devise': devise,
        'dateCreation': dateCreation.toIso8601String(),
        'dateModification': dateModification?.toIso8601String(),
        'synchronise': synchronise,
        'prixAchatMineur': prixAchatMineur,
        'prixVenteMineur': prixVenteMineur,
        'deviceId': deviceId,
        'lastModified': lastModified?.toIso8601String(),
        'uniteBase': uniteBase,
      };

  factory Produit.depuisJson(Map<String, dynamic> json) => Produit(
        id: json['id'] as String,
        nom: json['nom'] as String,
        prixAchat: (json['prixAchat'] as num).toDouble(),
        prixVente: (json['prixVente'] as num).toDouble(),
        stockActuel: json['stockActuel'] as int,
        devise: json['devise'] as String,
        dateCreation: DateTime.parse(json['dateCreation'] as String),
        dateModification: json['dateModification'] == null
            ? null
            : DateTime.parse(json['dateModification'] as String),
        synchronise: json['synchronise'] as bool? ?? false,
        prixAchatMineur: json['prixAchatMineur'] as int?,
        prixVenteMineur: json['prixVenteMineur'] as int?,
        deviceId: json['deviceId'] as String? ?? '',
        lastModified: json['lastModified'] == null
            ? null
            : DateTime.parse(json['lastModified'] as String),
        uniteBase: json['uniteBase'] as String? ?? 'unité',
      );
}
