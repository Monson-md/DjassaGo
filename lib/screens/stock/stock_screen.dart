import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/conditionnement.dart';
import '../../models/produit.dart';
import '../../providers/conditionnement_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/produit_provider.dart';
import '../../utils/money.dart';
import 'produit_form_sheet.dart';

/// Stock d'un produit exprimé en unité de base, avec la conversion la plus
/// lisible pour le commerçant quand un conditionnement groupé existe
/// (« 47 bouteilles (2 casiers + 7) ») — voir docs du modèle Conditionnement.
String _texteStock(Produit produit, List<Conditionnement> conditionnements) {
  final pluriel = produit.stockActuel > 1 ? 's' : '';
  final base = '${produit.stockActuel} ${produit.uniteBase}$pluriel';

  final regroupements = conditionnements.where((c) => c.quantiteEnUniteBase > 1).toList()
    ..sort((a, b) => b.quantiteEnUniteBase.compareTo(a.quantiteEnUniteBase));
  if (regroupements.isEmpty) return base;

  final plusGrand = regroupements.first;
  final nGroupes = produit.stockActuel ~/ plusGrand.quantiteEnUniteBase;
  final reste = produit.stockActuel % plusGrand.quantiteEnUniteBase;
  if (nGroupes == 0) return base;

  final nomGroupe = plusGrand.nom.toLowerCase();
  final detail = reste > 0
      ? '$nGroupes $nomGroupe${nGroupes > 1 ? 's' : ''} + $reste'
      : '$nGroupes $nomGroupe${nGroupes > 1 ? 's' : ''}';
  return '$base ($detail)';
}

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
    final devise = context.watch<CurrencyProvider>().devise;
    final conditionnementProvider = context.watch<ConditionnementProvider>();

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
                final conditionnements =
                    conditionnementProvider.listerPour(produit);
                final conditionnementParDefaut = conditionnements
                    .firstWhere((c) => c.parDefaut, orElse: () => conditionnements.first);
                return ListTile(
                  onTap: () => _ouvrirFormulaire(context, produit: produit),
                  title: Text(produit.nom),
                  subtitle: Text(
                    'Achat: ${formaterMontantMineur(produit.prixAchatMineur, decimales: devise.decimales, symbole: devise.symbole)}/${produit.uniteBase} · '
                    'Vente ${conditionnementParDefaut.nom}: ${formaterMontantMineur(conditionnementParDefaut.prixVenteMineur, decimales: devise.decimales, symbole: devise.symbole)}',
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
                          _texteStock(produit, conditionnements),
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
