import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pin_provider.dart';

enum _ModeGestion { menu, changer, desactiver }

/// Gestion du verrouillage une fois activé : changer le code PIN ou le
/// désactiver. Les deux actions exigent la saisie du PIN actuel.
class GererPinSheet extends StatefulWidget {
  const GererPinSheet({super.key});

  @override
  State<GererPinSheet> createState() => _GererPinSheetState();
}

class _GererPinSheetState extends State<GererPinSheet> {
  _ModeGestion _mode = _ModeGestion.menu;
  final _pinActuelController = TextEditingController();
  final _nouveauPinController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _pinActuelController.dispose();
    _nouveauPinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _changerPin() async {
    final pin = _nouveauPinController.text.trim();
    final confirmation = _confirmationController.text.trim();
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      setState(() => _erreur = 'Le code PIN doit contenir 4 à 6 chiffres.');
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
    final ok = await context
        .read<PinProvider>()
        .changerPin(_pinActuelController.text.trim(), pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code PIN mis à jour')),
      );
    } else {
      setState(() {
        _enCours = false;
        _erreur = 'Code PIN actuel incorrect.';
      });
    }
  }

  Future<void> _desactiver() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final ok = await context
        .read<PinProvider>()
        .desactiverVerrouillage(_pinActuelController.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verrouillage désactivé')),
      );
    } else {
      setState(() {
        _enCours = false;
        _erreur = 'Code PIN actuel incorrect.';
      });
    }
  }

  Widget _buildMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Verrouillage par code PIN',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('Changer le code PIN'),
          onTap: () => setState(() => _mode = _ModeGestion.changer),
        ),
        ListTile(
          leading: const Icon(Icons.lock_open, color: Colors.red),
          title: const Text('Désactiver le verrouillage'),
          onTap: () => setState(() => _mode = _ModeGestion.desactiver),
        ),
      ],
    );
  }

  Widget _buildFormulaire() {
    final changement = _mode == _ModeGestion.changer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          changement ? 'Changer le code PIN' : 'Désactiver le verrouillage',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pinActuelController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Code PIN actuel'),
        ),
        if (changement) ...[
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
            decoration:
                const InputDecoration(labelText: 'Confirmer le nouveau code'),
          ),
        ],
        if (_erreur != null) ...[
          const SizedBox(height: 4),
          Text(_erreur!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed:
              _enCours ? null : (changement ? _changerPin : _desactiver),
          style: changement
              ? null
              : FilledButton.styleFrom(backgroundColor: Colors.red),
          child: _enCours
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(changement ? 'Valider' : 'Désactiver'),
        ),
      ],
    );
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
        child: _mode == _ModeGestion.menu ? _buildMenu() : _buildFormulaire(),
      ),
    );
  }
}
