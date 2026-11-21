// Tests de la clé de fusion du panier (mission I1) : deux conditionnements
// homonymes ne doivent jamais être confondus, et une même ligne ne doit
// fusionner que si produit + id de conditionnement + quantité en unité de
// base + prix unitaire sont identiques.

import 'dart:io';

import 'package:caisse_de_poche/models/conditionnement.dart';
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
  late ProduitService produitService;
  late ConditionnementService conditionnementService;
  late CaisseProvider caisseProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'caisse_de_poche_panier_fusion_i1_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    HiveService.reinitialiserPourTest();
    await HiveService.init();
    produitService = ProduitService();
    conditionnementService = ConditionnementService();
    caisseProvider = CaisseProvider();
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    HiveService.reinitialiserPourTest();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<(String, Conditionnement, Conditionnement)>
  preparerDeuxCasiers() async {
    final produit = await produitService.ajouter(
      nom: 'Coca',
      prixAchat: 50,
      prixVente: 100,
      stockActuel: 100,
      devise: 'XOF',
      uniteBase: 'bouteille',
    );
    final casier12 = await conditionnementService.ajouter(
      produitId: produit.id,
      nom: 'Casier',
      quantiteEnUniteBase: 12,
      prixVente: 1200,
      devise: 'XOF',
      parDefaut: true,
    );
    final casier24 = await conditionnementService.ajouter(
      produitId: produit.id,
      nom: 'Casier',
      quantiteEnUniteBase: 24,
      prixVente: 2400,
      devise: 'XOF',
    );
    return (produit.id, casier12, casier24);
  }

  test(
    'deux conditionnements homonymes de quantités différentes restent deux lignes',
    () async {
      final (produitId, casier12, casier24) = await preparerDeuxCasiers();
      final produit = produitService.trouverParId(produitId)!;

      caisseProvider.ajouterAuPanier(produit, casier12);
      caisseProvider.ajouterAuPanier(produit, casier24);

      final panier = caisseProvider.panier;
      expect(panier, hasLength(2));
      expect(panier[0].conditionnementNom, 'Casier');
      expect(panier[1].conditionnementNom, 'Casier');
      expect(panier[0].conditionnementId, casier12.id);
      expect(panier[1].conditionnementId, casier24.id);
      expect(panier[0].quantite, 1);
      expect(panier[1].quantite, 1);
      expect(panier[0].prixUnitaireVente, 1200);
      expect(panier[1].prixUnitaireVente, 2400);
      expect(panier[0].quantiteEnUniteBase, 12);
      expect(panier[1].quantiteEnUniteBase, 24);
    },
  );

  test(
    'le même conditionnement ajouté deux fois fusionne en une seule ligne',
    () async {
      final (produitId, casier12, _) = await preparerDeuxCasiers();
      final produit = produitService.trouverParId(produitId)!;

      caisseProvider.ajouterAuPanier(produit, casier12, quantite: 2);
      caisseProvider.ajouterAuPanier(produit, casier12, quantite: 3);

      final panier = caisseProvider.panier;
      expect(panier, hasLength(1));
      expect(panier.single.conditionnementId, casier12.id);
      expect(panier.single.quantite, 5);
      expect(panier.single.prixUnitaireVente, 1200);
    },
  );

  test(
    'même id mais prix différent après édition : pas de fusion fausse',
    () async {
      final (produitId, casier12, _) = await preparerDeuxCasiers();
      final produit = produitService.trouverParId(produitId)!;

      caisseProvider.ajouterAuPanier(produit, casier12);
      final casierModifie = Conditionnement(
        id: casier12.id,
        produitId: produitId,
        nom: 'Casier',
        quantiteEnUniteBase: 12,
        prixVente: 1500,
        parDefaut: true,
        devise: 'XOF',
      );
      caisseProvider.ajouterAuPanier(produit, casierModifie);

      expect(caisseProvider.panier, hasLength(2));
      expect(caisseProvider.panier[0].prixUnitaireVente, 1200);
      expect(caisseProvider.panier[1].prixUnitaireVente, 1500);
    },
  );

  test(
    'même id mais multiplicateur différent après édition : pas de fusion fausse',
    () async {
      final (produitId, casier12, _) = await preparerDeuxCasiers();
      final produit = produitService.trouverParId(produitId)!;

      caisseProvider.ajouterAuPanier(produit, casier12);
      final casierModifie = Conditionnement(
        id: casier12.id,
        produitId: produitId,
        nom: 'Casier',
        quantiteEnUniteBase: 24,
        prixVente: 1200,
        parDefaut: true,
        devise: 'XOF',
      );
      caisseProvider.ajouterAuPanier(produit, casierModifie);

      expect(caisseProvider.panier, hasLength(2));
      expect(caisseProvider.panier[0].quantiteEnUniteBase, 12);
      expect(caisseProvider.panier[1].quantiteEnUniteBase, 24);
    },
  );

  test(
    'vente finale de deux lignes homonymes : stock, total et marge corrects',
    () async {
      final (produitId, casier12, casier24) = await preparerDeuxCasiers();
      final produit = produitService.trouverParId(produitId)!;

      caisseProvider.ajouterAuPanier(produit, casier12);
      caisseProvider.ajouterAuPanier(produit, casier24);
      final transaction = await caisseProvider.finaliserVente(devise: 'XOF');

      expect(transaction.itemsVendus, hasLength(2));
      expect(transaction.montantTotal, 3600);
      // Coût : 50 × 12 = 600 puis 50 × 24 = 1200, soit 1800 de marge.
      expect(transaction.margeBrute, 1800);
      expect(produitService.trouverParId(produitId)!.stockActuel, 64);
      expect(transaction.itemsVendus[0].conditionnementId, casier12.id);
      expect(transaction.itemsVendus[1].conditionnementId, casier24.id);
    },
  );
}
