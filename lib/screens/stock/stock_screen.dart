import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/produit.dart';
import '../../providers/currency_provider.dart';
import '../../providers/produit_provider.dart';
import '../../utils/formatage.dart';
import 'produit_form_sheet.dart';

/// Gestion du stock : liste des produits, ajout, modification et
/// réapprovisionnement.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  void _ouvrirFormulaire(BuildContext context, {Produit? produit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProduitFormSheet(produit: produit),
    );
  }

  Future<void> _confirmerSuppression(BuildContext context, Produit produit) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text('« ${produit.nom} » sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme == true && context.mounted) {
      await context.read<ProduitProvider>().supprimer(produit.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final produits = context.watch<ProduitProvider>().produits;
    final devise = context.watch<CurrencyProvider>().symboleDevise;

    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: produits.isEmpty
          ? Center(
              child: Text(
                'Aucun produit. Appuyez sur + pour en ajouter.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: produits.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final produit = produits[index];
                return ListTile(
                  onTap: () => _ouvrirFormulaire(context, produit: produit),
                  title: Text(produit.nom),
                  subtitle: Text(
                    'Achat: ${formaterMontant(produit.prixAchat, symbole: devise)} · '
                    'Vente: ${formaterMontant(produit.prixVente, symbole: devise)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: produit.enRupture
                              ? Colors.red.shade50
                              : produit.stockFaible
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${produit.stockActuel} en stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: produit.enRupture
                                ? Colors.red
                                : produit.stockFaible
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _confirmerSuppression(context, produit),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _ouvrirFormulaire(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
