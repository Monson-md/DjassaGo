import 'package:hive/hive.dart';

part 'conflit_synchronisation.g.dart';

/// Une entrée du journal des conflits de synchronisation (Phase 9,
/// préparation — voir lib/services/sync_service.dart et
/// sync_conflict_resolver.dart). Cette box reste vide tant qu'aucune
/// synchronisation réelle n'est activée : elle ne sert qu'à consigner,
/// pour le commerçant, les cas où une version locale et une version
/// distante d'un même enregistrement ont divergé et où l'une des deux a dû
/// être écartée.
@HiveType(typeId: 10)
class ConflitSynchronisation extends HiveObject {
  @HiveField(0)
  String id;

  /// Nom du type d'entité concerné (ex: "Produit", "Transaction").
  @HiveField(1)
  String entiteType;

  @HiveField(2)
  String entiteId;

  @HiveField(3)
  DateTime dateConflit;

  /// Nom de [ResultatResolutionConflit] retenu ("conserverLocal" ou
  /// "conserverDistant").
  @HiveField(4)
  String resolutionRetenue;

  @HiveField(5)
  String? resumeLocal;

  @HiveField(6)
  String? resumeDistant;

  ConflitSynchronisation({
    required this.id,
    required this.entiteType,
    required this.entiteId,
    required this.dateConflit,
    required this.resolutionRetenue,
    this.resumeLocal,
    this.resumeDistant,
  });
}
