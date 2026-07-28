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
      );
}
