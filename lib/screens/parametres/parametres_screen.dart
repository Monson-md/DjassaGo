import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/currency_provider.dart';
import '../../services/backup_service.dart';
import '../../services/diagnostic_service.dart';
import '../../services/sync_service.dart';
import '../../utils/formatage.dart';
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
  final _backupService = BackupService();
  bool _synchronisationEnCours = false;
  bool _exportEnCours = false;

  Future<void> _synchroniserMaintenant() async {
    setState(() => _synchronisationEnCours = true);
    await _syncService.synchroniserMaintenant();
    if (!mounted) return;
    setState(() => _synchronisationEnCours = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synchronisation cloud non configurée pour le moment')),
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

  Future<void> _exporter() async {
    setState(() => _exportEnCours = true);
    try {
      final fichier = await _backupService.exporter();
      if (!mounted) return;
      await _backupService.partager(fichier);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Échec de l'export : $e")),
      );
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  /// Import désactivé : file_picker a été retiré du projet (voir
  /// CHECKLIST.md — incompatible avec la migration Flutter "built-in
  /// Kotlin"). BackupService.analyserFichier/restaurer restent
  /// disponibles et fonctionnels ; il ne manque qu'un sélecteur de
  /// fichier pour les brancher à nouveau (candidat : file_selector,
  /// maintenu par l'équipe Flutter).
  void _importer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import de sauvegarde bientôt disponible')),
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
          if (_backupService.sauvegardeRecommandee())
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                title: const Text('Pensez à sauvegarder vos données'),
                subtitle: Text(
                  _backupService.derniereSauvegardeLe() == null
                      ? "Aucune sauvegarde n'a encore été faite."
                      : 'Dernière sauvegarde le '
                          '${formaterDate(_backupService.derniereSauvegardeLe()!)}.',
                ),
              ),
            ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Exporter une sauvegarde'),
                  subtitle: const Text(
                    'Produits, ventes et dettes dans un fichier à partager (WhatsApp, Drive, e-mail...).',
                  ),
                  trailing: _exportEnCours
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _exportEnCours ? null : _exporter,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.restore_outlined, color: Colors.grey.shade400),
                  title: const Text('Importer une sauvegarde'),
                  subtitle: const Text('Bientôt disponible.'),
                  trailing: const Icon(Icons.info_outline, size: 18),
                  onTap: _importer,
                ),
              ],
            ),
          ),
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
                "Non configurée. L'app fonctionne 100 % hors-ligne — utilisez l'export/import ci-dessus.",
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
