import 'package:hive/hive.dart';

part 'mode_paiement.g.dart';

/// Moyen par lequel une [Transaction] a été réglée. `credit` signifie que
/// la vente est actée (voir CaisseService) mais qu'aucun argent n'a
/// encore été encaissé : une Dette liée est créée dans ce cas.
@HiveType(typeId: 6)
enum ModePaiement {
  @HiveField(0)
  especes,
  @HiveField(1)
  credit,
  @HiveField(2)
  mobileMoney,
}
