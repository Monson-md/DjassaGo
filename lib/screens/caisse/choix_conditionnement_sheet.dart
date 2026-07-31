import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/conditionnement.dart';
import '../../models/produit.dart';
import '../../providers/currency_provider.dart';
import '../../utils/money.dart';

/// Choix du format de vente pour un produit à plusieurs conditionnements
/// (ex: Bouteille ou Casier de Coca), ouvert par un appui long sur la tuile
/// produit de l'écran Caisse. Renvoie le [Conditionnement] choisi via
/// Navigator.pop, ou `null` si l'utilisateur ferme la feuille sans choisir.
class ChoixConditionnementSheet extends StatelessWidget {
  const ChoixConditionnementSheet({
    super.key,
    required this.produit,
    required this.conditionnements,
  });

  final Produit produit;
  final List<Conditionnement> conditionnements;

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<CurrencyProvider>().devise;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(produit.nom, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Choisir le format',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...conditionnements.map((c) => ListTile(
                  title: Text(c.nom),
                  subtitle: Text(
                      '${c.quantiteEnUniteBase} ${produit.uniteBase}${c.quantiteEnUniteBase > 1 ? 's' : ''}'),
                  trailing: Text(
                    formaterMontantMineur(
                      c.prixVenteMineur,
                      decimales: devise.decimales,
                      symbole: devise.symbole,
                    ),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onTap: () => Navigator.of(context).pop(c),
                )),
          ],
        ),
      ),
    );
  }
}
