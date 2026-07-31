import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/caisse_provider.dart';
import 'providers/conditionnement_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/depense_provider.dart';
import 'providers/dette_provider.dart';
import 'providers/pin_provider.dart';
import 'providers/produit_provider.dart';
import 'screens/accueil/accueil_screen.dart';
import 'screens/accueil/onboarding_pays_screen.dart';
import 'screens/verrouillage/pin_lock_screen.dart';
import 'services/ad_service.dart';
import 'services/diagnostic_service.dart';
import 'services/hive_service.dart';
import 'services/sync_service.dart';

/// Point d'entrée de l'application.
///
/// Règle absolue : l'application ne doit jamais se fermer en silence au
/// démarrage. `runApp` est appelé immédiatement (voir _AppRacine) ; toute
/// initialisation lourde a lieu après le premier rendu, dans des étapes
/// nommées et isolées les unes des autres. Si une étape critique (Hive)
/// échoue, un écran de diagnostic lisible s'affiche à la place de l'app —
/// jamais un retour silencieux au launcher.
void main() {
  runZonedGuarded<void>(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      DiagnosticService.ajouter(
        'Flutter',
        details.exceptionAsString(),
        details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      DiagnosticService.ajouter('Uncaught (PlatformDispatcher)', '$error', stack);
      return true;
    };

    runApp(const _AppRacine());
  }, (error, stack) {
    DiagnosticService.ajouter('Uncaught (Zone)', '$error', stack);
  });
}

/// Racine réelle de l'application : affiche un état de chargement
/// instantané, puis pilote le démarrage étape par étape.
class _AppRacine extends StatefulWidget {
  const _AppRacine();

  @override
  State<_AppRacine> createState() => _AppRacineState();
}

class _AppRacineState extends State<_AppRacine> {
  bool _hivePret = false;
  bool _hiveEnErreur = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    setState(() {
      _hivePret = false;
      _hiveEnErreur = false;
    });

    // Seule étape bloquante : les Provider ci-dessous lisent des boxes
    // Hive dès leur construction, donc Hive doit être prêt avant
    // d'afficher l'app. C'est volontairement la seule étape critique.
    try {
      await HiveService.init();
    } catch (e, st) {
      DiagnosticService.ajouter('Hive.init', '$e', st);
      unawaited(DiagnosticService.sauvegarderSurDisque());
      if (!mounted) return;
      setState(() => _hiveEnErreur = true);
      return;
    }

    if (!mounted) return;
    setState(() => _hivePret = true);

    // Étapes non critiques, différées après le premier rendu. AdService
    // et SyncService sont aujourd'hui des implémentations neutres (voir
    // CHECKLIST.md : Firebase et Google Mobile Ads ont été retirés du
    // projet), mais la structure est conservée pour qu'une vraie
    // implémentation puisse être réintroduite sans changer ce fichier.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialiserEnArrierePlan());
  }

  Future<void> _initialiserEnArrierePlan() async {
    try {
      await AdService.instance.initialiser();
    } catch (e, st) {
      DiagnosticService.ajouter('AdService', '$e', st);
    }

    try {
      unawaited(SyncService().demarrer());
    } catch (e, st) {
      DiagnosticService.ajouter('SyncService.demarrer', '$e', st);
    }

    unawaited(DiagnosticService.sauvegarderSurDisque());
  }

  @override
  Widget build(BuildContext context) {
    if (_hiveEnErreur) {
      return _EcranDiagnostic(
        rapport: DiagnosticService.rapportComplet(),
        onContinuerQuandMeme: _demarrer,
      );
    }
    if (!_hivePret) {
      return const _EcranChargement();
    }
    return const CaisseDePocheApp();
  }
}

class _EcranChargement extends StatelessWidget {
  const _EcranChargement();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFFFCFAF5),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Écran affiché uniquement si une étape critique du démarrage (Hive)
/// échoue. Sans cet écran, l'échec fermerait l'app sans rien afficher,
/// ce qui est impossible à diagnostiquer sur un appareil réel sans
/// logcat. Le rapport est sélectionnable et copiable pour être transmis
/// tel quel.
class _EcranDiagnostic extends StatelessWidget {
  const _EcranDiagnostic({
    required this.rapport,
    required this.onContinuerQuandMeme,
  });

  final String rapport;
  final VoidCallback onContinuerQuandMeme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Erreur au démarrage de l'application",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Les données locales n'ont pas pu être chargées. Copiez "
                  'le rapport ci-dessous et transmettez-le pour le corriger.',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      rapport,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rapport));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Rapport copié')),
                          );
                        },
                        child: const Text('Copier le rapport'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onContinuerQuandMeme,
                        child: const Text('Continuer quand même'),
                      ),
                    ),
                  ],
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
        ChangeNotifierProvider(create: (_) => ConditionnementProvider()),
        ChangeNotifierProvider(create: (_) => CaisseProvider()),
        ChangeNotifierProvider(create: (_) => DetteProvider()),
        ChangeNotifierProvider(create: (_) => PinProvider()),
        ChangeNotifierProvider(create: (_) => DepenseProvider()),
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
/// sinon vers l'écran de verrouillage (si un code PIN est configuré) puis
/// l'écran d'accueil. Reverrouille l'application dès qu'elle repasse en
/// arrière-plan — le téléphone passe entre les mains des vendeurs et des
/// clients (voir Phase 5 de docs/PHASES.md).
class _EcranDemarrage extends StatefulWidget {
  const _EcranDemarrage();

  @override
  State<_EcranDemarrage> createState() => _EcranDemarrageState();
}

class _EcranDemarrageState extends State<_EcranDemarrage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<PinProvider>().verrouiller();
    }
  }

  @override
  Widget build(BuildContext context) {
    final premierLancementTermine =
        context.watch<CurrencyProvider>().premierLancementTermine;
    if (!premierLancementTermine) {
      return const OnboardingPaysScreen();
    }

    final pin = context.watch<PinProvider>();
    if (!pin.pret) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (pin.verrouille) {
      return const PinLockScreen();
    }
    return const AccueilScreen();
  }
}
