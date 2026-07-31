// Test de la Phase Conditionnements : modifier un conditionnement après une
// vente ne doit jamais changer l'historique déjà enregistré (nom, quantité
// et prix figés dans l'ItemVendu au moment de la vente).

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
        .createTemp('caisse_de_poche_conditionnement_historique_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('modifier un conditionnement après une vente ne change jamais l\'historique',
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

    // Le commerçant change son casier : 24 bouteilles à 2400 désormais.
    await conditionnementService.remplacerPour(
      produitId: coca.id,
      brouillons: const [
        ConditionnementBrouillon(
          nom: 'Casier',
          quantiteEnUniteBase: 24,
          prixVente: 2400,
          parDefaut: true,
        ),
      ],
      devise: 'XOF',
    );

    final itemHistorique = transaction.itemsVendus.first;
    expect(itemHistorique.conditionnementNom, 'Casier');
    expect(itemHistorique.quantiteEnUniteBase, 20);
    expect(itemHistorique.prixUnitaireVente, 2000);
    expect(transaction.montantTotal, 2000);
    expect(transaction.margeBrute, 500);
  });
}
