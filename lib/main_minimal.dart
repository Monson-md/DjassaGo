import 'package:flutter/material.dart';

/// Point d'entrée minimal, utilisé uniquement pour le diagnostic du
/// crash silencieux au démarrage (voir CHECKLIST.md). Ne fait
/// STRICTEMENT rien d'autre que runApp sur un écran uni : aucun Hive,
/// aucun service, aucun provider, aucun accès disque.
///
/// Si l'APK construit à partir de ce fichier (-t lib/main_minimal.dart)
/// s'ouvre normalement sur un appareil réel, la couche native est saine
/// et le problème vient de l'initialisation Dart dans lib/main.dart.
/// S'il plante aussi, le problème est purement natif (configuration
/// Android), indépendant de tout code Dart.
void main() {
  runApp(const _AppMinimale());
}

class _AppMinimale extends StatelessWidget {
  const _AppMinimale();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Le démarrage fonctionne',
            style: TextStyle(fontSize: 20, color: Colors.black),
          ),
        ),
      ),
    );
  }
}
