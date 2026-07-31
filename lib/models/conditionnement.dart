import 'package:hive/hive.dart';

import '../utils/devises_disponibles.dart';
import '../utils/money.dart';

part 'conditionnement.g.dart';

/// Une façon de vendre un [Produit] : « Bouteille », « Casier », « Carton »...
/// [quantiteEnUniteBase] exprime ce conditionnement en unité de base du
/// produit (ex: 20 pour un casier de 20 bouteilles) — c'est ce multiplicateur
/// qui relie le stock (toujours compté en unité de base) au prix de vente
/// affiché sur l'écran Caisse. Un produit possède toujours au moins un
/// conditionnement ; un produit « simple » en a exactement un, de quantité 1.
///
/// Ce modèle n'est jamais lu directement pour calculer une marge ou décrémenter
/// un stock après coup : au moment de la vente, [nom] et [quantiteEnUniteBase]
/// sont figés dans l'ItemVendu correspondant (voir CaisseProvider.ajouterAuPanier),
/// afin qu'une modification ultérieure de ce Conditionnement (ex: le casier
/// passe de 20 à 24 bouteilles) ne change jamais l'historique déjà enregistré.
@HiveType(typeId: 11)
class Conditionnement extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String produitId;

  @HiveField(2)
  String nom;

  @HiveField(3)
  int quantiteEnUniteBase;

  @HiveField(4)
  double prixVente;

  /// Le conditionnement proposé en premier sur l'écran Caisse (une touche
  /// l'ajoute directement). Un seul conditionnement par produit doit porter
  /// `true` ; ce n'est pas imposé au niveau du stockage, seulement par
  /// ConditionnementService.
  @HiveField(5)
  bool parDefaut;

  @HiveField(6)
  String devise;

  /// Prix de vente en unités mineures de la devise (lib/utils/money.dart).
  @HiveField(7, defaultValue: 0)
  int prixVenteMineur;

  /// Appareil ayant écrit la dernière version connue de ce conditionnement
  /// (préparation Phase 9 — voir lib/services/device_id_service.dart).
  @HiveField(8, defaultValue: '')
  String deviceId;

  @HiveField(9)
  DateTime? lastModified;

  Conditionnement({
    required this.id,
    required this.produitId,
    required this.nom,
    required this.quantiteEnUniteBase,
    required this.prixVente,
    this.parDefaut = false,
    required this.devise,
    int? prixVenteMineur,
    this.deviceId = '',
    this.lastModified,
  }) : prixVenteMineur = prixVenteMineur ??
            versUnitesMineures(prixVente, decimalesPourCodeIso(devise));

  Map<String, dynamic> versJson() => {
        'id': id,
        'produitId': produitId,
        'nom': nom,
        'quantiteEnUniteBase': quantiteEnUniteBase,
        'prixVente': prixVente,
        'parDefaut': parDefaut,
        'devise': devise,
        'prixVenteMineur': prixVenteMineur,
        'deviceId': deviceId,
        'lastModified': lastModified?.toIso8601String(),
      };

  factory Conditionnement.depuisJson(Map<String, dynamic> json) =>
      Conditionnement(
        id: json['id'] as String,
        produitId: json['produitId'] as String,
        nom: json['nom'] as String,
        quantiteEnUniteBase: json['quantiteEnUniteBase'] as int,
        prixVente: (json['prixVente'] as num).toDouble(),
        parDefaut: json['parDefaut'] as bool? ?? false,
        devise: json['devise'] as String,
        prixVenteMineur: json['prixVenteMineur'] as int?,
        deviceId: json['deviceId'] as String? ?? '',
        lastModified: json['lastModified'] == null
            ? null
            : DateTime.parse(json['lastModified'] as String),
      );
}
