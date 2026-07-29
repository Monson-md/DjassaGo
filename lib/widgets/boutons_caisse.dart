import 'package:flutter/material.dart';

/// Bouton d'action principale (ex: "Encaisser") : fond vert plein. La
/// cible tactile fait 48dp minimum de hauteur, imposé par le thème
/// global (voir lib/config/theme.dart) — ne jamais la réduire.
class BoutonPrincipal extends StatelessWidget {
  const BoutonPrincipal({
    super.key,
    required this.texte,
    required this.onPressed,
    this.icone,
  });

  final String texte;
  final VoidCallback? onPressed;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final enfant = icone == null
        ? Text(texte)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icone, size: 18), const SizedBox(width: 8), Text(texte)],
          );
    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: enfant),
    );
  }
}

/// Bouton d'action secondaire (ex: "Mettre en dette", "Annuler") :
/// contour encre, fond blanc. Même gabarit que [BoutonPrincipal] pour
/// s'aligner proprement à côté de lui dans les rangées d'actions.
class BoutonFantome extends StatelessWidget {
  const BoutonFantome({
    super.key,
    required this.texte,
    required this.onPressed,
    this.icone,
  });

  final String texte;
  final VoidCallback? onPressed;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final enfant = icone == null
        ? Text(texte)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icone, size: 18), const SizedBox(width: 8), Text(texte)],
          );
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: enfant),
    );
  }
}
