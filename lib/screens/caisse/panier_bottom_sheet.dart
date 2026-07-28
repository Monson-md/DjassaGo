import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/caisse_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/produit_provider.dart';
import '../../utils/formatage.dart';

/// Contenu du panier avant validation de la vente.
/// Renvoie `true` via Navigator.pop si une vente a été finalisée.
class PanierBottomSheet extends StatefulWidget {
  const PanierBottomSheet({super.key});

  @override
  State<PanierBottomSheet> createState() => _PanierBottomSheetState();
}

class _PanierBottomSheetState extends State<PanierBottomSheet> {
  bool _validationEnCours = false;

  Future<void> _validerVente() async {
    final caisseProvider = context.read<CaisseProvider>();
    final devise = context.read<CurrencyProvider>().codeIsoDevise;

    setState(() => _validationEnCours = true);
    try {
      final transaction = await caisseProvider.finaliserVente(devise: devise);
      if (!mounted) return;
      context.read<ProduitProvider>().charger();
      Navigator.of(context).pop(true);
      _afficherRecu(transaction.montantTotal, transaction.beneficeNet);
    } catch (e) {
      setState(() => _validationEnCours = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _afficherRecu(double total, double benefice) {
    final devise = context.read<CurrencyProvider>().symboleDevise;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: const Text('Vente enregistrée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total encaissé : ${formaterMontant(total, symbole: devise)}'),
            const SizedBox(height: 4),
            Text('Bénéfice net : ${formaterMontant(benefice, symbole: devise)}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caisse = context.watch<CaisseProvider>();
    final devise = context.watch<CurrencyProvider>().symboleDevise;
    final panier = caisse.panier;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Panier',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: panier.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = panier[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.nomProduit),
                        subtitle: Text(
                          formaterMontant(item.prixUnitaireVente, symbole: devise),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => caisse.modifierQuantite(
                                  index, item.quantite - 1),
                            ),
                            Text('${item.quantite}',
                                style: const TextStyle(fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => caisse.modifierQuantite(
                                  index, item.quantite + 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 16)),
                          Text(
                            formaterMontant(caisse.totalPanier, symbole: devise),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: panier.isEmpty || _validationEnCours
                              ? null
                              : _validerVente,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _validationEnCours
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Valider la vente'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
