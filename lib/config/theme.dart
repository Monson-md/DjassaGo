import 'package:flutter/material.dart';

/// Palette exacte de Caisse de Poche, dérivée de design/maquette.html.
/// Toute nouvelle interface doit utiliser ces constantes plutôt que des
/// couleurs en dur. Voir DESIGN.md pour les règles d'usage.
///
/// Deux couleurs présentes dans le CSS de la maquette sont volontairement
/// absentes ici : `--nuit` (#131A1F) n'est que le fond de la page de démo
/// autour du mockup de téléphone, pas une couleur de l'app ; `--ink-2`
/// (#3A362C) est déclarée mais n'est utilisée nulle part dans la
/// maquette.
class CaisseColors {
  CaisseColors._();

  /// En-têtes, barre de navigation, texte principal.
  static const encre = Color(0xFF17150F);

  /// Fond des écrans.
  static const papier = Color(0xFFFCFAF5);

  /// Surfaces, tuiles, lignes de liste.
  static const carte = Color(0xFFFFFFFF);

  /// Bordures, séparateurs.
  static const ligne = Color(0xFFE4DFD3);

  /// Onglet actif, alerte stock bas.
  static const ocre = Color(0xFFE0A02B);

  /// Ocre sur fond clair (contraste du texte).
  static const ocreFonce = Color(0xFFB57C13);

  /// Encaisser, marge positive, état sain.
  static const vert = Color(0xFF1C6B57);

  /// Fond des éléments verts.
  static const vertClair = Color(0xFFE7F1ED);

  /// Retard, rupture, dépenses.
  static const brique = Color(0xFFAF3524);

  /// Fond des éléments briques.
  static const briqueClair = Color(0xFFFBEBE8);

  /// Texte secondaire, légendes.
  static const sourdine = Color(0xFF8A8474);

  /// Texte inactif de la barre de navigation (sur fond encre).
  static const navInactif = Color(0xFF7C7666);
}

/// Rayons standard. La maquette n'applique pas une règle unique "cartes
/// = 14 / listes = 12" à tout : `.card` et `.dette` (une ligne de liste,
/// mais généreusement paddée) utilisent bien 14, tandis que `.tile`
/// (tuile produit) et `.stock-l` (ligne de stock, dense) utilisent 12
/// malgré leur rôle de liste. La distinction réelle est donc entre
/// surfaces généreusement paddées (14) et éléments denses de
/// grille/liste (12), pas entre "carte" et "liste" au sens strict.
class CaisseRadius {
  CaisseRadius._();

  /// Cartes autonomes et lignes généreusement paddées (stat, dette).
  static const carte = 14.0;

  /// Éléments denses de grille/liste (tuile produit, ligne de stock).
  static const liste = 12.0;

  static const bouton = 11.0;
}

/// Espacements standard, tirés des valeurs récurrentes de la maquette.
class CaisseEspacement {
  CaisseEspacement._();

  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0;
}

/// Typographie : Bricolage Grotesque (graisses 700/800) pour les titres
/// d'écran et tous les montants ; Inter (400 à 700) pour tout le reste.
/// Les montants utilisent systématiquement des chiffres tabulaires pour
/// ne pas "danser" quand un total change.
class CaisseTypographie {
  CaisseTypographie._();

  static const _affichage = 'BricolageGrotesque';
  static const _texte = 'Inter';

  static const _chiffresTabulaires = [FontFeature.tabularFigures()];

  /// Titre d'écran dans l'en-tête (ex: "Caisse", "Panier").
  static const titreEcran = TextStyle(
    fontFamily: _affichage,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: CaisseColors.papier,
  );

  /// Petite légende en majuscules au-dessus d'un titre ou d'une valeur
  /// (ex: la date dans l'en-tête, "TOTAL", "VENTES AUJOURD'HUI").
  static const etiquette = TextStyle(
    fontFamily: _texte,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: CaisseColors.sourdine,
  );

  /// Très grand montant (résultat net du Bilan, ex: 40px dans la maquette).
  static const montantEnorme = TextStyle(
    fontFamily: _affichage,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    fontFeatures: _chiffresTabulaires,
    color: CaisseColors.papier,
  );

  /// Grand montant (total du panier, ex: 32px dans la maquette).
  static const montantGrand = TextStyle(
    fontFamily: _affichage,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    fontFeatures: _chiffresTabulaires,
    color: CaisseColors.encre,
  );

  /// Montant de taille moyenne (cartes stat, ex: 18-21px dans la maquette).
  static const montant = TextStyle(
    fontFamily: _affichage,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    fontFeatures: _chiffresTabulaires,
    color: CaisseColors.encre,
  );

  /// Petit montant (ligne de panier, prix de tuile produit).
  static const montantPetit = TextStyle(
    fontFamily: _affichage,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    fontFeatures: _chiffresTabulaires,
    color: CaisseColors.encre,
  );

  /// Variante libre pour une taille non prévue ci-dessus : garde la
  /// police d'affichage et les chiffres tabulaires, jamais le formatage
  /// générique du système.
  static TextStyle stylerMontant({
    required double taille,
    FontWeight poids = FontWeight.w800,
    Color couleur = CaisseColors.encre,
  }) {
    return TextStyle(
      fontFamily: _affichage,
      fontSize: taille,
      fontWeight: poids,
      fontFeatures: _chiffresTabulaires,
      color: couleur,
    );
  }

  static const corps = TextStyle(
    fontFamily: _texte,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: CaisseColors.encre,
  );

  static const corpsGras = TextStyle(
    fontFamily: _texte,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: CaisseColors.encre,
  );

  static const corpsSecondaire = TextStyle(
    fontFamily: _texte,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: CaisseColors.sourdine,
  );

  static const bouton = TextStyle(
    fontFamily: _texte,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
}

ThemeData construireThemeCaisseDePoche() {
  const colorScheme = ColorScheme.light(
    primary: CaisseColors.vert,
    onPrimary: Colors.white,
    primaryContainer: CaisseColors.vertClair,
    onPrimaryContainer: CaisseColors.vert,
    secondary: CaisseColors.ocre,
    onSecondary: CaisseColors.encre,
    error: CaisseColors.brique,
    onError: Colors.white,
    errorContainer: CaisseColors.briqueClair,
    onErrorContainer: CaisseColors.brique,
    surface: CaisseColors.papier,
    onSurface: CaisseColors.encre,
    surfaceContainerHighest: CaisseColors.carte,
    outline: CaisseColors.ligne,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: CaisseColors.papier,
    fontFamily: 'Inter',
    splashFactory: NoSplash.splashFactory,
    textTheme: const TextTheme(
      bodyMedium: CaisseTypographie.corps,
      bodySmall: CaisseTypographie.corpsSecondaire,
      titleLarge: CaisseTypographie.titreEcran,
      labelLarge: CaisseTypographie.bouton,
    ).apply(bodyColor: CaisseColors.encre, displayColor: CaisseColors.encre),
    appBarTheme: const AppBarTheme(
      backgroundColor: CaisseColors.encre,
      foregroundColor: CaisseColors.papier,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: CaisseTypographie.titreEcran,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: CaisseColors.carte,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: CaisseEspacement.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CaisseRadius.carte),
        side: const BorderSide(color: CaisseColors.ligne),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: CaisseColors.ligne,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CaisseColors.vert,
        foregroundColor: Colors.white,
        disabledBackgroundColor: CaisseColors.vert.withValues(alpha: 0.35),
        minimumSize: const Size(0, 48),
        textStyle: CaisseTypographie.bouton,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CaisseRadius.bouton),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CaisseColors.encre,
        backgroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        textStyle: CaisseTypographie.bouton,
        side: const BorderSide(color: CaisseColors.encre, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CaisseRadius.bouton),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CaisseColors.encre,
        minimumSize: const Size(0, 48),
        textStyle: CaisseTypographie.bouton,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CaisseColors.encre,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 19,
          color: states.contains(WidgetState.selected)
              ? CaisseColors.ocre
              : CaisseColors.navInactif,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? CaisseColors.ocre
              : CaisseColors.navInactif,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CaisseColors.carte,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CaisseRadius.bouton),
        borderSide: const BorderSide(color: CaisseColors.ligne),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CaisseRadius.bouton),
        borderSide: const BorderSide(color: CaisseColors.ligne),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CaisseRadius.bouton),
        borderSide: const BorderSide(color: CaisseColors.vert, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        color: CaisseColors.sourdine,
      ),
    ),
  );
}
