import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pin_provider.dart';

/// Panneau « code PIN oublié » intégré au voile de verrouillage.
///
/// Il ne s'ouvre plus via `showModalBottomSheet` : le voile est au-dessus du
/// Navigator racine et n'a pas de Navigator ancêtre. Le panneau appelle les
/// mêmes méthodes du [PinProvider] que l'ancienne feuille (question,
/// vérification de la réponse, réinitialisation).
class RecuperationPinPanel extends StatefulWidget {
  const RecuperationPinPanel({super.key, required this.onAnnuler});

  final VoidCallback onAnnuler;

  @override
  State<RecuperationPinPanel> createState() => _RecuperationPinPanelState();
}

class _RecuperationPinPanelState extends State<RecuperationPinPanel> {
  final _reponseController = TextEditingController();
  final _nouveauPinController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _question;
  bool _questionIndisponible = false;
  bool _reponseValidee = false;
  String? _erreur;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _chargerQuestion();
  }

  Future<void> _chargerQuestion() async {
    try {
      final question = await context.read<PinProvider>().question();
      if (!mounted) return;
      setState(() {
        _question = question;
        _questionIndisponible = question == null || question.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _questionIndisponible = true);
    }
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
    try {
      final ok = await context.read<PinProvider>().verifierReponse(
        _reponseController.text,
      );
      if (!mounted) return;
      setState(() {
        _enCours = false;
        if (ok) {
          _reponseValidee = true;
        } else {
          _erreur = 'Réponse incorrecte.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = 'Stockage sécurisé indisponible.';
      });
    }
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
    try {
      await context.read<PinProvider>().reinitialiserPinAvecReponse(pin);
      if (!mounted) return;
      // Le provider a normalement déjà retiré le voile. S'il est resté
      // verrouillé (application en arrière-plan pendant l'écriture), on
      // revient à la saisie du PIN pour que le nouveau code soit utilisable.
      widget.onAnnuler();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = 'Stockage sécurisé indisponible.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionChargee = _question != null && !_questionIndisponible;
    final boutonActif =
        !_enCours &&
        (_reponseValidee || (questionChargee && _question != null));

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _enCours ? null : widget.onAnnuler,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Retour',
              ),
              Expanded(
                child: Text(
                  _reponseValidee ? 'Nouveau code PIN' : 'Code PIN oublié',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          if (_questionIndisponible) ...[
            const Text(
              'Récupération indisponible : le stockage sécurisé est '
              'illisible.',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ] else if (!_reponseValidee) ...[
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
              decoration: const InputDecoration(labelText: 'Nouveau code PIN'),
            ),
            TextField(
              controller: _confirmationController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Confirmer le code PIN',
              ),
            ),
          ],
          if (_erreur != null) ...[
            const SizedBox(height: 4),
            Text(_erreur!, style: const TextStyle(color: Colors.red)),
          ],
          if (!_questionIndisponible) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: boutonActif
                  ? (_reponseValidee ? _validerNouveauPin : _validerReponse)
                  : null,
              child: _enCours
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_reponseValidee ? 'Valider' : 'Continuer'),
            ),
          ],
        ],
      ),
    );
  }
}
