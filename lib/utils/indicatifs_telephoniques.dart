/// Indicatifs téléphoniques (sans le +) pour les pays couverts par
/// `devisesParPays` (lib/utils/devises_disponibles.dart). Sert de repli
/// pour les installations existantes qui ont choisi leur pays avant
/// l'introduction de la normalisation E.164 (Phase 6) et n'ont donc pas
/// encore d'indicatif enregistré — l'onboarding, lui, stocke directement
/// l'indicatif fourni par country_picker.
const Map<String, String> indicatifsParPays = {
  'CI': '225',
  'SN': '221',
  'ML': '223',
  'BF': '226',
  'TG': '228',
  'BJ': '229',
  'NE': '227',
  'GW': '245',
  'CM': '237',
  'GA': '241',
  'TD': '235',
  'CG': '242',
  'GQ': '240',
  'CF': '236',
  'NG': '234',
  'GH': '233',
  'MA': '212',
  'DZ': '213',
  'TN': '216',
  'CD': '243',
  'KE': '254',
  'RW': '250',
  'GN': '224',
  'FR': '33',
  'BE': '32',
  'US': '1',
  'GB': '44',
  'CA': '1',
};

const String indicatifParDefaut = '225';

String indicatifPourPays(String codePays) =>
    indicatifsParPays[codePays.toUpperCase()] ?? indicatifParDefaut;
