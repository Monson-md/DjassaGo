import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pin_provider.dart';

/// Parcours « code PIN oublié » : vérifie la réponse à la question
/// secrète définie à la création du PIN, puis permet d'en choisir un
/// nouveau. Renvoie `true` via Navigator.pop si le PIN a été réinitialisé.
class RecuperationPinSheet extends StatefulWidget {
  const RecuperationPinSheet({super.key});

  @override
  State<RecuperationPinSheet> createState() => _RecuperationPinSheetState();
}

class _RecuperationPinSheetState extends State<RecuperationPinSheet> {
  final _reponseController = TextEditingController();
  final _nouveauPinController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _question;
  bool _reponseValidee = false;
  String? _erreur;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    context.read<PinProvider>().question().then((q) {
      if (mounted) setState(() => _question = q);
    });
  }

  @override
  void dispose() {
    _reponseController.dispose();
    _nouveauPinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _validerReponse() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final ok = await context
        .read<PinProvider>()
        .verifierReponse(_reponseController.text);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      if (ok) {
        _reponseValidee = true;
      } else {
        _erreur = 'Réponse incorrecte.';
      }
    });
  }

  Future<void> _validerNouveauPin() async {
    final pin = _nouveauPinController.text.trim();
    final confirmation = _confirmationController.text.trim();
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      setState(() => _erreur = 'Le PIN doit contenir 4 à 6 chiffres.');
      return;
    }
    if (pin != confirmation) {
      setState(() => _erreur = 'Les deux codes ne correspondent pas.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    await context.read<PinProvider>().reinitialiserPinAvecReponse(pin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _reponseValidee ? 'Nouveau code PIN' : 'Code PIN oublié',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (!_reponseValidee) ...[
              Text(_question ?? '...'),
              const SizedBox(height: 12),
              TextField(
                controller: _reponseController,
                decoration: const InputDecoration(labelText: 'Votre réponse'),
                autofocus: true,
              ),
            ] else ...[
              TextField(
                controller: _nouveauPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration:
                    const InputDecoration(labelText: 'Nouveau code PIN'),
              ),
              TextField(
                controller: _confirmationController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration:
                    const InputDecoration(labelText: 'Confirmer le code PIN'),
              ),
            ],
            if (_erreur != null) ...[
              const SizedBox(height: 4),
              Text(_erreur!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enCours
                  ? null
                  : (_reponseValidee ? _validerNouveauPin : _validerReponse),
              child: _enCours
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_reponseValidee ? 'Valider' : 'Continuer'),
            ),
          ],
        ),
      ),
    );
  }
}
