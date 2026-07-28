import 'package:intl/intl.dart';

/// Convertit un montant décimal (ex: saisi par l'utilisateur) en entier
/// exprimé en unités mineures de la devise (ex: centimes pour l'EUR,
/// unités entières pour le XOF qui n'a pas de subdivision). Stocker et
/// additionner des entiers élimine les erreurs d'arrondi flottant qui
/// s'accumulent sur des totaux répétés (double 0.1 + 0.2 != 0.3).
int versUnitesMineures(double montant, int decimales) {
  return (montant * _facteur(decimales)).round();
}

/// Reconvertit un montant en unités mineures vers sa valeur décimale,
/// uniquement pour l'affichage ou l'interopérabilité avec du code encore
/// exprimé en double.
double depuisUnitesMineures(int montantMineur, int decimales) {
  return montantMineur / _facteur(decimales);
}

int _facteur(int decimales) {
  var facteur = 1;
  for (var i = 0; i < decimales; i++) {
    facteur *= 10;
  }
  return facteur;
}

final Map<int, NumberFormat> _formateursParDecimales = {};

/// Seule fonction à utiliser pour afficher un montant monétaire dans
/// l'application. Respecte le nombre de décimales propre à la devise
/// (0 pour XOF/XAF, 2 pour EUR/USD...) au lieu d'un formatage générique
/// qui pourrait afficher des décimales non pertinentes pour la devise
/// (ex: « 1500,00 FCFA » alors que le FCFA n'a pas de subdivision).
String formaterMontantMineur(
  int montantMineur, {
  required int decimales,
  String symbole = '',
}) {
  final formateur = _formateursParDecimales.putIfAbsent(
    decimales,
    () => NumberFormat.decimalPattern('fr_FR')
      ..minimumFractionDigits = decimales
      ..maximumFractionDigits = decimales,
  );
  final valeur =
      formateur.format(depuisUnitesMineures(montantMineur, decimales));
  return symbole.isEmpty ? valeur : '$valeur $symbole';
}
