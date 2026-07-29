import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Les 4 variantes visuelles de pastille/étiquette d'état trouvées dans
/// la maquette — elles ne suivent pas un seul style, donc pas un seul
/// nom : `.pill` (avertissement plein, ex: "Bas"), `.pill.r` (alerte
/// pleine, ex: "Rupture"), `.tag.ok` (succès doux, ex: "Actif") et
/// `.tag.warn` (alerte douce, ex: "À faire", "Inactive").
enum VariantePastille { avertissementPlein, alertePleine, succesDoux, alerteDouce }

/// Petite pastille d'état (stock bas/rupture) ou étiquette de réglage
/// (actif/à faire). Texte court, une seule ligne, jamais de contenu
/// interactif à l'intérieur.
class PastilleEtat extends StatelessWidget {
  const PastilleEtat({
    super.key,
    required this.texte,
    this.variante = VariantePastille.avertissementPlein,
  });

  final String texte;
  final VariantePastille variante;

  @override
  Widget build(BuildContext context) {
    final (Color fond, Color texteCouleur) = switch (variante) {
      VariantePastille.avertissementPlein => (CaisseColors.ocre, CaisseColors.encre),
      VariantePastille.alertePleine => (CaisseColors.brique, Colors.white),
      VariantePastille.succesDoux => (CaisseColors.vertClair, CaisseColors.vert),
      VariantePastille.alerteDouce => (CaisseColors.briqueClair, CaisseColors.brique),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: texteCouleur,
        ),
      ),
    );
  }
}
