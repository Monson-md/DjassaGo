// Tests purs de la normalisation partagée par la migration Hive 1→2 et
// l'import d'une sauvegarde antérieure au format 3 : renommage déterministe
// des doublons de conditionnement et recalcul du prix d'UNE unité de base.
// Aucune dépendance à Hive ni à Flutter.

import 'package:caisse_de_poche/models/conditionnement.dart';
import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/services/normalisation_produits_conditionnements.dart';
import 'package:flutter_test/flutter_test.dart';

Produit _produit({
  String id = 'p-1',
  String nom = 'Coca',
  double prixVente = 1500,
  int? prixVenteMineur,
}) => Produit(
  id: id,
  nom: nom,
  prixAchat: 50,
  prixVente: prixVente,
  prixVenteMineur: prixVenteMineur,
  stockActuel: 10,
  devise: 'XOF',
  uniteBase: 'bouteille',
);

Conditionnement _conditionnement({
  required String id,
  String produitId = 'p-1',
  required String nom,
  required int quantite,
  required double prixVente,
  bool parDefaut = false,
  int? prixVenteMineur,
}) => Conditionnement(
  id: id,
  produitId: produitId,
  nom: nom,
  quantiteEnUniteBase: quantite,
  prixVente: prixVente,
  prixVenteMineur: prixVenteMineur,
  parDefaut: parDefaut,
  devise: 'XOF',
);

void main() {
  test('renomme les doublons normalisés de façon déterministe sans changer '
      'les identifiants', () {
    final produit = _produit();
    final conditionnements = [
      _conditionnement(
        id: 'c-2',
        nom: 'Casier',
        quantite: 1,
        prixVente: 150,
        parDefaut: true,
      ),
      _conditionnement(id: 'c-1', nom: 'casier', quantite: 12, prixVente: 1200),
      _conditionnement(
        id: 'c-3',
        nom: ' CASIER ',
        quantite: 20,
        prixVente: 2000,
      ),
    ];

    final resultat = normaliserProduitsEtConditionnements(
      produits: [produit],
      conditionnements: conditionnements,
    );

    final parId = {for (final c in resultat.conditionnements) c.id: c};
    expect(parId.keys.toSet(), {'c-1', 'c-2', 'c-3'});
    expect(parId['c-2']!.nom, 'Casier');
    expect(parId['c-1']!.nom, 'Casier (2)');
    expect(parId['c-3']!.nom, 'Casier (3)');
    // Seul le nom change : quantité, prix et appartenance sont intacts.
    expect(parId['c-1']!.quantiteEnUniteBase, 12);
    expect(parId['c-1']!.prixVente, 1200);
    expect(parId['c-1']!.produitId, 'p-1');
    expect(parId['c-3']!.quantiteEnUniteBase, 20);
    expect(parId['c-3']!.prixVente, 2000);
    // Format de quantité 1 prioritaire.
    expect(produit.prixVenteMineur, 150);
    expect(produit.prixVente, 150);
  });

  test('le renommage évite toute collision avec un nom déjà utilisé', () {
    final conditionnements = [
      _conditionnement(
        id: 'c-a',
        nom: 'Casier',
        quantite: 1,
        prixVente: 150,
        parDefaut: true,
      ),
      _conditionnement(id: 'c-b', nom: 'casier', quantite: 2, prixVente: 300),
      _conditionnement(
        id: 'c-c',
        nom: 'Casier (2)',
        quantite: 3,
        prixVente: 450,
      ),
    ];

    final resultat = normaliserProduitsEtConditionnements(
      produits: [_produit()],
      conditionnements: conditionnements,
    );

    final parId = {for (final c in resultat.conditionnements) c.id: c};
    expect(parId['c-a']!.nom, 'Casier');
    expect(parId['c-b']!.nom, 'Casier (3)');
    expect(parId['c-c']!.nom, 'Casier (2)');
  });

  test("priorité au format de quantité 1 sur la division du format par "
      'défaut', () {
    final produit = _produit(prixVente: 2000);
    normaliserProduitsEtConditionnements(
      produits: [produit],
      conditionnements: [
        _conditionnement(
          id: 'c-20',
          nom: 'Casier',
          quantite: 20,
          prixVente: 2000,
          parDefaut: true,
        ),
        _conditionnement(
          id: 'c-1',
          nom: 'Bouteille',
          quantite: 1,
          prixVente: 120,
        ),
      ],
    );

    expect(produit.prixVenteMineur, 120);
    expect(produit.prixVente, 120);
  });

  test('division du prix du format par défaut par sa quantité', () {
    final produit = _produit(prixVente: 2000);
    normaliserProduitsEtConditionnements(
      produits: [produit],
      conditionnements: [
        _conditionnement(
          id: 'c-20',
          nom: 'Casier',
          quantite: 20,
          prixVente: 2000,
          parDefaut: true,
        ),
      ],
    );

    expect(produit.prixVenteMineur, 100);
    expect(produit.prixVente, 100);
  });

  test('un prixVenteMineur de conditionnement resté à 0 est réparé depuis '
      'prixVente avant le calcul', () {
    final produit = _produit(prixVente: 1000);
    final pack = _conditionnement(
      id: 'c-pack',
      nom: 'Pack',
      quantite: 10,
      prixVente: 1000,
      parDefaut: true,
      prixVenteMineur: 0,
    );

    normaliserProduitsEtConditionnements(
      produits: [produit],
      conditionnements: [pack],
    );

    expect(pack.prixVenteMineur, 1000);
    expect(produit.prixVenteMineur, 100);
    expect(produit.prixVente, 100);
  });

  test('un produit sans conditionnement reste strictement intact', () {
    final produit = _produit(
      id: 'p-simple',
      nom: 'Savon',
      prixVente: 500,
      prixVenteMineur: 500,
    );

    final resultat = normaliserProduitsEtConditionnements(
      produits: [produit],
      conditionnements: const [],
    );

    expect(resultat.produits.single.prixVente, 500);
    expect(resultat.produits.single.prixVenteMineur, 500);
    expect(resultat.produits.single.nom, 'Savon');
    expect(resultat.conditionnements, isEmpty);
  });

  test('idempotente : une seconde exécution ne change ni les noms ni les '
      'prix', () {
    final produit = _produit(prixVente: 1500);
    final conditionnements = [
      _conditionnement(
        id: 'c-2',
        nom: 'Casier',
        quantite: 1,
        prixVente: 150,
        parDefaut: true,
      ),
      _conditionnement(id: 'c-1', nom: 'casier', quantite: 12, prixVente: 1200),
    ];

    final premier = normaliserProduitsEtConditionnements(
      produits: [produit],
      conditionnements: conditionnements,
    );
    final nomsPremier = {for (final c in premier.conditionnements) c.id: c.nom};
    final prixPremier = premier.produits.single.prixVenteMineur;

    final second = normaliserProduitsEtConditionnements(
      produits: premier.produits,
      conditionnements: premier.conditionnements,
    );

    expect({for (final c in second.conditionnements) c.id: c.nom}, nomsPremier);
    expect(second.produits.single.prixVenteMineur, prixPremier);
  });
}
