/// Périodes utilisées par le tableau de bord (CA, marge brute, dépenses,
/// résultat net) : jour, semaine (lundi-dimanche) et mois calendaire.
enum Periode { jour, semaine, mois }

/// Bornes `[debut, finExclusive[` d'une [Periode], calculées à partir
/// d'une date de référence (par défaut aujourd'hui).
class PlagePeriode {
  final DateTime debut;
  final DateTime finExclusive;

  const PlagePeriode({required this.debut, required this.finExclusive});

  bool contient(DateTime date) =>
      !date.isBefore(debut) && date.isBefore(finExclusive);
}

PlagePeriode plagePour(Periode periode, {DateTime? reference}) {
  final ref = reference ?? DateTime.now();
  final debutJour = DateTime(ref.year, ref.month, ref.day);

  switch (periode) {
    case Periode.jour:
      return PlagePeriode(
        debut: debutJour,
        finExclusive: debutJour.add(const Duration(days: 1)),
      );
    case Periode.semaine:
      // Semaine du lundi (weekday == 1) au dimanche.
      final debut = debutJour.subtract(Duration(days: ref.weekday - 1));
      return PlagePeriode(
        debut: debut,
        finExclusive: debut.add(const Duration(days: 7)),
      );
    case Periode.mois:
      final debut = DateTime(ref.year, ref.month, 1);
      final finExclusive = DateTime(ref.year, ref.month + 1, 1);
      return PlagePeriode(debut: debut, finExclusive: finExclusive);
  }
}
