// Test de la Phase Conditionnements : vente d'un casier de Coca — stock et
// marge conformes à l'exemple de docs/PHASES.md (casier de 20 bouteilles
// acheté 1500, coût unitaire 75, vendu 2000 le casier -> marge 500).

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
        .createTemp('caisse_de_poche_conditionnement_casier_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('vente d\'un casier : stock et marge conformes à l\'exemple du casier de Coca',
      () async {
    final produitService = ProduitService();
    final conditionnementService = ConditionnementService();
    final caisseProvider = CaisseProvider();

    // Casier acheté 1500, contenant 20 bouteilles : coût unitaire = 75.
    final coca = await produitService.ajouter(
      nom: 'Coca',
      prixAchat: 75,
      prixVente: 2000,
      stockActuel: 100,
      devise: 'XOF',
      uniteBase: 'bouteille',
    );
    final casier = await conditionnementService.ajouter(
      produitId: coca.id,
      nom: 'Casier',
      quantiteEnUniteBase: 20,
      prixVente: 2000,
      devise: 'XOF',
      parDefaut: true,
    );

    caisseProvider.ajouterAuPanier(coca, casier);
    final transaction = await caisseProvider.finaliserVente(devise: 'XOF');

    expect(transaction.montantTotal, 2000);
    expect(transaction.margeBrute, 500);
    expect(produitService.trouverParId(coca.id)!.stockActuel, 80);
  });
}
