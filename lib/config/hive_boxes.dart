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
  /// de désaccord, les boxes de données locales sont effacées plutôt que
  /// de risquer une erreur de cast au premier accès à un champ dont le
  /// type a changé entre deux versions de l'app.
  static const String schemaVersion = 'schema_version';

  /// Identifiant stable de cet appareil (UUID v4), généré une seule fois
  /// par DeviceIdService et utilisé comme départage lors d'un conflit de
  /// synchronisation (Phase 9 — voir lib/services/sync_conflict_resolver.dart).
  static const String deviceId = 'device_id';
}
