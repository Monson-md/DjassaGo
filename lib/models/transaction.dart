import 'package:hive/hive.dart';
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

  Transaction({
    required this.id,
    required this.date,
    required this.itemsVendus,
    required this.montantTotal,
    required this.beneficeNet,
    required this.devise,
    this.synchronise = false,
  });

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
