import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/produit.dart';
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';

/// Tuile produit de la grille Caisse (3 colonnes). Purement présentative :
/// la logique de refus d'ajout pour un produit en rupture appartient à
/// l'écran, pas à la tuile (voir DESIGN.md).
class TuileProduit extends StatelessWidget {
  const TuileProduit({
    super.key,
    required this.produit,
    required this.devise,
    this.quantiteDansPanier = 0,
    this.onTap,
  });

  final Produit produit;
  final InfoDevise devise;
  final int quantiteDansPanier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enRupture = produit.enRupture;
    final stockBas = produit.stockFaible && !enRupture;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CaisseRadius.liste),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: stockBas ? const Color(0xFFFFF9F2) : CaisseColors.carte,
            border: Border.all(
              color: stockBas ? const Color(0xFFEEC9A8) : CaisseColors.ligne,
            ),
            borderRadius: BorderRadius.circular(CaisseRadius.liste),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (quantiteDansPanier > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: CaisseColors.vert,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$quantiteDansPanier',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              Text(
                produit.nom,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CaisseColors.encre,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formaterMontantMineur(
                      produit.prixVenteMineur,
                      decimales: devise.decimales,
                      symbole: devise.symbole,
                    ),
                    style: CaisseTypographie.montantPetit,
                  ),
                  Text(
                    enRupture ? 'Rupture' : '${produit.stockActuel} en stock',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: enRupture ? CaisseColors.brique : CaisseColors.sourdine,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
