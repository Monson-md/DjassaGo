import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import 'pastille_etat.dart';

enum EtatStock { sain, bas, rupture }

/// Ligne de l'écran Stock : barre colorée à gauche selon l'état, prix
/// d'achat/vente/marge sur une seule ligne de sous-texte, quantité en
/// gros à droite.
class LigneStock extends StatelessWidget {
  const LigneStock({
    super.key,
    required this.nom,
    required this.etat,
    required this.stockActuel,
    required this.prixAchatMineur,
    required this.prixVenteMineur,
    required this.margeMineur,
    required this.devise,
    this.onTap,
  });

  final String nom;
  final EtatStock etat;
  final int stockActuel;
  final int prixAchatMineur;
  final int prixVenteMineur;
  final int margeMineur;
  final InfoDevise devise;
  final VoidCallback? onTap;

  Color get _couleurBarre => switch (etat) {
        EtatStock.sain => CaisseColors.vert,
        EtatStock.bas => CaisseColors.ocre,
        EtatStock.rupture => CaisseColors.brique,
      };

  @override
  Widget build(BuildContext context) {
    String fmt(int m) => formaterMontantMineur(m,
        decimales: devise.decimales, symbole: devise.symbole);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CaisseRadius.liste),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: CaisseColors.carte,
            border: Border.all(color: CaisseColors.ligne),
            borderRadius: BorderRadius.circular(CaisseRadius.liste),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: _couleurBarre,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      nom,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CaisseColors.encre,
                      ),
                    ),
                    Text(
                      'Achat ${fmt(prixAchatMineur)} · Vente ${fmt(prixVenteMineur)} · Marge ${fmt(margeMineur)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: CaisseColors.sourdine,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (etat != EtatStock.sain)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PastilleEtat(
                    texte: etat == EtatStock.rupture ? 'Rupture' : 'Bas',
                    variante: etat == EtatStock.rupture
                        ? VariantePastille.alertePleine
                        : VariantePastille.avertissementPlein,
                  ),
                ),
              Text(
                '$stockActuel',
                style: CaisseTypographie.stylerMontant(
                  taille: 18,
                  couleur: etat == EtatStock.rupture ? CaisseColors.brique : CaisseColors.encre,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
