import 'package:flutter/material.dart';

import '../config/theme.dart';

enum VarianteStat { neutre, positive, negative }

/// Carte statistique générique (Bilan, Stock, tableau de bord Caisse) :
/// une étiquette au-dessus, un montant ou un nombre en gros en dessous.
class CarteStat extends StatelessWidget {
  const CarteStat({
    super.key,
    required this.etiquette,
    required this.valeur,
    this.variante = VarianteStat.neutre,
    this.icone,
  });

  final String etiquette;
  final String valeur;
  final VarianteStat variante;
  final IconData? icone;

  Color get _couleurValeur => switch (variante) {
        VarianteStat.neutre => CaisseColors.encre,
        VarianteStat.positive => CaisseColors.vert,
        VarianteStat.negative => CaisseColors.brique,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: CaisseColors.carte,
        border: Border.all(color: CaisseColors.ligne),
        borderRadius: BorderRadius.circular(CaisseRadius.carte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icone != null) ...[
                Icon(icone, size: 14, color: CaisseColors.sourdine),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  etiquette,
                  overflow: TextOverflow.ellipsis,
                  style: CaisseTypographie.etiquette,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: CaisseTypographie.stylerMontant(taille: 21, couleur: _couleurValeur),
          ),
        ],
      ),
    );
  }
}
