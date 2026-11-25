import '../models/conditionnement.dart';
import '../models/produit.dart';
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import 'normalisation_conditionnements.dart';

/// Résultat de [normaliserProduitsEtConditionnements].
class ResultatNormalisationProduits {
  final List<Produit> produits;
  final List<Conditionnement> conditionnements;

  const ResultatNormalisationProduits({
    required this.produits,
    required this.conditionnements,
  });
}

/// Applique aux données les règles des missions I1/I2, sans dépendance à
/// Hive :
/// 1. noms de conditionnement uniques après normalisation pour un même
///    produit ;
/// 2. [Produit.prixVente]/[Produit.prixVenteMineur] = prix d'UNE unité de
///    base, calculé depuis les conditionnements du produit.
///
/// Utilisée à l'identique par la migration Hive 1→2
/// (lib/services/hive_migrations.dart) et par l'import d'une sauvegarde
/// antérieure au format 3 (lib/services/backup_service.dart). Une seule
/// logique, donc aucun risque de divergence.
///
/// Les objets passés sont modifiés en place puis retournés. Les produits
/// sans aucun conditionnement sont laissés tels quels : un produit simple
/// est vendu à l'unité, son prix est déjà celui de l'unité de base.
ResultatNormalisationProduits normaliserProduitsEtConditionnements({
  required List<Produit> produits,
  required List<Conditionnement> conditionnements,
}) {
  final parProduit = <String, List<Conditionnement>>{};
  for (final conditionnement in conditionnements) {
    parProduit
        .putIfAbsent(conditionnement.produitId, () => <Conditionnement>[])
        .add(conditionnement);
  }

  final conditionnementsNormalises = <Conditionnement>[];
  for (final formats in parProduit.values) {
    conditionnementsNormalises.addAll(_renommerDoublons(formats));
  }

  final parProduitNormalise = <String, List<Conditionnement>>{};
  for (final conditionnement in conditionnementsNormalises) {
    parProduitNormalise
        .putIfAbsent(conditionnement.produitId, () => <Conditionnement>[])
        .add(conditionnement);
  }

  for (final produit in produits) {
    final formats = parProduitNormalise[produit.id];
    if (formats == null || formats.isEmpty) continue;

    final tries = _trierFormats(formats);
    final indexParDefaut = tries.indexWhere((c) => c.parDefaut);

    final prixMineur = calculerPrixUniteBaseMineur(
      quantitesEnUniteBase: [for (final c in tries) c.quantiteEnUniteBase],
      prixVenteMineur: [for (final c in tries) _prixMineurEffectif(c)],
      indexParDefaut: indexParDefaut < 0 ? 0 : indexParDefaut,
    );

    // Calcul indéterminé (quantité invalide, prix tous nuls) : conserver
    // le prix existant plutôt que de détruire une donnée.
    if (prixMineur <= 0) continue;

    produit.prixVenteMineur = prixMineur;
    produit.prixVente = depuisUnitesMineures(
      prixMineur,
      decimalesPourCodeIso(produit.devise),
    );
  }

  return ResultatNormalisationProduits(
    produits: produits,
    conditionnements: conditionnementsNormalises,
  );
}

/// Ordre déterministe : format par défaut d'abord, puis quantité croissante,
/// puis identifiant. L'identifiant est le départage stable qui rend la
/// migration reproductible et idempotente.
List<Conditionnement> _trierFormats(List<Conditionnement> formats) {
  return [...formats]..sort((a, b) {
    if (a.parDefaut != b.parDefaut) return a.parDefaut ? -1 : 1;
    final parQuantite = a.quantiteEnUniteBase.compareTo(b.quantiteEnUniteBase);
    if (parQuantite != 0) return parQuantite;
    return a.id.compareTo(b.id);
  });
}

/// Renomme les doublons normalisés d'un même produit : le premier format
/// (ordre [_trierFormats]) conserve son nom, les suivants reçoivent
/// « Nom (2) », « Nom (3) »... en évitant toute collision avec un nom déjà
/// utilisé par le produit. Les identifiants ne changent jamais.
List<Conditionnement> _renommerDoublons(List<Conditionnement> formats) {
  final tries = _trierFormats(formats);

  final groupes = <String, List<Conditionnement>>{};
  for (final format in tries) {
    groupes
        .putIfAbsent(normaliserNomConditionnement(format.nom), () => [])
        .add(format);
  }

  final nomsUtilises = <String>{
    for (final format in tries) normaliserNomConditionnement(format.nom),
  };

  for (final groupe in groupes.values) {
    if (groupe.length < 2) continue;

    final base = groupe.first.nom.trim().isEmpty
        ? 'Format'
        : groupe.first.nom.trim();
    var suffixe = 2;

    for (var i = 1; i < groupe.length; i++) {
      String candidat;
      do {
        candidat = '$base ($suffixe)';
        suffixe++;
      } while (nomsUtilises.contains(normaliserNomConditionnement(candidat)));

      groupe[i].nom = candidat;
      nomsUtilises.add(normaliserNomConditionnement(candidat));
    }
  }

  return tries;
}

/// Prix en unités mineures d'un conditionnement, en réparant au passage le
/// pendant mineur resté à 0 sur des données antérieures à son introduction.
int _prixMineurEffectif(Conditionnement conditionnement) {
  if (conditionnement.prixVenteMineur != 0) {
    return conditionnement.prixVenteMineur;
  }
  final derive = versUnitesMineures(
    conditionnement.prixVente,
    decimalesPourCodeIso(conditionnement.devise),
  );
  if (derive != 0) conditionnement.prixVenteMineur = derive;
  return derive;
}
