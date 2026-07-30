import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/categorie_depense.dart';
import '../../providers/currency_provider.dart';
import '../../providers/depense_provider.dart';

String libelleCategorie(CategorieDepense categorie) {
  switch (categorie) {
    case CategorieDepense.loyer:
      return 'Loyer';
    case CategorieDepense.transport:
      return 'Transport';
    case CategorieDepense.electricite:
      return 'Électricité';
    case CategorieDepense.reapprovisionnement:
      return 'Réapprovisionnement';
    case CategorieDepense.autre:
      return 'Autre';
  }
}

/// Saisie rapide d'une dépense (loyer, transport, électricité,
/// réapprovisionnement, autre) — Phase 7 de docs/PHASES.md.
class DepenseFormSheet extends StatefulWidget {
  const DepenseFormSheet({super.key});

  @override
  State<DepenseFormSheet> createState() => _DepenseFormSheetState();
}

class _DepenseFormSheetState extends State<DepenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _libelleController = TextEditingController();
  final _montantController = TextEditingController();
  CategorieDepense _categorie = CategorieDepense.autre;
  bool _enCours = false;

  @override
  void dispose() {
    _libelleController.dispose();
    _montantController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enCours = true);
    final devise = context.read<CurrencyProvider>().codeIsoDevise;
    await context.read<DepenseProvider>().ajouter(
          libelle: _libelleController.text.trim(),
          montant:
              double.parse(_montantController.text.replaceAll(',', '.')),
          categorie: _categorie,
          devise: devise,
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
              Text('Nouvelle dépense',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _libelleController,
                decoration: const InputDecoration(labelText: 'Libellé'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montantController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CategorieDepense>(
                initialValue: _categorie,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: CategorieDepense.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(libelleCategorie(c)),
                        ))
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _categorie = c);
                },
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
