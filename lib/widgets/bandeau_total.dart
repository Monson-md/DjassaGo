import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';

/// Bandeau de total du panier : "Total" et le montant en très grand à
/// gauche, la marge en petit vert à droite. Séparé du contenu au-dessus
/// par un filet pointillé, comme dans la maquette.
class BandeauTotal extends StatelessWidget {
  const BandeauTotal({
    super.key,
    required this.totalMineur,
    required this.margeMineur,
    required this.devise,
  });

  final int totalMineur;
  final int margeMineur;
  final InfoDevise devise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CaisseColors.ligne)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total', style: CaisseTypographie.etiquette),
              Text(
                formaterMontantMineur(totalMineur,
                    decimales: devise.decimales, symbole: devise.symbole),
                style: CaisseTypographie.montantGrand,
              ),
            ],
          ),
          Text(
            'Marge ${formaterMontantMineur(margeMineur, decimales: devise.decimales, symbole: devise.symbole)}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CaisseColors.vert,
            ),
          ),
        ],
      ),
    );
  }
}
