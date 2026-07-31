// Test de la Phase 10 : parcours panier -> encaissement. Ajoute un
// produit au panier par un vrai tap sur sa carte (parcours widget réel),
// puis valide la vente via CaisseProvider directement plutôt qu'en
// pilotant la feuille modale et le dialogue de reçu : cet enchaînement de
// routes animées (showModalBottomSheet puis showDialog) n'atteint jamais
// un état stable sous pumpAndSettle en environnement de test (testé et
// confirmé manuellement sur téléphone, voir CLAUDE.md Phase 3) — ce test
// vérifie la même logique métier (ajout widget-driven, décrément de
// stock, création de la transaction) sans dépendre de ce détail de test.

import 'dart:io';

import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/providers/caisse_provider.dart';
import 'package:caisse_de_poche/providers/conditionnement_provider.dart';
import 'package:caisse_de_poche/providers/currency_provider.dart';
import 'package:caisse_de_poche/providers/produit_provider.dart';
import 'package:caisse_de_poche/screens/caisse/caisse_screen.dart';
import 'package:caisse_de_poche/services/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final Directory _dir;
  _FakePathProviderPlatform(this._dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir.path;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp
        .createTemp('caisse_de_poche_panier_widget_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
    await HiveService.produitsBox.put(
      'p1',
      Produit(
        id: 'p1',
        nom: 'Sac de riz',
        prixAchat: 8000,
        prixVente: 10000,
        stockActuel: 10,
        devise: 'XOF',
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('ajouter un produit au panier puis encaisser', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CurrencyProvider()),
          ChangeNotifierProvider(create: (_) => ProduitProvider()),
          ChangeNotifierProvider(create: (_) => ConditionnementProvider()),
          ChangeNotifierProvider(create: (_) => CaisseProvider()),
        ],
        child: const MaterialApp(home: CaisseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Le produit créé en amont est visible sur l'écran Caisse.
    expect(find.text('Sac de riz'), findsOneWidget);

    // Ajoute le produit au panier par un vrai tap sur sa carte.
    await tester.tap(find.text('Sac de riz'));
    await tester.pump();

    final caisseProvider =
        tester.element(find.byType(CaisseScreen)).read<CaisseProvider>();
    expect(caisseProvider.nombreArticlesPanier, 1);
    expect(caisseProvider.totalPanier, 10000);

    // Valide la vente directement via le provider. tester.runAsync() est
    // nécessaire ici : finaliserVente() écrit réellement sur disque via
    // Hive, et une E/S réelle lancée depuis le corps d'un testWidgets (zone
    // fake-async) ne se termine jamais sans cet échappatoire — contrairement
    // à setUp()/tearDown(), qui s'exécutent hors de cette zone et où les
    // mêmes écritures Hive fonctionnent sans problème (voir HiveService.init
    // ci-dessus).
    final transaction =
        (await tester.runAsync(() => caisseProvider.finaliserVente(devise: 'XOF')))!;
    expect(transaction.montantTotal, 10000);
    expect(transaction.margeBrute, 2000);

    final transactions = HiveService.transactionsBox.values.toList();
    expect(transactions, hasLength(1));

    final produit = HiveService.produitsBox.get('p1')!;
    expect(produit.stockActuel, 9);
  });
}
