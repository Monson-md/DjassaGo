import 'package:hive/hive.dart';

import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import 'item_vendu.dart';

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
  })  : montantTotalMineur = montantTotalMineur ??
            versUnitesMineures(montantTotal, decimalesPourCodeIso(devise)),
        beneficeNetMineur = beneficeNetMineur ??
            versUnitesMineures(beneficeNet, decimalesPourCodeIso(devise));

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
    };
  }
}
