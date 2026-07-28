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

  /// Nombre de décimales de la devise (0 pour XOF/FCFA, 2 pour EUR/USD...).
  /// Ajouté après la création initiale du modèle : valeur par défaut 2
  /// pour les enregistrements existants qui ne l'avaient pas encore.
  @HiveField(5, defaultValue: 2)
  int decimales;

  Devise({
    required this.id,
    required this.symbole,
    required this.nom,
    required this.codeIso,
    required this.codePays,
    this.decimales = 2,
  });
}
