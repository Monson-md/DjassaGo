import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mode_paiement.dart';
import '../../models/transaction.dart' as model;
import '../../providers/caisse_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dette_provider.dart';
import '../../providers/produit_provider.dart';
import '../../utils/formatage.dart';
import '../../utils/money.dart';

/// Journal de toutes les ventes, y compris les transactions annulées :
/// une annulation (voir CaisseService.annulerTransaction) ne supprime
/// jamais physiquement une transaction, elle est seulement exclue des
/// statistiques du jour.
class JournalVentesScreen extends StatelessWidget {
  const JournalVentesScreen({super.key});

  Future<void> _confirmerAnnulation(
      BuildContext context, model.Transaction transaction) async {
    final motifController = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler cette vente ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Les articles vendus seront remis en stock. La vente reste consultable, elle est marquée annulée, jamais supprimée.'),
            const SizedBox(height: 12),
            TextField(
              controller: motifController,
              decoration: const InputDecoration(labelText: 'Motif'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(motifController.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (motif == null || motif.isEmpty || !context.mounted) return;

    try {
      await context.read<CaisseProvider>().annulerTransaction(
            transactionId: transaction.id,
            motif: motif,
          );
      if (!context.mounted) return;
      context.read<ProduitProvider>().charger();
      context.read<DetteProvider>().charger();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vente annulée, stock remis à jour')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _libelleModePaiement(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.especes:
        return 'Espèces';
      case ModePaiement.credit:
        return 'Crédit';
      case ModePaiement.mobileMoney:
        return 'Mobile Money';
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions =
        context.watch<CaisseProvider>().toutesLesTransactions();
    final devise = context.watch<CurrencyProvider>().devise;

    return Scaffold(
      appBar: AppBar(title: const Text('Journal des ventes')),
      body: transactions.isEmpty
          ? Center(
              child: Text(
                'Aucune vente enregistrée',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: transactions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final estCredit =
                    !transaction.annulee &&
                        transaction.modePaiement == ModePaiement.credit;
                final nomClient = estCredit
                    ? context
                        .read<DetteProvider>()
                        .trouverParTransactionId(transaction.id)
                        ?.nomClient
                    : null;
                return ListTile(
                  title: Text(
                    formaterMontantMineur(
                      transaction.montantTotalMineur,
                      decimales: devise.decimales,
                      symbole: devise.symbole,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: transaction.annulee
                          ? TextDecoration.lineThrough
                          : null,
                      color: transaction.annulee ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text(
                    transaction.annulee
                        ? "Annulée · ${transaction.motifAnnulation ?? ''}"
                        : '${formaterDate(transaction.date)} ${formaterHeure(transaction.date)} · '
                            '${_libelleModePaiement(transaction.modePaiement)}'
                            '${nomClient != null ? ' · $nomClient' : ''}',
                  ),
                  trailing: transaction.annulee
                      ? const Icon(Icons.block, color: Colors.grey)
                      : IconButton(
                          icon: const Icon(Icons.undo),
                          tooltip: 'Annuler cette vente',
                          onPressed: () =>
                              _confirmerAnnulation(context, transaction),
                        ),
                );
              },
            ),
    );
  }
}
