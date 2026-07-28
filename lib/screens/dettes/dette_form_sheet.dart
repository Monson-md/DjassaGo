import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../providers/dette_provider.dart';

/// Formulaire d'ajout rapide d'une dette au carnet.
class DetteFormSheet extends StatefulWidget {
  const DetteFormSheet({super.key});

  @override
  State<DetteFormSheet> createState() => _DetteFormSheetState();
}

class _DetteFormSheetState extends State<DetteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _montantController = TextEditingController();
  final _noteController = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _montantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enCours = true);
    final devise = context.read<CurrencyProvider>().codeIsoDevise;
    await context.read<DetteProvider>().ajouter(
          nomClient: _nomController.text.trim(),
          telephone: _telephoneController.text.trim(),
          montantDu: double.parse(_montantController.text.replaceAll(',', '.')),
          devise: devise,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Nouvelle dette', style: Theme.of(context).textTheme.titleLarge),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _montantController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant dû'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (optionnel)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _enCours ? null : _enregistrer,
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
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
