// Test de la Phase Conditionnements : vente de 20 bouteilles du même Coca
// que test/conditionnement_vente_casier_test.dart — même stock retiré, mais
// marge trois fois supérieure puisque vendu au détail.

import 'dart:io';

import 'package:caisse_de_poche/providers/caisse_provider.dart';
import 'package:caisse_de_poche/services/conditionnement_service.dart';
import 'package:caisse_de_poche/services/hive_service.dart';
import 'package:caisse_de_poche/services/produit_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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
        .createTemp('caisse_de_poche_conditionnement_bouteilles_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('vente de 20 bouteilles du même produit : même stock retiré, marge trois fois supérieure',
      () async {
    final produitService = ProduitService();
    final conditionnementService = ConditionnementService();
    final caisseProvider = CaisseProvider();

    final coca = await produitService.ajouter(
      nom: 'Coca',
      prixAchat: 75,
      prixVente: 2000,
      stockActuel: 100,
      devise: 'XOF',
      uniteBase: 'bouteille',
    );
    final bouteille = await conditionnementService.ajouter(
      produitId: coca.id,
      nom: 'Bouteille',
      quantiteEnUniteBase: 1,
      prixVente: 150,
      devise: 'XOF',
    );

    caisseProvider.ajouterAuPanier(coca, bouteille, quantite: 20);
    final transaction = await caisseProvider.finaliserVente(devise: 'XOF');

    // Même stock retiré que la vente d'un casier (20 bouteilles), mais une
    // marge trois fois supérieure : 1500 contre 500.
    expect(transaction.montantTotal, 3000);
    expect(transaction.margeBrute, 1500);
    expect(produitService.trouverParId(coca.id)!.stockActuel, 80);
  });
}
