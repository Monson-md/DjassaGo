import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pin_provider.dart';
import 'recuperation_pin_sheet.dart';

/// Écran de verrouillage plein écran, affiché au lancement et au retour
/// d'arrière-plan lorsqu'un code PIN est configuré. Volontairement sans
/// AppBar ni bouton retour : la seule sortie possible est un PIN correct
/// (ou le parcours de récupération).
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _pinController = TextEditingController();
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final ok = await context.read<PinProvider>().deverrouiller(pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _enCours = false;
        _erreur = 'Code incorrect.';
        _pinController.clear();
      });
    }
  }

  Future<void> _codeOublie() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const RecuperationPinSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.teal),
                const SizedBox(height: 16),
                Text('Application verrouillée',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'Code PIN',
                  ),
                  onSubmitted: (_) => _valider(),
                ),
                if (_erreur != null) ...[
                  const SizedBox(height: 4),
                  Text(_erreur!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _enCours ? null : _valider,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: _enCours
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Déverrouiller'),
                ),
                TextButton(
                  onPressed: _codeOublie,
                  child: const Text('Code PIN oublié ?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
