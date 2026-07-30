import 'package:hive/hive.dart';

part 'categorie_depense.g.dart';

@HiveType(typeId: 8)
enum CategorieDepense {
  @HiveField(0)
  loyer,
  @HiveField(1)
  transport,
  @HiveField(2)
  electricite,
  @HiveField(3)
  reapprovisionnement,
  @HiveField(4)
  autre,
}
