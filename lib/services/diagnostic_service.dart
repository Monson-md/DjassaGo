import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Collecte les erreurs survenues au démarrage de l'application et les
/// rend consultables depuis l'écran (EcranDiagnostic) et depuis les
/// Réglages, y compris lors d'un démarrage qui a par ailleurs réussi.
///
/// Existe uniquement pour rendre visible un échec qui, sans lui,
/// fermerait silencieusement l'application sur un appareil réel où
/// aucun logcat n'est disponible.
class DiagnosticService {
  DiagnosticService._();

  static final List<_EntreeDiagnostic> _entrees = [];

  static bool get aDesErreurs => _entrees.isNotEmpty;

  static void ajouter(String etape, String message, StackTrace? pile) {
    _entrees.add(_EntreeDiagnostic(etape, message, pile, DateTime.now()));
  }

  static String rapportComplet() {
    if (_entrees.isEmpty) {
      return 'Aucune erreur au démarrage.';
    }
    return _entrees
        .map((e) =>
            '=== ${e.etape} — ${e.date.toIso8601String()} ===\n${e.message}\n${e.pile ?? ''}')
        .join('\n\n');
  }

  /// Ajoute le rapport du démarrage courant au fichier diagnostic.log,
  /// sans jamais faire échouer l'application si l'écriture échoue
  /// (permissions, stockage plein...).
  static Future<void> sauvegarderSurDisque() async {
    try {
      final fichier = await _fichierLog();
      final entete = _entrees.isEmpty
          ? '--- Démarrage OK du ${DateTime.now().toIso8601String()} ---\n'
          : '--- Démarrage avec erreurs du ${DateTime.now().toIso8601String()} ---\n${rapportComplet()}\n';
      await fichier.writeAsString('$entete\n', mode: FileMode.append);
    } catch (_) {
      // Le journal est un outil de diagnostic secondaire : son échec ne
      // doit jamais empêcher l'application de démarrer.
    }
  }

  static Future<String> lireDepuisDisque() async {
    try {
      final fichier = await _fichierLog();
      if (!await fichier.exists()) {
        return 'Aucun journal de diagnostic pour le moment.';
      }
      return await fichier.readAsString();
    } catch (e) {
      return "Impossible de lire le journal de diagnostic : $e";
    }
  }

  static Future<File> _fichierLog() async {
    final dossier = await getApplicationDocumentsDirectory();
    return File('${dossier.path}/diagnostic.log');
  }
}

class _EntreeDiagnostic {
  final String etape;
  final String message;
  final StackTrace? pile;
  final DateTime date;

  _EntreeDiagnostic(this.etape, this.message, this.pile, this.date);
}
