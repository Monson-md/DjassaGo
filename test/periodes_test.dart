// Test de la Phase 7 : bornes des périodes (jour/semaine/mois) utilisées
// par le tableau de bord CA / marge brute / dépenses / résultat net.

import 'package:caisse_de_poche/utils/periodes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Jeudi 30 juillet 2026.
  final reference = DateTime(2026, 7, 30);

  test('jour : bornes du jour de référence', () {
    final plage = plagePour(Periode.jour, reference: reference);
    expect(plage.debut, DateTime(2026, 7, 30));
    expect(plage.finExclusive, DateTime(2026, 7, 31));
    expect(plage.contient(DateTime(2026, 7, 30, 23, 59)), isTrue);
    expect(plage.contient(DateTime(2026, 7, 31)), isFalse);
  });

  test('semaine : du lundi au dimanche, référence un jeudi', () {
    final plage = plagePour(Periode.semaine, reference: reference);
    expect(plage.debut, DateTime(2026, 7, 27)); // lundi
    expect(plage.finExclusive, DateTime(2026, 8, 3)); // lundi suivant
    expect(plage.contient(DateTime(2026, 7, 27)), isTrue);
    expect(plage.contient(DateTime(2026, 8, 2, 23, 59)), isTrue); // dimanche
    expect(plage.contient(DateTime(2026, 8, 3)), isFalse);
  });

  test('semaine : référence un dimanche reste dans la même semaine', () {
    final dimanche = DateTime(2026, 8, 2);
    final plage = plagePour(Periode.semaine, reference: dimanche);
    expect(plage.debut, DateTime(2026, 7, 27));
    expect(plage.finExclusive, DateTime(2026, 8, 3));
  });

  test('mois : bornes du mois calendaire', () {
    final plage = plagePour(Periode.mois, reference: reference);
    expect(plage.debut, DateTime(2026, 7, 1));
    expect(plage.finExclusive, DateTime(2026, 8, 1));
  });

  test('mois : décembre bascule correctement sur janvier de l\'année suivante', () {
    final plage =
        plagePour(Periode.mois, reference: DateTime(2026, 12, 15));
    expect(plage.debut, DateTime(2026, 12, 1));
    expect(plage.finExclusive, DateTime(2027, 1, 1));
  });
}
