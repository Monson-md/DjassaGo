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

  ItemVendu({
    required this.produitId,
    required this.nomProduit,
    required this.quantite,
    required this.prixUnitaireVente,
    required this.prixUnitaireAchat,
  });

  double get sousTotal => prixUnitaireVente * quantite;

  double get benefice => (prixUnitaireVente - prixUnitaireAchat) * quantite;
}
