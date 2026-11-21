import '../utils/money.dart';

/// Fonctions pures partagées par le formulaire produit et
/// [ConditionnementService] : normalisation des noms, validation d'un
/// ensemble de formats de vente et calcul du prix de l'unité de base.
///
/// Aucune dépendance à Hive ni à Flutter : ces règles peuvent être testées
/// isolément (voir test/prix_unite_base_test.dart).

/// Normalise un nom de conditionnement pour comparer deux saisies :
/// espaces de bord retirés, espaces internes réduits à un seul, casse
/// ignorée. «  Casier   de 12 » et « casier de 12 » sont donc le même nom.
String normaliserNomConditionnement(String nom) {
  return nom.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

/// Valide l'ensemble des formats de vente d'un produit avant toute
/// écriture :
/// - au moins un format ;
/// - chaque nom non vide ;
/// - noms uniques après normalisation ;
/// - chaque quantité strictement positive.
///
/// Retourne `null` si tout est valide, sinon un message d'erreur destiné à
/// l'utilisateur.
String? validerNomsEtQuantitesConditionnements({
  required List<String> noms,
  required List<int> quantitesEnUniteBase,
}) {
  if (noms.isEmpty) {
    return 'Un produit doit avoir au moins un format de vente.';
  }
  final nomsVus = <String>{};
  for (var i = 0; i < noms.length; i++) {
    final nomNormalise = normaliserNomConditionnement(noms[i]);
    if (nomNormalise.isEmpty) {
      return 'Chaque format de vente doit avoir un nom.';
    }
    if (!nomsVus.add(nomNormalise)) {
      return 'Deux formats de vente portent le même nom « ${noms[i].trim()} ».';
    }
    if (i >= quantitesEnUniteBase.length || quantitesEnUniteBase[i] <= 0) {
      return 'Chaque format de vente doit avoir une quantité supérieure à 0.';
    }
  }
  return null;
}

/// Calcule le prix de vente d'une unité de base, en unités mineures.
///
/// Règle (option A de la mission I2) :
/// 1. si un format de quantité 1 existe, son prix est celui de l'unité de
///    base (le format par défaut est prioritaire s'il est lui-même de
///    quantité 1, sinon le premier format de quantité 1) ;
/// 2. sinon, on divise le prix du format par défaut par sa quantité en
///    unité de base, puis on arrondit à l'unité mineure.
///
/// [indexParDefaut] doit désigner un index valide ; par prudence, un index
/// hors bornes retombe sur le premier format.
int calculerPrixUniteBaseMineur({
  required List<int> quantitesEnUniteBase,
  required List<int> prixVenteMineur,
  required int indexParDefaut,
}) {
  if (quantitesEnUniteBase.isEmpty || prixVenteMineur.isEmpty) return 0;
  final indexDefaut =
      indexParDefaut >= 0 && indexParDefaut < quantitesEnUniteBase.length
      ? indexParDefaut
      : 0;

  // Priorité au format par défaut s'il vaut déjà une unité de base.
  if (quantitesEnUniteBase[indexDefaut] == 1) {
    return prixVenteMineur[indexDefaut];
  }
  // Sinon, n'importe quel autre format de quantité 1 fait foi.
  for (var i = 0; i < quantitesEnUniteBase.length; i++) {
    if (quantitesEnUniteBase[i] == 1) return prixVenteMineur[i];
  }

  final quantite = quantitesEnUniteBase[indexDefaut];
  if (quantite <= 0) return 0;
  return (prixVenteMineur[indexDefaut] / quantite).round();
}

/// Variante de [calculerPrixUniteBaseMineur] travaillant sur les prix en
/// unités majeures (ceux saisis dans le formulaire) : convertit d'abord
/// chaque prix avec les décimales de la devise, puis revient à un double
/// pour l'écriture dans [Produit.prixVente].
double calculerPrixUniteBase({
  required List<int> quantitesEnUniteBase,
  required List<double> prixVente,
  required int indexParDefaut,
  required int decimales,
}) {
  final prixMineurs = [
    for (final prix in prixVente) versUnitesMineures(prix, decimales),
  ];
  final prixUniteBaseMineur = calculerPrixUniteBaseMineur(
    quantitesEnUniteBase: quantitesEnUniteBase,
    prixVenteMineur: prixMineurs,
    indexParDefaut: indexParDefaut,
  );
  return depuisUnitesMineures(prixUniteBaseMineur, decimales);
}
