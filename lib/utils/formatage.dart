import 'package:intl/intl.dart';

final NumberFormat _formateurMontant = NumberFormat.decimalPattern('fr_FR');
final DateFormat _formateurDateCourte = DateFormat('dd/MM/yyyy');
final DateFormat _formateurHeure = DateFormat('HH:mm');

String formaterMontant(double montant, {String symbole = ''}) {
  final valeur = _formateurMontant.format(montant);
  return symbole.isEmpty ? valeur : '$valeur $symbole';
}

String formaterDate(DateTime date) => _formateurDateCourte.format(date);

String formaterHeure(DateTime date) => _formateurHeure.format(date);
