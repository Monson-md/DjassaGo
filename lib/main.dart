import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/caisse_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/dette_provider.dart';
import 'providers/produit_provider.dart';
import 'screens/accueil/accueil_screen.dart';
import 'screens/accueil/onboarding_pays_screen.dart';
import 'services/ad_service.dart';
import 'services/hive_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  // Toute la séquence de démarrage est protégée : une exception non
  // interceptée ici (avant le premier runApp) tue l'isolate principal
  // sans aucun écran d'erreur, même en debug — l'app se ferme
  // silencieusement. On capture donc explicitement Hive (bloquant et
  // indispensable) et on affiche un écran d'erreur lisible plutôt que
  // de laisser le processus mourir sans rien afficher.
  runZonedGuarded<void>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    Object? erreurDemarrage;
    StackTrace? traceDemarrage;
    try {
      await HiveService.init();
    } catch (e, st) {
      erreurDemarrage = e;
      traceDemarrage = st;
      debugPrint('Erreur critique au démarrage (Hive) : $e\n$st');
    }

    // Firebase et AdMob sont initialisés de façon non-bloquante : si le
    // projet n'a pas encore été configuré (pas de google-services.json /
    // GoogleService-Info.plist réels), l'application continue de
    // fonctionner intégralement hors-ligne.
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase non configuré : la synchronisation restera inactive
      // jusqu'à ce qu'un projet Firebase soit branché (voir SyncService).
    }

    unawaited(AdService.instance.initialiser());
    unawaited(SyncService().demarrer());

    if (erreurDemarrage != null) {
      runApp(_ErreurDemarrageApp(
        erreur: erreurDemarrage,
        stackTrace: traceDemarrage,
      ));
    } else {
      runApp(const CaisseDePocheApp());
    }
  }, (error, stack) {
    debugPrint('Erreur non interceptée : $error\n$stack');
  });
}

/// Écran affiché uniquement si l'initialisation locale (Hive) échoue.
/// Sans cet écran, une erreur de démarrage ferme l'app sans rien
/// afficher, ce qui est impossible à diagnostiquer sur un appareil réel.
class _ErreurDemarrageApp extends StatelessWidget {
  const _ErreurDemarrageApp({required this.erreur, this.stackTrace});

  final Object? erreur;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Erreur au démarrage de l'application",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Les données locales n'ont pas pu être chargées. "
                  'Redémarrez l\'application. Si le problème persiste, '
                  'contactez le support avec le message ci-dessous.',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      '$erreur\n\n$stackTrace',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CaisseDePocheApp extends StatelessWidget {
  const CaisseDePocheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => ProduitProvider()),
        ChangeNotifierProvider(create: (_) => CaisseProvider()),
        ChangeNotifierProvider(create: (_) => DetteProvider()),
      ],
      child: MaterialApp(
        title: 'Caisse de Poche',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          navigationBarTheme: const NavigationBarThemeData(
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
        ),
        home: const _EcranDemarrage(),
      ),
    );
  }
}

/// Redirige vers l'onboarding pays/devise si c'est le premier lancement,
/// sinon directement vers l'écran d'accueil.
class _EcranDemarrage extends StatelessWidget {
  const _EcranDemarrage();

  @override
  Widget build(BuildContext context) {
    final premierLancementTermine =
        context.watch<CurrencyProvider>().premierLancementTermine;
    return premierLancementTermine
        ? const AccueilScreen()
        : const OnboardingPaysScreen();
  }
}
