/// Normalise un numéro de téléphone au format E.164 (ex: `+225712345678`),
/// à partir de l'indicatif du pays choisi à l'onboarding (sans le +).
/// Retire les espaces, tirets et parenthèses, le préfixe international
/// `00`, et le zéro initial local — qu'il soit saisi seul ou juste après
/// l'indicatif — pour obtenir un format unique quelle que soit la façon
/// dont le commerçant a saisi le numéro (ex: `07 12 34 56 78`,
/// `+225 07 12 34 56 78` ou `002250712345678` normalisent tous vers
/// `+225712345678`).
String normaliserTelephone(String telephone, String indicatifPays) {
  final brut = telephone.trim();
  if (brut.isEmpty) return '';

  var chiffres = brut.replaceAll(RegExp(r'[^0-9]'), '');
  if (chiffres.isEmpty) return '';

  // Un + ou un préfixe international 00 signale que le numéro porte déjà
  // un indicatif (le nôtre ou celui d'un autre pays, ex: un client dont
  // le numéro est enregistré avec son propre indicatif) : on ne doit
  // alors jamais préfixer l'indicatif du commerçant par-dessus.
  final formatInternational = brut.startsWith('+') || chiffres.startsWith('00');

  if (!brut.startsWith('+') && chiffres.startsWith('00')) {
    chiffres = chiffres.substring(2);
  }

  if (formatInternational) {
    if (chiffres.startsWith(indicatifPays)) {
      var reste = chiffres.substring(indicatifPays.length);
      if (reste.startsWith('0')) {
        reste = reste.substring(1);
      }
      return '+$indicatifPays$reste';
    }
    return '+$chiffres';
  }

  // Numéro local, sans indicatif : on retire le zéro initial (préfixe
  // national) puis on préfixe l'indicatif du commerçant.
  if (chiffres.startsWith('0')) {
    chiffres = chiffres.substring(1);
  }
  return '+$indicatifPays$chiffres';
}
