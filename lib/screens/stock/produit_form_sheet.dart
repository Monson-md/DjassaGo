import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/produit.dart';
import '../../providers/currency_provider.dart';
import '../../providers/produit_provider.dart';

/// Formulaire d'ajout ou de modification d'un produit.
class ProduitFormSheet extends StatefulWidget {
  final Produit? produit;
  const ProduitFormSheet({super.key, this.produit});

  @override
  State<ProduitFormSheet> createState() => _ProduitFormSheetState();
}

class _ProduitFormSheetState extends State<ProduitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _prixAchatController;
  late final TextEditingController _prixVenteController;
  late final TextEditingController _stockController;
  bool _enCours = false;

  bool get _modeEdition => widget.produit != null;

  @override
  void initState() {
    super.initState();
    final p = widget.produit;
    _nomController = TextEditingController(text: p?.nom ?? '');
    _prixAchatController =
        TextEditingController(text: p != null ? p.prixAchat.toString() : '');
    _prixVenteController =
        TextEditingController(text: p != null ? p.prixVente.toString() : '');
    _stockController =
        TextEditingController(text: p != null ? p.stockActuel.toString() : '');
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prixAchatController.dispose();
    _prixVenteController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enCours = true);
    final provider = context.read<ProduitProvider>();
    final devise = context.read<CurrencyProvider>().codeIsoDevise;

    final prixAchat = double.parse(_prixAchatController.text.replaceAll(',', '.'));
    final prixVente = double.parse(_prixVenteController.text.replaceAll(',', '.'));
    final stock = int.parse(_stockController.text);

    if (_modeEdition) {
      final p = widget.produit!;
      p.nom = _nomController.text.trim();
      p.prixAchat = prixAchat;
      p.prixVente = prixVente;
      p.stockActuel = stock;
      await provider.modifier(p);
    } else {
      await provider.ajouter(
        nom: _nomController.text.trim(),
        prixAchat: prixAchat,
        prixVente: prixVente,
        stockActuel: stock,
        devise: devise,
      );
    }

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
              Text(
                _modeEdition ? 'Modifier le produit' : 'Nouveau produit',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(labelText: 'Nom du produit'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prixAchatController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Prix d'achat"),
                      validator: _validerNombre,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _prixVenteController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Prix de vente'),
                      validator: _validerNombre,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock actuel'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (int.tryParse(v) == null) return 'Nombre entier requis';
                  return null;
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

  String? _validerNombre(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requis';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Valeur invalide';
    return null;
  }
}
