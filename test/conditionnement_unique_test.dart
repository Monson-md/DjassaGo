// Test de la Phase Conditionnements : un produit à conditionnement unique
// (aucun conditionnement enregistré) se comporte exactement comme avant
// cette phase — voir ConditionnementService.conditionnementSynthetique.

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
        .createTemp('caisse_de_poche_conditionnement_unique_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('produit à conditionnement unique : comportement strictement identique à avant la phase',
      () async {
    final produitService = ProduitService();
    final conditionnementService = ConditionnementService();
    final caisseProvider = CaisseProvider();

    final sac = await produitService.ajouter(
      nom: 'Sac de riz',
      prixAchat: 8000,
      prixVente: 10000,
      stockActuel: 50,
      devise: 'XOF',
    );

    // Aucun conditionnement enregistré : le synthétique se comporte comme
    // l'unique conditionnement implicite d'avant cette phase.
    expect(conditionnementService.listerPour(sac.id), isEmpty);
    final synthetique = conditionnementService.conditionnementSynthetique(sac);
    expect(synthetique.quantiteEnUniteBase, 1);
    expect(synthetique.prixVente, sac.prixVente);

    caisseProvider.ajouterAuPanier(sac, synthetique, quantite: 3);
    final transaction = await caisseProvider.finaliserVente(devise: 'XOF');

    expect(transaction.montantTotal, 30000);
    expect(transaction.margeBrute, 6000);
    expect(produitService.trouverParId(sac.id)!.stockActuel, 47);
  });
}
