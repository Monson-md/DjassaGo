// Test du complément C1 : concurrence entre cycles de vente.
// Dart entrelace deux `finaliserVente()` lancés en parallèle à chaque
// `await` : sans sérialisation, un rollback peut restaurer son snapshot
// APRÈS la décrémentation persistée d'une autre vente (stock fantôme),
// et une validation peut s'appuyer sur un état transitoire d'une vente
// en cours qui échouera ensuite. Ces tests vérifient que le verrou
// statique de CaisseService rend chaque cycle vente/annulation
// séquentiel — y compris entre deux INSTANCES différentes du service
// (le verrou est partagé, pas par instance).

import 'dart:io';

import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/services/caisse_service.dart';
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

ItemVendu itemPour(Produit produit, int quantite) => ItemVendu(
  produitId: produit.id,
  nomProduit: produit.nom,
  quantite: quantite,
  prixUnitaireVente: produit.prixVente,
  prixUnitaireAchat: produit.prixAchat,
);

/// ProduitService dont [decrementerStock] écrit réellement le stock
/// persisté puis échoue comme une erreur disque : simule une vente A qui
/// a déjà décrémenté (mémoire + disque) avant de déclencher son rollback,
/// tandis qu'une vente B est déjà déposée dans la file du verrou.
class _ProduitServiceDefectueux extends ProduitService {
  final String produitIdDefectueux;
  _ProduitServiceDefectueux(this.produitIdDefectueux);

  @override
  Future<void> decrementerStock(String produitId, int quantite) async {
    await super.decrementerStock(produitId, quantite);
    if (produitId == produitIdDefectueux) {
      throw Exception("Erreur disque simulée pendant l'écriture du stock");
    }
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'caisse_de_poche_vente_concurrence_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // Chaque test repart d'une base propre (voir vente_atomique_test.dart :
  // clear() plutôt que deleteFromDisk, pour garder les boxes ouvertes).
  setUp(() async {
    await HiveService.produitsBox.clear();
    await HiveService.transactionsBox.clear();
    await HiveService.dettesBox.clear();
  });

  test('deux ventes simultanées sur des produits distincts : chacune '
      'décrit exactement son propre stock et sa propre transaction', () async {
    // Deux INSTANCES distinctes de CaisseService : le verrou doit être
    // partagé (statique) pour que la sérialisation s'applique quand même.
    final produitService = ProduitService();
    final caisseServiceA = CaisseService(produitService: produitService);
    final caisseServiceB = CaisseService(produitService: produitService);

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );
    final huile = await produitService.ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 20,
      devise: 'XOF',
    );

    final ventes = await Future.wait([
      caisseServiceA.finaliserVente(panier: [itemPour(riz, 3)], devise: 'XOF'),
      caisseServiceB.finaliserVente(
        panier: [itemPour(huile, 4)],
        devise: 'XOF',
      ),
    ]);

    // Les deux ventes aboutissent et sont enregistrées.
    expect(ventes, hasLength(2));
    expect(HiveService.transactionsBox.values, hasLength(2));

    // Chaque vente a décrémenté exactement son produit : aucun mélange.
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 7);
    expect(HiveService.produitsBox.get(huile.id)!.stockActuel, 16);
  });

  test('deux ventes simultanées sur le même stock : la seconde part du '
      'résultat de la première — pas de stock, échec net', () async {
    final produitService = ProduitService();
    final caisseServiceA = CaisseService(produitService: produitService);
    final caisseServiceB = CaisseService(produitService: produitService);

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );

    // A vend 8, B vend 4 : impossible ensemble (10 < 12). Sans
    // sérialisation, B pourrait valider pendant un état transitoire de A.
    final venteA = caisseServiceA.finaliserVente(
      panier: [itemPour(riz, 8)],
      devise: 'XOF',
    );
    final venteB = caisseServiceB.finaliserVente(
      panier: [itemPour(riz, 4)],
      devise: 'XOF',
    );

    await expectLater(
      venteB,
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Stock insuffisant'),
        ),
      ),
    );
    final transactionA = await venteA;
    expect(transactionA.montantTotalMineur, 8 * 750);

    // Stock cohérent : 10 - 8 = 2, vente A seulement.
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 2);
    final transactions = HiveService.transactionsBox.values;
    expect(transactions, hasLength(1));
    expect(transactions.first.montantTotalMineur, 8 * 750);
  });

  test("rollback d'une vente échouée en même temps qu'une vente réussie : "
      "le stock de la vente réussie n'est jamais écrasé", () async {
    final produitService = ProduitService();
    final huile = await produitService.ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 10,
      devise: 'XOF',
    );

    // La vente A échoue sur l'huile (2e article), après sa décrémentation
    // persistée : son rollback doit tourner AVANT que B n'écrive son stock.
    final serviceDefectueux = _ProduitServiceDefectueux(huile.id);
    final caisseServiceA = CaisseService(produitService: serviceDefectueux);
    final caisseServiceB = CaisseService(produitService: produitService);

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 20,
      devise: 'XOF',
    );

    final venteA = caisseServiceA.finaliserVente(
      panier: [itemPour(riz, 6), itemPour(huile, 5)],
      devise: 'XOF',
    );
    final venteB = caisseServiceB.finaliserVente(
      panier: [itemPour(riz, 4)],
      devise: 'XOF',
    );

    await expectLater(
      venteA,
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Erreur disque simulée'),
        ),
      ),
    );
    final transactionB = await venteB;
    expect(transactionB.montantTotalMineur, 4 * 750);

    // Sans verrou, le rollback de A pouvait restaurer son snapshot (riz
    // = 20) APRÈS la décrémentation persistée de B : stock fantôme. Avec
    // le verrou, A est intégralement terminée (rollback inclus) avant le
    // démarrage de B : 20 - 4 (B seul) = 16. L'huile n'a rien subi de A.
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 16);
    expect(HiveService.produitsBox.get(huile.id)!.stockActuel, 10);

    final transactions = HiveService.transactionsBox.values;
    expect(transactions, hasLength(1));
    expect(transactions.first.montantTotalMineur, 4 * 750);
  });

  test("annulation simultanée d'une vente et nouvelle vente : les deux "
      'aboutissent, stock final exact qu\'importe l\'ordre utile', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );

    final premiere = await caisseService.finaliserVente(
      panier: [itemPour(riz, 2)],
      devise: 'XOF',
    );
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 8);

    // Annulation + nouvelle vente lancées « en même temps ». Scénario où
    // les deux aboutissent : 10 - 2 + 2 (annulation) - 3 (vente) = 7.
    // (Et si l'ordre d'exécution s'inversait : 8 - 3 + 2 = 7 aussi — le
    // stock final attendu est identique dans les deux rotations.)
    final resultats = await Future.wait([
      caisseService.annulerTransaction(
        transactionId: premiere.id,
        motif: 'Erreur de saisie',
      ),
      caisseService.finaliserVente(panier: [itemPour(riz, 3)], devise: 'XOF'),
    ]);

    expect(resultats, hasLength(2));
    expect(resultats.first.annulee, isTrue);
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 7);
    expect(HiveService.transactionsBox.values, hasLength(2));
  });

  test('vente à crédit et vente au comptant simultanées : deux '
      'transactions, une seule dette, stock exact', () async {
    final produitService = ProduitService();
    final caisseServiceA = CaisseService(produitService: produitService);
    final caisseServiceB = CaisseService(produitService: produitService);

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 20,
      devise: 'XOF',
    );

    final ventes = await Future.wait([
      caisseServiceA.finaliserVenteACredit(
        panier: [itemPour(riz, 5)],
        devise: 'XOF',
        nomClient: 'Awa',
        telephone: '+2250700000000',
      ),
      caisseServiceB.finaliserVente(panier: [itemPour(riz, 3)], devise: 'XOF'),
    ]);

    // Deux transactions, une seule dette (celle de la vente à crédit).
    expect(ventes, hasLength(2));
    expect(HiveService.transactionsBox.values, hasLength(2));
    final dettes = HiveService.dettesBox.values;
    expect(dettes, hasLength(1));
    expect(dettes.first.montantDu, 5 * 750);

    // Stock : 20 - 5 (crédit) - 3 (comptant) = 12.
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 12);
  });
}
