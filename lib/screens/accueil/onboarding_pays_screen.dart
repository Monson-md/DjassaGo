import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../utils/devises_disponibles.dart';
import '../accueil/accueil_screen.dart';

/// Écran affiché uniquement au tout premier lancement de l'application :
/// le commerçant choisit son pays, ce qui détermine automatiquement sa
/// devise de travail. Ce choix est stocké localement et n'est plus
/// redemandé ensuite.
class OnboardingPaysScreen extends StatefulWidget {
  const OnboardingPaysScreen({super.key});

  @override
  State<OnboardingPaysScreen> createState() => _OnboardingPaysScreenState();
}

class _OnboardingPaysScreenState extends State<OnboardingPaysScreen> {
  Country? _paysChoisi;
  bool _enCours = false;

  void _ouvrirSelecteurPays() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (country) {
        setState(() => _paysChoisi = country);
      },
    );
  }

  Future<void> _confirmer() async {
    final pays = _paysChoisi;
    if (pays == null) return;

    setState(() => _enCours = true);
    await context.read<CurrencyProvider>().definirPaysEtDevise(
          codePays: pays.countryCode,
          nomPays: pays.name,
        );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AccueilScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devise =
        _paysChoisi != null ? deviseSelonPays(_paysChoisi!.countryCode) : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 72, color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                'Bienvenue sur Caisse de Poche',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sélectionnez votre pays pour configurer votre devise. '
                'Cette information est enregistrée sur votre appareil, '
                'l\'application fonctionne 100% hors-ligne.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _ouvrirSelecteurPays,
                icon: const Icon(Icons.public),
                label: Text(_paysChoisi == null
                    ? 'Choisir mon pays'
                    : '${_paysChoisi!.flagEmoji} ${_paysChoisi!.name}'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (devise != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Devise détectée : ${devise.nom} (${devise.symbole})',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed:
                    _paysChoisi == null || _enCours ? null : _confirmer,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _enCours
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Commencer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
