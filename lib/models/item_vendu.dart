import 'package:hive/hive.dart';

part 'item_vendu.g.dart';

@HiveType(typeId: 2)
class ItemVendu extends HiveObject {
  @HiveField(0)
  String produitId;

  @HiveField(1)
  String nomProduit;

  @HiveField(2)
  int quantite;

  @HiveField(3)
  double prixUnitaireVente;

  @HiveField(4)
  double prixUnitaireAchat;

  /// Prix unitaires en unités mineures de la devise (lib/utils/money.dart).
  /// ItemVendu ne connaît pas sa propre devise (elle est globale à la
  /// boutique) : ces champs sont renseignés par CaisseService au moment
  /// de la finalisation de la vente, pas dans ce constructeur. Valeur par
  /// défaut 0 pour les ventes historiques enregistrées avant ce champ.
  @HiveField(5, defaultValue: 0)
  int prixUnitaireVenteMineur;

  @HiveField(6, defaultValue: 0)
  int prixUnitaireAchatMineur;

  ItemVendu({
    required this.produitId,
    required this.nomProduit,
    required this.quantite,
    required this.prixUnitaireVente,
    required this.prixUnitaireAchat,
    this.prixUnitaireVenteMineur = 0,
    this.prixUnitaireAchatMineur = 0,
  });

  double get sousTotal => prixUnitaireVente * quantite;

  double get margeBrute => (prixUnitaireVente - prixUnitaireAchat) * quantite;

  int get sousTotalMineur => prixUnitaireVenteMineur * quantite;

  int get margeBruteMineur =>
      (prixUnitaireVenteMineur - prixUnitaireAchatMineur) * quantite;

  /// Sérialisation complète et sans perte pour l'export/import de
  /// sauvegarde (lib/services/backup_service.dart) — distincte de
  /// [Transaction.toMap] qui ne sert qu'à la synchronisation Firestore.
  Map<String, dynamic> versJson() => {
        'produitId': produitId,
        'nomProduit': nomProduit,
        'quantite': quantite,
        'prixUnitaireVente': prixUnitaireVente,
        'prixUnitaireAchat': prixUnitaireAchat,
        'prixUnitaireVenteMineur': prixUnitaireVenteMineur,
        'prixUnitaireAchatMineur': prixUnitaireAchatMineur,
      };

  factory ItemVendu.depuisJson(Map<String, dynamic> json) => ItemVendu(
        produitId: json['produitId'] as String,
        nomProduit: json['nomProduit'] as String,
        quantite: json['quantite'] as int,
        prixUnitaireVente: (json['prixUnitaireVente'] as num).toDouble(),
        prixUnitaireAchat: (json['prixUnitaireAchat'] as num).toDouble(),
        prixUnitaireVenteMineur: json['prixUnitaireVenteMineur'] as int? ?? 0,
        prixUnitaireAchatMineur: json['prixUnitaireAchatMineur'] as int? ?? 0,
      );
}
