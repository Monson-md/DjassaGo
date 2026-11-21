// Tests du formulaire produit (mission I2) : Produit.prixVente doit être le
// prix d'une unité de base, à la création comme à l'édition, tandis que le
// prix du conditionnement saisi reste inchangé.

import 'dart:io';

import 'package:caisse_de_poche/models/conditionnement.dart';
import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/providers/conditionnement_provider.dart';
import 'package:caisse_de_poche/providers/currency_provider.dart';
import 'package:caisse_de_poche/providers/produit_provider.dart';
import 'package:caisse_de_poche/screens/stock/produit_form_sheet.dart';
import 'package:caisse_de_poche/services/conditionnement_service.dart';
import 'package:caisse_de_poche/services/hive_service.dart';
import 'package:caisse_de_poche/services/produit_service.dart';
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

Widget _application({Produit? produit}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ChangeNotifierProvider(create: (_) => ProduitProvider()),
      ChangeNotifierProvider(create: (_) => ConditionnementProvider()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      Scaffold(body: ProduitFormSheet(produit: produit)),
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _ouvrirFormulaire(WidgetTester tester, {Produit? produit}) async {
  await tester.pumpWidget(_application(produit: produit));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

Future<void> _enregistrer(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Enregistrer'));
  // Les écritures Hive sont de vraies E/S : le tap (et donc le callback
  // asynchrone _enregistrer) doit être déclenché dans la zone réelle de
  // runAsync, sinon la sauvegarde ne se termine jamais sous fake-async.
  await tester.runAsync(() async {
    await tester.tap(find.text('Enregistrer'));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;
  late ProduitService produitService;
  late ConditionnementService conditionnementService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'caisse_de_poche_produit_form_prix_unite_base_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    HiveService.reinitialiserPourTest();
    await HiveService.init();
    produitService = ProduitService();
    conditionnementService = ConditionnementService();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    HiveService.reinitialiserPourTest();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'création avec un casier de 20 à 2000 : prixVente = 100 par unité de base',
    (tester) async {
      await _ouvrirFormulaire(tester);

      await tester.enterText(find.byKey(const Key('produit_nom')), 'Coca');
      await tester.enterText(
        find.byKey(const Key('produit_unite_base')),
        'bouteille',
      );
      await tester.enterText(
        find.byKey(const Key('produit_achat_quantite')),
        '1',
      );
      await tester.enterText(find.byKey(const Key('produit_achat_prix')), '50');
      await tester.enterText(find.byKey(const Key('produit_stock')), '100');

      await tester.enterText(
        find.byKey(const Key('conditionnement_0_nom')),
        'Casier',
      );
      await tester.enterText(
        find.byKey(const Key('conditionnement_0_quantite')),
        '20',
      );
      await tester.enterText(
        find.byKey(const Key('conditionnement_0_prix')),
        '2000',
      );
      await tester.pump();

      // L'indication « Soit X par unité de base » est visible.
      expect(find.textContaining('par bouteille'), findsWidgets);

      await _enregistrer(tester);

      final produit = HiveService.produitsBox.values.single;
      expect(produit.nom, 'Coca');
      expect(produit.prixVente, 100);
      expect(produit.prixVenteMineur, 100);

      final conditionnements = conditionnementService.listerPour(produit.id);
      expect(conditionnements, hasLength(1));
      expect(conditionnements.single.nom, 'Casier');
      expect(conditionnements.single.quantiteEnUniteBase, 20);
      expect(conditionnements.single.prixVente, 2000);
    },
  );

  testWidgets(
    'édition d\'un produit existant : le prix de base est recalculé',
    (tester) async {
      // Produit historique : prixVente contient encore le prix du casier
      // (2000), pas celui de l'unité de base. Les écritures Hive doivent se
      // faire hors de la zone fake-async du testWidgets.
      late Produit produit;
      late Conditionnement casier;
      await tester.runAsync(() async {
        produit = await produitService.ajouter(
          nom: 'Coca',
          prixAchat: 50,
          prixVente: 2000,
          stockActuel: 100,
          devise: 'XOF',
          uniteBase: 'bouteille',
        );
        casier = await conditionnementService.ajouter(
          produitId: produit.id,
          nom: 'Casier',
          quantiteEnUniteBase: 20,
          prixVente: 2000,
          devise: 'XOF',
          parDefaut: true,
        );
      });

      await _ouvrirFormulaire(
        tester,
        produit: produitService.trouverParId(produit.id),
      );

      await _enregistrer(tester);

      final apres = produitService.trouverParId(produit.id)!;
      expect(apres.prixVente, 100);
      expect(apres.prixVenteMineur, 100);

      final conditionnements = conditionnementService.listerPour(produit.id);
      expect(conditionnements, hasLength(1));
      expect(conditionnements.single.id, casier.id);
      expect(conditionnements.single.prixVente, 2000);
    },
  );
}
