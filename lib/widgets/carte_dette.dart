import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';

/// Ligne du carnet de dettes. En retard : fond et bordure brique,
/// initiales et texte de statut en brique, bouton Relancer inversé
/// (fond blanc / texte brique) — voir DESIGN.md.
class CarteDette extends StatelessWidget {
  const CarteDette({
    super.key,
    required this.nomClient,
    required this.texteStatut,
    required this.montantMineur,
    required this.devise,
    required this.enRetard,
    this.onTap,
    this.onRelancer,
  });

  final String nomClient;
  final String texteStatut;
  final int montantMineur;
  final InfoDevise devise;
  final bool enRetard;
  final VoidCallback? onTap;
  final VoidCallback? onRelancer;

  String get _initiales => nomClient
      .split(' ')
      .where((mot) => mot.isNotEmpty)
      .map((mot) => mot[0].toUpperCase())
      .take(2)
      .join();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CaisseRadius.carte),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: enRetard ? CaisseColors.briqueClair : CaisseColors.carte,
            border: Border.all(
              color: enRetard ? const Color(0xFFE9B8AF) : CaisseColors.ligne,
            ),
            borderRadius: BorderRadius.circular(CaisseRadius.carte),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enRetard ? CaisseColors.brique : CaisseColors.encre,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  _initiales,
                  style: const TextStyle(
                    fontFamily: 'BricolageGrotesque',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomClient,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: CaisseColors.encre,
                      ),
                    ),
                    Text(
                      texteStatut,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: enRetard ? FontWeight.w600 : FontWeight.w500,
                        color: enRetard ? CaisseColors.brique : CaisseColors.sourdine,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formaterMontantMineur(montantMineur,
                        decimales: devise.decimales, symbole: devise.symbole),
                    style: CaisseTypographie.stylerMontant(taille: 15),
                  ),
                  const SizedBox(height: 3),
                  Material(
                    color: enRetard ? Colors.white : CaisseColors.vertClair,
                    borderRadius: BorderRadius.circular(7),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: onRelancer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: Text(
                          'Relancer',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: enRetard ? CaisseColors.brique : CaisseColors.vert,
                          ),
                        ),
                      ),
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
