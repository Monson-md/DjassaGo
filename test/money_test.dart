// Test de la Phase 10 : lib/utils/money.dart — conversion en unités
// mineures, arrondis, et formatage selon le nombre de décimales de la
// devise (0 pour XOF/XAF, 2 pour EUR/USD...). Logique pure, sans Hive.

import 'package:caisse_de_poche/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('devise à 0 décimale (XOF) : aucune subdivision', () {
    expect(versUnitesMineures(1500, 0), 1500);
    expect(depuisUnitesMineures(1500, 0), 1500.0);
    // Pas de séparateur de milliers en jeu ici : évite toute hypothèse
    // fragile sur le caractère exact (espace normale/insécable) utilisé
    // par la locale fr_FR pour les groupes de milliers.
    expect(formaterMontantMineur(150, decimales: 0), '150');
  });

  test('devise à 2 décimales (EUR) : centimes', () {
    expect(versUnitesMineures(19.99, 2), 1999);
    expect(depuisUnitesMineures(1999, 2), 19.99);
    expect(formaterMontantMineur(1999, decimales: 2), '19,99');
  });

  test('arrondi au plus proche, sans dérive flottante', () {
    expect(versUnitesMineures(10.10, 2), 1010);
    expect(versUnitesMineures(19.996, 2), 2000); // 0,6 arrondi au-dessus.
    expect(versUnitesMineures(19.994, 2), 1999); // 0,4 arrondi en dessous.
  });

  test('aller-retour vers/depuis unités mineures sans perte', () {
    for (final decimales in [0, 2]) {
      final valeur = decimales == 0 ? 2500.0 : 25.50;
      final mineur = versUnitesMineures(valeur, decimales);
      expect(depuisUnitesMineures(mineur, decimales), valeur);
    }
  });

  test('symbole optionnel accolé après le montant formaté', () {
    expect(
        formaterMontantMineur(150, decimales: 0, symbole: 'FCFA'), '150 FCFA');
    expect(formaterMontantMineur(150, decimales: 0), '150');
  });
}
