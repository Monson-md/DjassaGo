import 'package:caisse_de_poche/providers/pin_provider.dart';
import 'package:caisse_de_poche/screens/verrouillage/pin_lock_screen.dart';
import 'package:caisse_de_poche/services/pin_service.dart';
import 'package:caisse_de_poche/widgets/gardien_retour.dart';
import 'package:caisse_de_poche/widgets/verrouillage_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_stockage_securise.dart';

Widget _application(PinProvider pin) {
  return MultiProvider(
    providers: [ChangeNotifierProvider<PinProvider>.value(value: pin)],
    child: GardienRetour(
      pin: pin,
      child: MaterialApp(
        builder: (context, child) =>
            VerrouillageOverlay(child: child ?? const SizedBox.shrink()),
        home: const _EcranTest(),
      ),
    ),
  );
}

class _EcranTest extends StatelessWidget {
  const _EcranTest();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              label: 'accueil-sous-jacent',
              child: const SizedBox(width: 1, height: 1),
            ),
            const Focus(child: Text('ACCUEIL TEST')),
            ElevatedButton(
              key: const Key('push'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _RouteTest()),
              ),
              child: const Text('Pousser'),
            ),
            ElevatedButton(
              key: const Key('sheet'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const Text('FEUILLE TEST'),
              ),
              child: const Text('Feuille'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteTest extends StatelessWidget {
  const _RouteTest();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('ROUTE TEST')));
  }
}

Future<PinProvider> _pomper(
  WidgetTester tester, {
  required bool avecPin,
}) async {
  final stockage = FakeStockageSecurise();
  final service = PinService(stockage: stockage);
  if (avecPin) {
    await service.definirPin(
      '1234',
      question: 'Question secrète ?',
      reponse: 'reponse',
    );
  }
  final pin = PinProvider(service: service, delaiReessai: Duration.zero);
  addTearDown(pin.dispose);
  await tester.pumpWidget(_application(pin));
  await _laisserSeStabiliser(tester);
  return pin;
}

Future<void> _laisserSeStabiliser(
  WidgetTester tester, [
  Duration duree = const Duration(milliseconds: 350),
]) async {
  await tester.pump();
  await tester.pump(duree);
}

Future<void> _deverrouiller(WidgetTester tester, String code) async {
  final champ = find.descendant(
    of: find.byType(PinLockScreen),
    matching: find.byType(TextField),
  );
  expect(champ, findsOneWidget);
  await tester.enterText(champ, code);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Déverrouiller'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

Future<void> _verrouiller(WidgetTester tester, PinProvider pin) async {
  pin.verrouiller();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('voile affiché au démarrage à froid quand un PIN existe', (
    tester,
  ) async {
    final pin = await _pomper(tester, avecPin: true);

    expect(pin.verrouille, isTrue);
    expect(find.byType(PinLockScreen), findsOneWidget);
    expect(find.text('Application verrouillée'), findsOneWidget);
  });

  testWidgets('aucun voile sans PIN', (tester) async {
    final pin = await _pomper(tester, avecPin: false);

    expect(pin.verrouille, isFalse);
    expect(find.byType(PinLockScreen), findsNothing);
    expect(find.text('ACCUEIL TEST'), findsOneWidget);
  });

  testWidgets('voile au-dessus d\'une route poussée', (tester) async {
    final pin = await _pomper(tester, avecPin: true);
    await _deverrouiller(tester, '1234');

    await tester.tap(find.byKey(const Key('push')));
    await _laisserSeStabiliser(tester);
    expect(find.text('ROUTE TEST'), findsOneWidget);

    await _verrouiller(tester, pin);
    expect(find.byType(PinLockScreen), findsOneWidget);
    // La route est toujours dans l'arbre, sous le voile.
    expect(find.text('ROUTE TEST'), findsOneWidget);

    await _deverrouiller(tester, '1234');
    expect(find.byType(PinLockScreen), findsNothing);
    expect(find.text('ROUTE TEST'), findsOneWidget);
  });

  testWidgets('voile au-dessus d\'une feuille modale', (tester) async {
    final pin = await _pomper(tester, avecPin: true);
    await _deverrouiller(tester, '1234');

    await tester.tap(find.byKey(const Key('sheet')));
    await _laisserSeStabiliser(tester);
    expect(find.text('FEUILLE TEST'), findsOneWidget);

    await _verrouiller(tester, pin);
    expect(find.byType(PinLockScreen), findsOneWidget);
    expect(find.text('FEUILLE TEST'), findsOneWidget);

    await _deverrouiller(tester, '1234');
    expect(find.byType(PinLockScreen), findsNothing);
    expect(find.text('FEUILLE TEST'), findsOneWidget);
  });

  testWidgets('bouton retour système bloqué pendant le verrou', (tester) async {
    final pin = await _pomper(tester, avecPin: true);
    await _deverrouiller(tester, '1234');

    await tester.tap(find.byKey(const Key('push')));
    await _laisserSeStabiliser(tester);
    expect(find.text('ROUTE TEST'), findsOneWidget);

    await _verrouiller(tester, pin);
    await tester.binding.handlePopRoute();
    await _laisserSeStabiliser(tester);

    expect(find.byType(PinLockScreen), findsOneWidget);
    expect(find.text('ROUTE TEST'), findsOneWidget);
  });

  testWidgets('appui long dans le champ PIN : aucune exception (Overlay)', (
    tester,
  ) async {
    await _pomper(tester, avecPin: true);

    final champ = find.descendant(
      of: find.byType(PinLockScreen),
      matching: find.byType(TextField),
    );
    await tester.enterText(champ, '1234');
    await tester.pump();
    await tester.longPress(champ);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('contenu sous-jacent exclu du focus et de la sémantique', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await _pomper(tester, avecPin: true);

    final focus = Focus.of(tester.element(find.text('ACCUEIL TEST')));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(find.bySemanticsLabel('accueil-sous-jacent'), findsNothing);

    await _deverrouiller(tester, '1234');
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(find.bySemanticsLabel('accueil-sous-jacent'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('mauvais PIN puis bon PIN', (tester) async {
    await _pomper(tester, avecPin: true);

    final champ = find.descendant(
      of: find.byType(PinLockScreen),
      matching: find.byType(TextField),
    );
    await tester.enterText(champ, '0000');
    await tester.tap(find.widgetWithText(FilledButton, 'Déverrouiller'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Code incorrect.'), findsOneWidget);
    expect(find.byType(PinLockScreen), findsOneWidget);

    await _deverrouiller(tester, '1234');
    expect(find.byType(PinLockScreen), findsNothing);
  });

  testWidgets('récupération intégrée : bonne réponse puis nouveau PIN', (
    tester,
  ) async {
    final pin = await _pomper(tester, avecPin: true);

    await tester.tap(find.widgetWithText(TextButton, 'Code PIN oublié ?'));
    await _laisserSeStabiliser(tester);
    expect(find.text('Question secrète ?'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'reponse');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
    await _laisserSeStabiliser(tester);
    expect(find.text('Nouveau code PIN'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), '5678');
    await tester.enterText(find.byType(TextField).at(1), '5678');
    await tester.tap(find.widgetWithText(FilledButton, 'Valider'));
    await _laisserSeStabiliser(tester);

    expect(find.byType(PinLockScreen), findsNothing);

    await _verrouiller(tester, pin);
    await _deverrouiller(tester, '5678');
    expect(find.byType(PinLockScreen), findsNothing);
  });

  testWidgets('paused verrouille', (tester) async {
    final pin = await _pomper(tester, avecPin: true);
    await _deverrouiller(tester, '1234');
    expect(find.byType(PinLockScreen), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // Le verrou est posé immédiatement, sans délai de grâce.
    expect(pin.verrouille, isTrue);

    // Les frames sont suspendues tant que l'app est en arrière-plan : le
    // voile se matérialise au retour au premier plan.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _laisserSeStabiliser(tester);
    expect(find.byType(PinLockScreen), findsOneWidget);
  });

  testWidgets('hidden verrouille', (tester) async {
    final pin = await _pomper(tester, avecPin: true);
    await _deverrouiller(tester, '1234');
    expect(find.byType(PinLockScreen), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    expect(pin.verrouille, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _laisserSeStabiliser(tester);
    expect(find.byType(PinLockScreen), findsOneWidget);
  });

  testWidgets('stockage illisible : message, Réessayer, puis déverrouillage', (
    tester,
  ) async {
    final stockage = FakeStockageSecurise();
    final service = PinService(stockage: stockage);
    await service.definirPin(
      '1234',
      question: 'Question secrète ?',
      reponse: 'reponse',
    );
    stockage
      ..echecsLecture = 3
      ..erreurLecture = PlatformException(code: 'illisible');

    final pin = PinProvider(service: service, delaiReessai: Duration.zero);
    addTearDown(pin.dispose);
    await tester.pumpWidget(_application(pin));
    await _laisserSeStabiliser(tester);

    expect(pin.erreurStockage, isTrue);
    expect(find.text('Stockage sécurisé indisponible.'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Réessayer'));
    await _laisserSeStabiliser(tester);
    expect(pin.erreurStockage, isFalse);

    await _deverrouiller(tester, '1234');
    expect(find.byType(PinLockScreen), findsNothing);
  });

  testWidgets('plugin absent : aucun voile', (tester) async {
    final stockage = FakeStockageSecurise()
      ..echecsLecture = 999
      ..erreurLecture = MissingPluginException('plugin absent');
    final pin = PinProvider(
      service: PinService(stockage: stockage),
      delaiReessai: Duration.zero,
    );
    addTearDown(pin.dispose);

    await tester.pumpWidget(_application(pin));
    await _laisserSeStabiliser(tester);

    expect(pin.verrouille, isFalse);
    expect(find.byType(PinLockScreen), findsNothing);
    expect(find.text('ACCUEIL TEST'), findsOneWidget);
  });
}
