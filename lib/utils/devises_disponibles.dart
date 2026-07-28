/// Association simple entre un code pays (ISO 3166-1 alpha-2, tel que
/// fourni par le package country_picker) et sa devise principale.
/// Utilisée lors de la sélection du pays au premier lancement pour
/// pré-remplir automatiquement la devise du commerçant.
class InfoDevise {
  final String symbole;
  final String nom;
  final String codeIso;

  const InfoDevise({
    required this.symbole,
    required this.nom,
    required this.codeIso,
  });
}

const Map<String, InfoDevise> devisesParPays = {
  // Zone UEMOA (Franc CFA Ouest-Africain)
  'CI': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF'),
  'SN': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF'),
  'ML': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF'),
  'BF': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF'),
  'TG': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF'),
  'BJ': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF'),
  'NE': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF'),
  'GW': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF'),
  // Zone CEMAC (Franc CFA Afrique Centrale)
  'CM': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF'),
  'GA': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF'),
  'TD': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF'),
  'CG': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF'),
  'GQ': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF'),
  'CF': InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BEAC)', codeIso: 'XAF'),
  // Autres devises africaines courantes
  'NG': InfoDevise(symbole: '₦', nom: 'Naira nigérian', codeIso: 'NGN'),
  'GH': InfoDevise(symbole: 'GH₵', nom: 'Cedi ghanéen', codeIso: 'GHS'),
  'MA': InfoDevise(symbole: 'DH', nom: 'Dirham marocain', codeIso: 'MAD'),
  'DZ': InfoDevise(symbole: 'DA', nom: 'Dinar algérien', codeIso: 'DZD'),
  'TN': InfoDevise(symbole: 'DT', nom: 'Dinar tunisien', codeIso: 'TND'),
  'CD': InfoDevise(symbole: 'FC', nom: 'Franc congolais', codeIso: 'CDF'),
  'KE': InfoDevise(symbole: 'KSh', nom: 'Shilling kényan', codeIso: 'KES'),
  'RW': InfoDevise(symbole: 'FRw', nom: 'Franc rwandais', codeIso: 'RWF'),
  'GN': InfoDevise(symbole: 'FG', nom: 'Franc guinéen', codeIso: 'GNF'),
  // Devises internationales majeures
  'FR': InfoDevise(symbole: '€', nom: 'Euro', codeIso: 'EUR'),
  'BE': InfoDevise(symbole: '€', nom: 'Euro', codeIso: 'EUR'),
  'US': InfoDevise(symbole: '\$', nom: 'Dollar américain', codeIso: 'USD'),
  'GB': InfoDevise(symbole: '£', nom: 'Livre sterling', codeIso: 'GBP'),
  'CA': InfoDevise(symbole: 'CA\$', nom: 'Dollar canadien', codeIso: 'CAD'),
};

const InfoDevise deviseParDefaut =
    InfoDevise(symbole: 'FCFA', nom: 'Franc CFA (BCEAO)', codeIso: 'XOF');

InfoDevise deviseSelonPays(String codePays) {
  return devisesParPays[codePays.toUpperCase()] ?? deviseParDefaut;
}
