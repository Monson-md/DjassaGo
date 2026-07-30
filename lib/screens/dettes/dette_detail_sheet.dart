import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dette.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dette_provider.dart';
import '../../utils/money.dart';

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
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: context.read<DetteProvider>().genererMessageRelance(widget.dette),
    );
  }

  @override
  void dispose() {
    _montantPaiementController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _envoyerWhatsApp() async {
    final provider = context.read<DetteProvider>();
    final message = _messageController.text;
    final ok =
        await provider.envoyerRelanceWhatsApp(widget.dette, message: message);
    if (ok || !mounted) return;

    // Repli automatique : WhatsApp n'est pas installé (ou n'a pas pu être
    // ouvert), on tente le SMS avec le même message avant d'abandonner.
    final okSms =
        await provider.envoyerRelanceSms(widget.dette, message: message);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(okSms
            ? "WhatsApp indisponible, SMS ouvert à la place"
            : "Impossible d'ouvrir WhatsApp ou l'application SMS"),
      ),
    );
  }

  Future<void> _envoyerSms() async {
    final provider = context.read<DetteProvider>();
    final ok = await provider.envoyerRelanceSms(widget.dette,
        message: _messageController.text);
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
    final devise = context.watch<CurrencyProvider>().devise;
    final aUnTelephone = widget.dette.telephone.trim().isNotEmpty;

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
              'Montant dû : ${formaterMontantMineur(widget.dette.montantDuMineur, decimales: devise.decimales, symbole: devise.symbole)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text('Message de relance (modifiable)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: aUnTelephone ? _envoyerWhatsApp : null,
                    icon: const Icon(Icons.chat, color: Colors.green),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: aUnTelephone ? _envoyerSms : null,
                    icon: const Icon(Icons.sms),
                    label: const Text('SMS'),
                  ),
                ),
              ],
            ),
            if (!aUnTelephone) ...[
              const SizedBox(height: 6),
              Text(
                'Aucun numéro enregistré pour ce client.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
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
                      suffixText: devise.symbole,
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
