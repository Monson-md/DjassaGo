import 'package:hive/hive.dart';

part 'devise.g.dart';

@HiveType(typeId: 0)
class Devise extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String symbole;

  @HiveField(2)
  String nom;

  @HiveField(3)
  String codeIso;

  @HiveField(4)
  String codePays;

  Devise({
    required this.id,
    required this.symbole,
    required this.nom,
    required this.codeIso,
    required this.codePays,
  });
}
