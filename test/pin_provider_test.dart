import 'package:caisse_de_poche/providers/pin_provider.dart';
import 'package:caisse_de_poche/services/pin_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_stockage_securise.dart';

Future<void> _attendrePret(PinProvider pin) async {
  for (var i = 0; i < 200 && !pin.pret; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(
    pin.pret,
    isTrue,
    reason: 'PinProvider devrait avoir fini son chargement',
  );
}

Future<void> _attendrePretWidget(WidgetTester tester, PinProvider pin) async {
  for (var i = 0; i < 50 && !pin.pret; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(
    pin.pret,
    isTrue,
    reason: 'PinProvider devrait avoir fini son chargement',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MissingPluginException -> aucun PIN et aucun verrou', () async {
    final stockage = FakeStockageSecurise()
      ..echecsLecture = 999
      ..erreurLecture = MissingPluginException('plugin absent');
    final pin = PinProvider(
      service: PinService(stockage: stockage),
      delaiReessai: Duration.zero,
    );
    addTearDown(pin.dispose);

    await _attendrePret(pin);

    expect(pin.pinConfigure, isFalse);
    expect(pin.verrouille, isFalse);
    expect(pin.erreurStockage, isFalse);
    expect(stockage.lectures, 1);
  });

  test('PlatformException -> 3 tentatives puis fail-closed', () async {
    final stockage = FakeStockageSecurise()
      ..echecsLecture = 999
      ..erreurLecture = PlatformException(code: 'illisible');
    final pin = PinProvider(
      service: PinService(stockage: stockage),
      delaiReessai: Duration.zero,
    );
    addTearDown(pin.dispose);

    await _attendrePret(pin);

    expect(stockage.lectures, 3);
    expect(pin.pinConfigure, isTrue);
    expect(pin.verrouille, isTrue);
    expect(pin.erreurStockage, isTrue);
  });

  test('Réessayer après erreur réussit et permet de déverrouiller', () async {
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

    await _attendrePret(pin);
    expect(pin.erreurStockage, isTrue);
    expect(pin.verrouille, isTrue);

    await pin.recharger();
    expect(pin.erreurStockage, isFalse);
    expect(pin.verrouille, isTrue);

    expect(await pin.deverrouiller('1234'), isTrue);
    expect(pin.verrouille, isFalse);
  });

  testWidgets('definirPin pendant paused laisse verrouillé', (tester) async {
    final stockage = FakeStockageSecurise();
    final pin = PinProvider(
      service: PinService(stockage: stockage),
      delaiReessai: Duration.zero,
    );
    addTearDown(pin.dispose);
    await _attendrePretWidget(tester, pin);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    await pin.definirPin(
      '1234',
      question: 'Question secrète ?',
      reponse: 'reponse',
    );

    expect(pin.pinConfigure, isTrue);
    expect(pin.verrouille, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets('reinitialiserPinAvecReponse pendant paused laisse verrouillé', (
    tester,
  ) async {
    final stockage = FakeStockageSecurise();
    final service = PinService(stockage: stockage);
    await service.definirPin(
      '1234',
      question: 'Question secrète ?',
      reponse: 'reponse',
    );
    final pin = PinProvider(service: service, delaiReessai: Duration.zero);
    addTearDown(pin.dispose);
    await _attendrePretWidget(tester, pin);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    await pin.reinitialiserPinAvecReponse('5678');

    expect(pin.verrouille, isTrue);
    expect(await service.verifierPin('5678'), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });
}
