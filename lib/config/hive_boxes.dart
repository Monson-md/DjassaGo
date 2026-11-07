/// Noms centralisés des boxes Hive utilisées dans l'application.
class HiveBoxes {
  HiveBoxes._();

  static const String produits = 'produits_box';
  static const String transactions = 'transactions_box';
  static const String dettes = 'dettes_box';
  static const String devises = 'devises_box';
  static const String parametres = 'parametres_box';
  static const String paiementsDette = 'paiements_dette_box';
  static const String depenses = 'depenses_box';

  /// Conditionnements de vente des produits (Bouteille, Casier, Carton...)
  /// — voir lib/models/conditionnement.dart.
  static const String conditionnements = 'conditionnements_box';

  /// Journal des conflits de synchronisation (Phase 9, préparation
  /// uniquement — voir lib/services/sync_service.dart). Vide tant qu'aucune
  /// synchronisation réelle n'est activée.
  static const String conflitsSynchronisation = 'conflits_synchronisation_box';
}

/// Clés utilisées dans la box [HiveBoxes.parametres].
class ParametresKeys {
  ParametresKeys._();

  static const String premierLancementTermine = 'premier_lancement_termine';
  static const String devisePrincipale = 'devise_principale';
  static const String paysCode = 'pays_code';
  static const String paysNom = 'pays_nom';

  /// Indicatif téléphonique du pays (sans le +), utilisé pour normaliser
  /// les numéros en E.164 (voir lib/utils/telephone.dart). Absent chez les
  /// installations qui ont fait l'onboarding avant la Phase 6 — un repli
  /// par pays existe dans lib/utils/indicatifs_telephoniques.dart.
  static const String indicatifPays = 'indicatif_pays';

  /// Version du schéma Hive attendue par le code actuel. Comparée à la
  /// valeur stockée à chaque démarrage (voir HiveService.init) : en cas
  /// de désaccord, une MIGRATION versionnée s'exécute (ou, en l'absence
  /// de migrateur, le démarrage est refusé explicitement) — jamais
  /// d'effacement de données. Voir ParametresKeys.migrationHiveEnCours
  /// pour le journal qui rend chaque migration récupérable.
  static const String schemaVersion = 'schema_version';

  /// Journal d'une migration Hive en cours (voir
  /// lib/services/hive_migrations.dart et HiveService.init). Absent en
  /// temps normal ; présent seulement entre le début d'une migration et
  /// sa validation complète. En cas d'arrêt brutal pendant la migration,
  /// cette entrée déclenche au démarrage suivant la restauration de la
  /// sauvegarde brute correspondante — jamais un effacement.
  static const String migrationHiveEnCours = 'migration_hive_en_cours';

  /// Identifiant stable de cet appareil (UUID v4), généré une seule fois
  /// par DeviceIdService et utilisé comme départage lors d'un conflit de
  /// synchronisation (Phase 9 — voir lib/services/sync_conflict_resolver.dart).
  static const String deviceId = 'device_id';
}
