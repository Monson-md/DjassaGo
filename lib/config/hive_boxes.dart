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
}
