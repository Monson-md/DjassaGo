// Tests de l'unicité des noms de conditionnement (mission I1) :
// ConditionnementService.remplacerPour doit refuser un ensemble de brouillons
// invalide AVANT de supprimer les conditionnements existants.

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
      'caisse_de_poche_conditionnement_noms_uniques_test',
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

  test(
    'doublon exact, casse différente et espaces différents sont refusés',
    () async {
      final produit = await produitService.ajouter(
        nom: 'Coca',
        prixAchat: 75,
        prixVente: 100,
        stockActuel: 100,
        devise: 'XOF',
        uniteBase: 'bouteille',
      );
      final ancien = await conditionnementService.ajouter(
        produitId: produit.id,
        nom: 'Casier',
        quantiteEnUniteBase: 20,
        prixVente: 2000,
        devise: 'XOF',
        parDefaut: true,
      );

      final jeuxDeNoms = [
        ['Casier', 'Casier'], // doublon exact
        ['Casier', 'CASIER'], // casse différente
        ['Casier de 12', 'Casier   de   12'], // espaces différents
      ];

      for (final noms in jeuxDeNoms) {
        await expectLater(
          conditionnementService.remplacerPour(
            produitId: produit.id,
            brouillons: [
              for (final nom in noms)
                ConditionnementBrouillon(
                  nom: nom,
                  quantiteEnUniteBase: 12,
                  prixVente: 1200,
                  parDefaut: false,
                ),
            ],
            devise: 'XOF',
          ),
          throwsA(isA<Exception>()),
        );

        // Rien n'a été supprimé : l'ancien conditionnement est toujours là.
        final restants = conditionnementService.listerPour(produit.id);
        expect(restants, hasLength(1));
        expect(restants.single.id, ancien.id);
        expect(restants.single.nom, 'Casier');
      }

      // Vérification sur disque : fermeture puis réouverture réelle de Hive.
      await Hive.close();
      HiveService.reinitialiserPourTest();
      await HiveService.init();

      final surDisque = HiveService.conditionnementsBox.get(ancien.id);
      expect(surDisque, isNotNull);
      expect(surDisque!.nom, 'Casier');
      expect(surDisque.quantiteEnUniteBase, 20);
      expect(HiveService.conditionnementsBox.values, hasLength(1));
    },
  );

  test(
    'nom vide et quantité nulle sont aussi refusés avant suppression',
    () async {
      final produit = await produitService.ajouter(
        nom: 'Savon',
        prixAchat: 200,
        prixVente: 300,
        stockActuel: 40,
        devise: 'XOF',
      );
      final ancien = await conditionnementService.ajouter(
        produitId: produit.id,
        nom: 'Unité',
        quantiteEnUniteBase: 1,
        prixVente: 300,
        devise: 'XOF',
        parDefaut: true,
      );

      await expectLater(
        conditionnementService.remplacerPour(
          produitId: produit.id,
          brouillons: const [
            ConditionnementBrouillon(
              nom: '   ',
              quantiteEnUniteBase: 1,
              prixVente: 300,
              parDefaut: true,
            ),
          ],
          devise: 'XOF',
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        conditionnementService.remplacerPour(
          produitId: produit.id,
          brouillons: const [
            ConditionnementBrouillon(
              nom: 'Carton',
              quantiteEnUniteBase: 0,
              prixVente: 300,
              parDefaut: true,
            ),
          ],
          devise: 'XOF',
        ),
        throwsA(isA<Exception>()),
      );

      final restants = conditionnementService.listerPour(produit.id);
      expect(restants, hasLength(1));
      expect(restants.single.id, ancien.id);
    },
  );
}
