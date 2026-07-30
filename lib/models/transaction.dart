import 'package:hive/hive.dart';

import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import 'item_vendu.dart';
import 'mode_paiement.dart';

part 'transaction.g.dart';

@HiveType(typeId: 3)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  List<ItemVendu> itemsVendus;

  @HiveField(3)
  double montantTotal;

  @HiveField(4)
  double beneficeNet;

  @HiveField(5)
  String devise;

  @HiveField(6)
  bool synchronise;

  /// Montants en unités mineures de la devise (lib/utils/money.dart) :
  /// source de vérité pour tout nouveau calcul, sans erreur d'arrondi
  /// flottant. Valeur par défaut 0 pour les transactions enregistrées
  /// avant l'introduction de ce champ — elles restent consultables via
  /// [montantTotal]/[beneficeNet] mais sont exclues des agrégations en
  /// unités mineures tant qu'elles n'ont pas cette valeur figée.
  @HiveField(7, defaultValue: 0)
  int montantTotalMineur;

  @HiveField(8, defaultValue: 0)
  int beneficeNetMineur;

  /// Moyen de règlement de la vente. Valeur par défaut `especes` pour les
  /// transactions enregistrées avant l'introduction de ce champ — elles
  /// n'existaient qu'au comptant, aucune vente à crédit n'était possible.
  @HiveField(9, defaultValue: ModePaiement.especes)
  ModePaiement modePaiement;

  /// Vrai si la vente a été annulée (voir [marquerAnnulee]). Une
  /// transaction annulée n'est **jamais** supprimée physiquement : elle est
  /// exclue des statistiques (CaisseService.transactionsDuJour) mais reste
  /// consultable dans le journal des ventes.
  @HiveField(10, defaultValue: false)
  bool annulee;

  @HiveField(11)
  DateTime? dateAnnulation;

  @HiveField(12)
  String? motifAnnulation;

  Transaction({
    required this.id,
    required this.date,
    required this.itemsVendus,
    required this.montantTotal,
    required this.beneficeNet,
    required this.devise,
    this.synchronise = false,
    int? montantTotalMineur,
    int? beneficeNetMineur,
    this.modePaiement = ModePaiement.especes,
    this.annulee = false,
    this.dateAnnulation,
    this.motifAnnulation,
  })  : montantTotalMineur = montantTotalMineur ??
            versUnitesMineures(montantTotal, decimalesPourCodeIso(devise)),
        beneficeNetMineur = beneficeNetMineur ??
            versUnitesMineures(beneficeNet, decimalesPourCodeIso(devise));

  /// Marque la vente comme annulée. Le stock doit être remis par
  /// l'appelant (voir CaisseService.annulerTransaction) avant d'appeler
  /// cette méthode : elle ne fait que figer l'état de la transaction.
  void marquerAnnulee({required String motif, DateTime? date}) {
    annulee = true;
    dateAnnulation = date ?? DateTime.now();
    motifAnnulation = motif;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'montantTotal': montantTotal,
      'beneficeNet': beneficeNet,
      'devise': devise,
      'itemsVendus': itemsVendus
          .map((i) => {
                'produitId': i.produitId,
                'nomProduit': i.nomProduit,
                'quantite': i.quantite,
                'prixUnitaireVente': i.prixUnitaireVente,
                'prixUnitaireAchat': i.prixUnitaireAchat,
              })
          .toList(),
      'annulee': annulee,
    };
  }

  /// Sérialisation complète et sans perte pour l'export/import de
  /// sauvegarde (lib/services/backup_service.dart) — distincte de
  /// [toMap] qui ne sert qu'à la synchronisation Firestore.
  Map<String, dynamic> versJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'itemsVendus': itemsVendus.map((i) => i.versJson()).toList(),
        'montantTotal': montantTotal,
        'beneficeNet': beneficeNet,
        'devise': devise,
        'synchronise': synchronise,
        'montantTotalMineur': montantTotalMineur,
        'beneficeNetMineur': beneficeNetMineur,
        'modePaiement': modePaiement.name,
        'annulee': annulee,
        'dateAnnulation': dateAnnulation?.toIso8601String(),
        'motifAnnulation': motifAnnulation,
      };

  factory Transaction.depuisJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        itemsVendus: (json['itemsVendus'] as List)
            .map((i) => ItemVendu.depuisJson(i as Map<String, dynamic>))
            .toList(),
        montantTotal: (json['montantTotal'] as num).toDouble(),
        beneficeNet: (json['beneficeNet'] as num).toDouble(),
        devise: json['devise'] as String,
        synchronise: json['synchronise'] as bool? ?? false,
        montantTotalMineur: json['montantTotalMineur'] as int?,
        beneficeNetMineur: json['beneficeNetMineur'] as int?,
        modePaiement: json['modePaiement'] == null
            ? ModePaiement.especes
            : ModePaiement.values.byName(json['modePaiement'] as String),
        annulee: json['annulee'] as bool? ?? false,
        dateAnnulation: json['dateAnnulation'] == null
            ? null
            : DateTime.parse(json['dateAnnulation'] as String),
        motifAnnulation: json['motifAnnulation'] as String?,
      );
}
