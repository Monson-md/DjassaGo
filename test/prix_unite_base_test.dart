// Tests purs (sans Hive) du calcul du prix de l'unité de base — mission I2.
//
// Règle : si un format de quantité 1 existe, son prix est celui de l'unité
// de base ; sinon on divise le prix du format par défaut par sa quantité,
// avec arrondi à l'unité mineure de la devise.

import 'package:caisse_de_poche/services/normalisation_conditionnements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculerPrixUniteBaseMineur', () {
    test('casier de 20 à 2000 sans format unité : 100 par unité de base', () {
      final prix = calculerPrixUniteBaseMineur(
        quantitesEnUniteBase: const [20],
        prixVenteMineur: const [2000],
        indexParDefaut: 0,
      );
      expect(prix, 100);
    });

    test(
      'priorité au format de quantité 1 (casier 20 à 2000 + bouteille 1 à 120)',
      () {
        final prix = calculerPrixUniteBaseMineur(
          quantitesEnUniteBase: const [20, 1],
          prixVenteMineur: const [2000, 120],
          indexParDefaut: 0,
        );
        expect(prix, 120);
      },
    );

    test('format par défaut déjà en quantité 1 : son prix tel quel', () {
      final prix = calculerPrixUniteBaseMineur(
        quantitesEnUniteBase: const [20, 1],
        prixVenteMineur: const [2000, 120],
        indexParDefaut: 1,
      );
      expect(prix, 120);
    });

    test('division non entière en XOF : 3 à 1000 donne 333 après arrondi', () {
      final prix = calculerPrixUniteBaseMineur(
        quantitesEnUniteBase: const [3],
        prixVenteMineur: const [1000],
        indexParDefaut: 0,
      );
      expect(prix, 333);
    });

    test('devise à 2 décimales : arrondi correct en unités mineures', () {
      // 3 unités à 10,00 € = 1000 centimes ; 1000 / 3 = 333,33 -> 333.
      final prixMineur = calculerPrixUniteBaseMineur(
        quantitesEnUniteBase: const [3],
        prixVenteMineur: const [1000],
        indexParDefaut: 0,
      );
      expect(prixMineur, 333);

      final prixMajeur = calculerPrixUniteBase(
        quantitesEnUniteBase: const [3],
        prixVente: const [10.00],
        indexParDefaut: 0,
        decimales: 2,
      );
      expect(prixMajeur, 3.33);
    });
  });

  group('normaliserNomConditionnement / validation', () {
    test('la normalisation ignore casse et espaces', () {
      expect(
        normaliserNomConditionnement('  Casier   de   12 '),
        'casier de 12',
      );
    });

    test('des noms homonymes normalisés sont refusés', () {
      final erreur = validerNomsEtQuantitesConditionnements(
        noms: const ['Casier', '  casier  '],
        quantitesEnUniteBase: const [12, 24],
      );
      expect(erreur, isNotNull);
    });
  });
}
