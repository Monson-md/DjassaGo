import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../services/diagnostic_service.dart';
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

  Future<void> _voirJournalDiagnostic() async {
    final contenu = await DiagnosticService.lireDepuisDisque();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Journal de diagnostic'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              contenu,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: contenu));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Journal copié')),
              );
            },
            child: const Text('Copier'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Journal de diagnostic'),
              subtitle: const Text(
                'Erreurs survenues au démarrage, à transmettre en cas de problème.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _voirJournalDiagnostic,
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: BannierePub()),
        ],
      ),
    );
  }
}
