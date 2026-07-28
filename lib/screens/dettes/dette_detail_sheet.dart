import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dette.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dette_provider.dart';
import '../../utils/formatage.dart';

/// Détail d'une dette : aperçu du message de relance et actions rapides
/// (WhatsApp, SMS, enregistrement d'un paiement).
class DetteDetailSheet extends StatefulWidget {
  final Dette dette;
  const DetteDetailSheet({super.key, required this.dette});

  @override
  State<DetteDetailSheet> createState() => _DetteDetailSheetState();
}

class _DetteDetailSheetState extends State<DetteDetailSheet> {
  final _montantPaiementController = TextEditingController();

  @override
  void dispose() {
    _montantPaiementController.dispose();
    super.dispose();
  }

  Future<void> _envoyerWhatsApp() async {
    final provider = context.read<DetteProvider>();
    final ok = await provider.envoyerRelanceWhatsApp(widget.dette);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir WhatsApp")),
      );
    }
  }

  Future<void> _envoyerSms() async {
    final provider = context.read<DetteProvider>();
    final ok = await provider.envoyerRelanceSms(widget.dette);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'application SMS")),
      );
    }
  }

  Future<void> _enregistrerPaiement() async {
    final montant =
        double.tryParse(_montantPaiementController.text.replaceAll(',', '.'));
    if (montant == null || montant <= 0) return;
    await context.read<DetteProvider>().enregistrerPaiement(widget.dette, montant);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<CurrencyProvider>().symboleDevise;
    final message = context.read<DetteProvider>().genererMessageRelance(widget.dette);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.dette.nomClient,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Montant dû : ${formaterMontant(widget.dette.montantDu, symbole: devise)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _envoyerWhatsApp,
                    icon: const Icon(Icons.chat, color: Colors.green),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _envoyerSms,
                    icon: const Icon(Icons.sms),
                    label: const Text('SMS'),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text('Enregistrer un paiement',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _montantPaiementController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Montant reçu',
                      suffixText: devise,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _enregistrerPaiement,
                  child: const Text('Valider'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
