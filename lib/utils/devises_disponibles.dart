/// Association simple entre un code pays (ISO 3166-1 alpha-2, tel que
/// fourni par le package country_picker) et sa devise principale.
/// Utilisée lors de la sélection du pays au premier lancement pour
/// pré-remplir automatiquement la devise du commerçant.
class InfoDevise {
  final String symbole;
  final String nom;
  final String codeIso;

  /// Nombre de décimales de la devise (unités mineures ISO 4217) : 0 pour
  /// les francs CFA qui n'ont pas de subdivision, 2 pour la plupart des
  /// autres devises, 3 pour le dinar tunisien.
  final int decimales;

  const InfoDevise({
    required this.symbole,
    required this.nom,
    required this.codeIso,
    required this.decimales,
  });
}

const Map<String, InfoDevise> devisesParPays = {
  // Zone UEMOA (Franc CFA Ouest-Africain)
  'CI': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0),
  'SN': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0),
  'ML': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0),
  'BF': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0),
  'TG': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0),
  'BJ': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0),
  'NE': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0),
  'GW': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0),
  // Zone CEMAC (Franc CFA Afrique Centrale)
  'CM': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF', decimales: 0),
  'GA': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF', decimales: 0),
  'TD': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF', decimales: 0),
  'CG': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF', decimales: 0),
  'GQ': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF', decimales: 0),
  'CF': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF', decimales: 0),
  // Autres devises africaines courantes
  'NG': InfoDevise(symbole: '₦', nom: 'Naira nigérian', codeIso: 'NGN', decimales: 2),
  'GH': InfoDevise(symbole: 'GH₵', nom: 'Cedi ghanéen', codeIso: 'GHS', decimales: 2),
  'MA': InfoDevise(symbole: 'DH', nom: 'Dirham marocain', codeIso: 'MAD', decimales: 2),
  'DZ': InfoDevise(symbole: 'DA', nom: 'Dinar algérien', codeIso: 'DZD', decimales: 2),
  'TN': InfoDevise(symbole: 'DT', nom: 'Dinar tunisien', codeIso: 'TND', decimales: 3),
  'CD': InfoDevise(symbole: 'FC', nom: 'Franc congolais', codeIso: 'CDF', decimales: 2),
  'KE': InfoDevise(symbole: 'KSh', nom: 'Shilling kényan', codeIso: 'KES', decimales: 2),
  'RW': InfoDevise(symbole: 'FRw', nom: 'Franc rwandais', codeIso: 'RWF', decimales: 0),
  'GN': InfoDevise(symbole: 'FG', nom: 'Franc guinéen', codeIso: 'GNF', decimales: 0),
  // Devises internationales majeures
  'FR': InfoDevise(symbole: '€', nom: 'Euro', codeIso: 'EUR', decimales: 2),
  'BE': InfoDevise(symbole: '€', nom: 'Euro', codeIso: 'EUR', decimales: 2),
  'US': InfoDevise(symbole: '\$', nom: 'Dollar américain', codeIso: 'USD', decimales: 2),
  'GB': InfoDevise(symbole: '£', nom: 'Livre sterling', codeIso: 'GBP', decimales: 2),
  'CA': InfoDevise(symbole: 'CA\$', nom: 'Dollar canadien', codeIso: 'CAD', decimales: 2),
};

const InfoDevise deviseParDefaut =
    InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF', decimales: 0);

InfoDevise deviseSelonPays(String codePays) {
  return devisesParPays[codePays.toUpperCase()] ?? deviseParDefaut;
}

/// Devises disponibles indexées par code ISO 4217, reconstruite depuis
/// [devisesParPays] (plusieurs pays partagent la même devise).
final Map<String, InfoDevise> devisesParCodeIso = {
  for (final devise in devisesParPays.values) devise.codeIso: devise,
};

/// Nombre de décimales pour un code ISO 4217 donné. Retourne 2 par défaut
/// (comportement le plus courant) si le code est inconnu.
int decimalesPourCodeIso(String codeIso) =>
    devisesParCodeIso[codeIso]?.decimales ?? 2;
