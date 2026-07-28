/// Noms centralisés des boxes Hive utilisées dans l'application.
class HiveBoxes {
  HiveBoxes._();

  static const String produits = 'produits_box';
  static const String transactions = 'transactions_box';
  static const String dettes = 'dettes_box';
  static const String devises = 'devises_box';
  static const String parametres = 'parametres_box';
}

/// Clés utilisées dans la box [HiveBoxes.parametres].
class ParametresKeys {
  ParametresKeys._();

  static const String premierLancementTermine = 'premier_lancement_termine';
  static const String devisePrincipale = 'devise_principale';
  static const String paysCode = 'pays_code';
  static const String paysNom = 'pays_nom';

  /// Version du schéma Hive attendue par le code actuel. Comparée à la
  /// valeur stockée à chaque démarrage (voir HiveService.init) : en cas
  /// de désaccord, les boxes de données locales sont effacées plutôt que
  /// de risquer une erreur de cast au premier accès à un champ dont le
  /// type a changé entre deux versions de l'app.
  static const String schemaVersion = 'schema_version';
}
