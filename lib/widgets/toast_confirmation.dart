import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Confirmation non bloquante (fond encre, texte papier, disparition
/// automatique) — jamais un AlertDialog sur l'écran Caisse : une vente
/// doit pouvoir s'enchaîner sans qu'un bouton "OK" soit nécessaire.
/// Reprend le comportement du toast de la maquette (3.4s, titre en gras
/// suivi d'une ligne de détail optionnelle).
void afficherToastCaisse(
  BuildContext context, {
  required String titre,
  String? details,
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: CaisseColors.encre,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 3400),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CaisseRadius.carte),
        ),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: CaisseColors.papier,
              ),
            ),
            if (details != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  details,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12.5,
                    color: CaisseColors.papier,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
}
