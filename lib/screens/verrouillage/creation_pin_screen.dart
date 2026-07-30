import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pin_provider.dart';

/// Configuration initiale du verrouillage par code PIN, depuis les
/// Paramètres : choix du PIN, confirmation, et question secrète pour la
/// récupération en cas d'oubli.
class CreationPinScreen extends StatefulWidget {
  const CreationPinScreen({super.key});

  @override
  State<CreationPinScreen> createState() => _CreationPinScreenState();
}

class _CreationPinScreenState extends State<CreationPinScreen> {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _questionController = TextEditingController();
  final _reponseController = TextEditingController();
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    _questionController.dispose();
    _reponseController.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final pin = _pinController.text.trim();
    final confirmation = _confirmationController.text.trim();
    final question = _questionController.text.trim();
    final reponse = _reponseController.text.trim();

    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      setState(() => _erreur = 'Le code PIN doit contenir 4 à 6 chiffres.');
      return;
    }
    if (pin != confirmation) {
      setState(() => _erreur = 'Les deux codes ne correspondent pas.');
      return;
    }
    if (question.isEmpty || reponse.isEmpty) {
      setState(() =>
          _erreur = 'La question secrète et sa réponse sont requises.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });
    await context
        .read<PinProvider>()
        .definirPin(pin, question: question, reponse: reponse);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verrouillage par code PIN activé')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activer le code PIN')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "L'application sera verrouillée à chaque lancement et à "
                'chaque retour au premier plan.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Code PIN (4 à 6 chiffres)'),
              ),
              TextField(
                controller: _confirmationController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Confirmer le code PIN'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Question secrète (utilisée si vous oubliez votre code)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question secrète',
                  hintText: 'ex : Nom de mon premier client ?',
                ),
              ),
              TextField(
                controller: _reponseController,
                decoration: const InputDecoration(labelText: 'Réponse'),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 8),
                Text(_erreur!, style: const TextStyle(color: Colors.red)),
              ],
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
                    : const Text('Activer le verrouillage'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
