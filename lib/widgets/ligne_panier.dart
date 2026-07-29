import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';

/// Ligne d'un article dans le panier (feuille Caisse).
class LignePanier extends StatelessWidget {
  const LignePanier({
    super.key,
    required this.nomProduit,
    required this.quantite,
    required this.montantMineur,
    required this.devise,
    this.onRetirer,
  });

  final String nomProduit;
  final int quantite;
  final int montantMineur;
  final InfoDevise devise;
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: CaisseColors.encre,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$quantite×',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            nomProduit,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: CaisseColors.encre,
            ),
          ),
        ),
        Text(
          formaterMontantMineur(montantMineur,
              decimales: devise.decimales, symbole: devise.symbole),
          style: CaisseTypographie.stylerMontant(taille: 13),
        ),
        IconButton(
          onPressed: onRetirer,
          icon: const Icon(Icons.close, size: 18, color: CaisseColors.sourdine),
          visualDensity: VisualDensity.compact,
          tooltip: 'Retirer',
        ),
      ],
    );
  }
}
