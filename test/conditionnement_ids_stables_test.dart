// Tests des identifiants stables des conditionnements (mission I1) :
// remplacerPour met à jour un format existant par son id, crée les nouveaux
// et ne supprime que ceux réellement retirés.

import 'dart:io';

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
  late ProduitService produitService;
  late ConditionnementService conditionnementService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'caisse_de_poche_conditionnement_ids_stables_test',
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

  test('éditer sans changer un conditionnement conserve son id', () async {
    final produit = await produitService.ajouter(
      nom: 'Coca',
      prixAchat: 75,
      prixVente: 100,
      stockActuel: 100,
      devise: 'XOF',
      uniteBase: 'bouteille',
    );
    final casier = await conditionnementService.ajouter(
      produitId: produit.id,
      nom: 'Casier',
      quantiteEnUniteBase: 20,
      prixVente: 2000,
      devise: 'XOF',
      parDefaut: true,
    );
    final bouteille = await conditionnementService.ajouter(
      produitId: produit.id,
      nom: 'Bouteille',
      quantiteEnUniteBase: 1,
      prixVente: 150,
      devise: 'XOF',
    );

    final resultat = await conditionnementService.remplacerPour(
      produitId: produit.id,
      brouillons: [
        ConditionnementBrouillon(
          id: casier.id,
          nom: 'Casier',
          quantiteEnUniteBase: 20,
          prixVente: 2000,
          parDefaut: true,
        ),
        ConditionnementBrouillon(
          id: bouteille.id,
          nom: 'Bouteille',
          quantiteEnUniteBase: 1,
          prixVente: 150,
          parDefaut: false,
        ),
      ],
      devise: 'XOF',
    );

    expect(resultat.map((c) => c.id), containsAll([casier.id, bouteille.id]));
    final apres = conditionnementService.listerPour(produit.id);
    expect(apres, hasLength(2));
    expect(apres.map((c) => c.id), containsAll([casier.id, bouteille.id]));
  });

  test(
    'supprimer un conditionnement à l\'édition laisse les autres ids intacts',
    () async {
      final produit = await produitService.ajouter(
        nom: 'Coca',
        prixAchat: 75,
        prixVente: 100,
        stockActuel: 100,
        devise: 'XOF',
        uniteBase: 'bouteille',
      );
      final casier = await conditionnementService.ajouter(
        produitId: produit.id,
        nom: 'Casier',
        quantiteEnUniteBase: 20,
        prixVente: 2000,
        devise: 'XOF',
        parDefaut: true,
      );
      final bouteille = await conditionnementService.ajouter(
        produitId: produit.id,
        nom: 'Bouteille',
        quantiteEnUniteBase: 1,
        prixVente: 150,
        devise: 'XOF',
      );
      final carton = await conditionnementService.ajouter(
        produitId: produit.id,
        nom: 'Carton',
        quantiteEnUniteBase: 12,
        prixVente: 1500,
        devise: 'XOF',
      );

      await conditionnementService.remplacerPour(
        produitId: produit.id,
        brouillons: [
          ConditionnementBrouillon(
            id: casier.id,
            nom: 'Casier',
            quantiteEnUniteBase: 20,
            prixVente: 2000,
            parDefaut: true,
          ),
          ConditionnementBrouillon(
            id: bouteille.id,
            nom: 'Bouteille',
            quantiteEnUniteBase: 1,
            prixVente: 150,
            parDefaut: false,
          ),
        ],
        devise: 'XOF',
      );

      final apres = conditionnementService.listerPour(produit.id);
      expect(apres, hasLength(2));
      expect(apres.map((c) => c.id), containsAll([casier.id, bouteille.id]));
      expect(apres.any((c) => c.id == carton.id), isFalse);
      expect(HiveService.conditionnementsBox.get(carton.id), isNull);
    },
  );
}
