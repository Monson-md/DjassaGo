// Test de la Phase 6 : normalisation des numéros de téléphone en E.164 à
// partir de l'indicatif du pays, avec des formats de saisie réels
// (espaces, zéro initial, préfixe international 00, indicatif déjà
// présent avec ou sans +).

import 'package:caisse_de_poche/utils/telephone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const indicatif = '225';

  test('numéro local avec zéro initial et espaces : 07 XX XX XX XX', () {
    expect(normaliserTelephone('07 12 34 56 78', indicatif), '+225712345678');
  });

  test(
      'numéro avec indicatif, espace et zéro initial redondant : '
      '+225 07 XX XX XX XX', () {
    expect(normaliserTelephone('+225 07 12 34 56 78', indicatif),
        '+225712345678');
  });

  test('numéro avec préfixe international 00 : 0022507XXXXXXX', () {
    expect(
        normaliserTelephone('002250712345678', indicatif), '+225712345678');
  });

  test('numéro déjà normalisé reste inchangé (idempotent)', () {
    expect(
        normaliserTelephone('+225712345678', indicatif), '+225712345678');
  });

  test('numéro local avec tirets et parenthèses', () {
    expect(normaliserTelephone('(07) 12-34-56-78', indicatif),
        '+225712345678');
  });

  test('numéro vide ou uniquement des espaces renvoie une chaîne vide', () {
    expect(normaliserTelephone('', indicatif), '');
    expect(normaliserTelephone('   ', indicatif), '');
  });

  test("indicatif différent de celui du pays courant reste tel quel", () {
    // Un client dont le numéro a un indicatif étranger (ex: Sénégal +221)
    // ne doit pas se voir imposer l'indicatif du commerçant.
    expect(normaliserTelephone('+221771234567', indicatif), '+221771234567');
  });
}
