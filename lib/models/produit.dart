import 'package:hive/hive.dart';

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
  }) : dateCreation = dateCreation ?? DateTime.now();

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
}
