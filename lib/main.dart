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
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();

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

  runApp(const CaisseDePocheApp());
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
