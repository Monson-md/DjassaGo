import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart' as model;
import '../../providers/caisse_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dette_provider.dart';

/// Sélection ou saisie rapide du client avant de convertir la vente en
/// cours en dette. Renvoie la [model.Transaction] créée via
/// Navigator.pop si la vente à crédit a été enregistrée, `null` sinon.
class MettreEnDetteSheet extends StatefulWidget {
  const MettreEnDetteSheet({super.key});

  @override
  State<MettreEnDetteSheet> createState() => _MettreEnDetteSheetState();
}

class _MettreEnDetteSheetState extends State<MettreEnDetteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  void _selectionnerClient(String nom, String telephone) {
    setState(() {
      _nomController.text = nom;
      _telephoneController.text = telephone;
    });
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    final devise = context.read<CurrencyProvider>().codeIsoDevise;

    setState(() => _enCours = true);
    try {
      final transaction =
          await context.read<CaisseProvider>().finaliserVenteACredit(
                devise: devise,
                nomClient: _nomController.text.trim(),
                telephone: _telephoneController.text.trim(),
              );
      if (!mounted) return;
      Navigator.of(context).pop<model.Transaction>(transaction);
    } catch (e) {
      setState(() => _enCours = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clients distincts déjà connus du carnet de dettes, pour retrouver un
    // client récurrent sans ressaisir ses coordonnées.
    final clientsExistants = <String, String>{};
    for (final dette in context.watch<DetteProvider>().dettes) {
      clientsExistants[dette.nomClient] = dette.telephone;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mettre en dette',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'La vente est enregistrée immédiatement ; le client paiera plus tard.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (clientsExistants.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Client existant',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: clientsExistants.entries
                      .map((e) => ActionChip(
                            label: Text(e.key),
                            onPressed: () =>
                                _selectionnerClient(e.key, e.value),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(labelText: 'Nom du client'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (WhatsApp/SMS)',
                  hintText: 'ex: +2250700000000',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _enCours ? null : _valider,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _enCours
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmer la dette'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
