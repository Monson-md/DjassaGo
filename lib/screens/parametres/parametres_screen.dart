import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../services/sync_service.dart';
import '../../widgets/banniere_pub.dart';

/// Écran de paramètres : informations sur le commerce, synchronisation
/// manuelle, et emplacement de la publicité (jamais sur l'écran de Caisse).
class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  final _syncService = SyncService();
  bool _synchronisationEnCours = false;

  Future<void> _synchroniserMaintenant() async {
    setState(() => _synchronisationEnCours = true);
    await _syncService.synchroniserMaintenant();
    if (!mounted) return;
    setState(() => _synchronisationEnCours = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synchronisation effectuée (si connecté)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Pays'),
              subtitle: Text(currency.nomPays),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Devise'),
              subtitle: Text('${currency.devise.nom} (${currency.symboleDevise})'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_sync),
              title: const Text('Synchronisation cloud'),
              subtitle: const Text(
                'Vos données sont sauvegardées automatiquement dès qu\'une connexion est disponible.',
              ),
              trailing: _synchronisationEnCours
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: _synchroniserMaintenant,
                    ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: BannierePub()),
        ],
      ),
    );
  }
}
