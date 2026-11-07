// Test de la correction C1 : atomique de CaisseService.finaliserVente.
// Une vente qui échoue (stock insuffisant sur n'importe quel article,
// produit inexistant, erreur d'écriture du stock ou de la transaction)
// ne doit JAMAIS laisser un stock partiellement décrémenté ni une
// transaction enregistrée seule : les échecs avant écriture ne touchent
// rien, et les échecs pendant les écritures sont annulés par un rollback
// de compensation (remise des stocks mémoire + disque, suppression d'une
// transaction partiellement écrite).

import 'dart:io';

import 'package:caisse_de_poche/config/hive_boxes.dart';
import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/models/transaction.dart' as model;
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

/// Construit un ItemVendu comme le fait CaisseProvider.ajouterAuPanier :
/// le prix du conditionnement (vente et coût) est celui de la ligne,
/// ["quantiteEnUniteBase"] est le multiplicateur de stock de la ligne.
ItemVendu itemPour(
  Produit produit,
  int quantite, {
  int quantiteEnUniteBase = 1,
  double? prixUnitaireVente,
  double? prixUnitaireAchat,
}) => ItemVendu(
  produitId: produit.id,
  nomProduit: produit.nom,
  quantite: quantite,
  prixUnitaireVente:
      prixUnitaireVente ?? produit.prixVente * quantiteEnUniteBase,
  prixUnitaireAchat:
      prixUnitaireAchat ?? produit.prixAchat * quantiteEnUniteBase,
  conditionnementNom: quantiteEnUniteBase > 1 ? 'Casier' : '',
  quantiteEnUniteBase: quantiteEnUniteBase,
);

/// ProduitService dont [decrementerStock] écrit réellement le stock
/// persisté, puis échoue comme ferait une erreur disque : simule un
/// échec APRÈS la décrémentation, pour vérifier le rollback par
/// compensation au point précis où l'ancien code laissait un état
/// partiel.
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
      'caisse_de_poche_vente_atomique_test',
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

  // Chaque test repart d'une base propre : contrairement à
  // Hive.deleteFromDisk() (qui ferme les boxes que HiveService.init ne
  // rouvrirait pas, _initialise restant vrai), on vide le contenu des
  // boxes — clear() supprime les données en mémoire ET sur disque.
  setUp(() async {
    await HiveService.produitsBox.clear();
    await HiveService.transactionsBox.clear();
    await HiveService.dettesBox.clear();
  });

  test('vente normale : stock décrémenté sur toutes les lignes, montants '
      'figés en unités mineures, transaction enregistrée', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

    // Casier de Coca acheté 1500, bouteille vendue 150 (coût 75) :
    // soit 2 lignes du même produit + un produit simple.
    final coca = await produitService.ajouter(
      nom: 'Coca',
      prixAchat: 75,
      prixVente: 150,
      stockActuel: 100,
      devise: 'XOF',
      uniteBase: 'bouteille',
    );
    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );

    final panier = [
      itemPour(
        coca,
        1,
        quantiteEnUniteBase: 20,
        prixUnitaireVente: 2000,
        prixUnitaireAchat: 1500,
      ),
      itemPour(coca, 3),
      itemPour(riz, 2),
    ];

    final transaction = await caisseService.finaliserVente(
      panier: panier,
      devise: 'XOF',
    );

    // Total : 2000 + 3*150 + 2*750 = 3950. Marge : 500 + 3*75 + 2*250 = 1225.
    expect(transaction.montantTotal, 3950);
    expect(transaction.margeBrute, 1225);
    expect(transaction.montantTotalMineur, 3950);
    expect(transaction.margeBruteMineur, 1225);

    // Le stock agrégé du Coca (casier = 20 unités de base) est décrémenté :
    // 100 - 20 - 3 = 77. Riz : 10 - 2 = 8.
    expect(produitService.trouverParId(coca.id)!.stockActuel, 77);
    expect(produitService.trouverParId(riz.id)!.stockActuel, 8);

    // La transaction est bien enregistrée dans la box.
    final enregistree = HiveService.transactionsBox.get(transaction.id);
    expect(enregistree, isNotNull);
    expect(enregistree!.montantTotalMineur, 3950);
    expect(enregistree.itemsVendus, hasLength(3));
  });

  test('stock insuffisant sur le premier article : échec avant toute '
      'écriture, état inchangé', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 2,
      devise: 'XOF',
    );
    final huile = await produitService.ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 20,
      devise: 'XOF',
    );

    final panier = [itemPour(riz, 3), itemPour(huile, 1)];

    await expectLater(
      caisseService.finaliserVente(panier: panier, devise: 'XOF'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Stock insuffisant'),
        ),
      ),
    );

    expect(produitService.trouverParId(riz.id)!.stockActuel, 2);
    expect(produitService.trouverParId(huile.id)!.stockActuel, 20);
    expect(HiveService.transactionsBox.values, isEmpty);
  });

  test('stock insuffisant sur un article suivant : le premier produit '
      'décrémenté par l\'ancien code est remis — état inchangé', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

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
      stockActuel: 1,
      devise: 'XOF',
    );

    // La vente du riz passe (10 >= 2) mais l'huile échoue : l'ancien
    // déroulement laissait le riz décrémenté à 8 sans transaction.
    final panier = [itemPour(riz, 2), itemPour(huile, 5)];

    await expectLater(
      caisseService.finaliserVente(panier: panier, devise: 'XOF'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Stock insuffisant'),
        ),
      ),
    );

    // Le stock du riz reste intact : aucune écriture n'a eu lieu.
    expect(produitService.trouverParId(riz.id)!.stockActuel, 10);
    expect(produitService.trouverParId(huile.id)!.stockActuel, 1);
    expect(HiveService.transactionsBox.values, isEmpty);
  });

  test(
    'stock insuffisant sur la somme de deux lignes du même produit '
    '(conditionnements différents) : validé en agrégé, rien n\'est écrit',
    () async {
      final produitService = ProduitService();
      final caisseService = CaisseService(produitService: produitService);

      final coca = await produitService.ajouter(
        nom: 'Coca',
        prixAchat: 75,
        prixVente: 150,
        stockActuel: 25,
        devise: 'XOF',
        uniteBase: 'bouteille',
      );

      // Ligne par ligne, chaque ligne passe (25 >= 20, puis 5 >= 10 serait
      // faux) — seul le total agrégé 20 + 10 = 30 > 25 fait échouer la vente.
      // L'ancien code décrémentait déjà le casier (25 -> 5) avant d'échouer.
      final panier = [
        itemPour(
          coca,
          1,
          quantiteEnUniteBase: 20,
          prixUnitaireVente: 2000,
          prixUnitaireAchat: 1500,
        ),
        itemPour(coca, 10),
      ];

      await expectLater(
        caisseService.finaliserVente(panier: panier, devise: 'XOF'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Stock insuffisant'),
          ),
        ),
      );

      expect(produitService.trouverParId(coca.id)!.stockActuel, 25);
      expect(HiveService.transactionsBox.values, isEmpty);
    },
  );

  test(
    'produit inexistant : échec avant toute écriture, état inchangé',
    () async {
      final produitService = ProduitService();
      final caisseService = CaisseService(produitService: produitService);

      final riz = await produitService.ajouter(
        nom: 'Riz 1kg',
        prixAchat: 500,
        prixVente: 750,
        stockActuel: 10,
        devise: 'XOF',
      );

      // 1) Le produit inconnu arrive en tête de panier.
      final panierProduitInconnuEnTete = [
        itemPour(riz, 1),
        ItemVendu(
          produitId: 'produit-supprime-entre-temps',
          nomProduit: 'Ancien produit',
          quantite: 1,
          prixUnitaireVente: 1000,
          prixUnitaireAchat: 500,
        ),
      ];
      await expectLater(
        caisseService.finaliserVente(
          panier: panierProduitInconnuEnTete,
          devise: 'XOF',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Produit introuvable'),
          ),
        ),
      );
      // 2) Le produit inconnu arrive en tête : même verdict.
      final panierProduitInconnuPremier = [
        ItemVendu(
          produitId: 'produit-supprime-entre-temps',
          nomProduit: 'Ancien produit',
          quantite: 1,
          prixUnitaireVente: 1000,
          prixUnitaireAchat: 500,
        ),
        itemPour(riz, 1),
      ];
      await expectLater(
        caisseService.finaliserVente(
          panier: panierProduitInconnuPremier,
          devise: 'XOF',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Produit introuvable'),
          ),
        ),
      );

      expect(produitService.trouverParId(riz.id)!.stockActuel, 10);
      expect(HiveService.transactionsBox.values, isEmpty);
    },
  );

  test('erreur pendant l\'écriture de la transaction : les stocks déjà '
      'décrémentés sont restaurés en mémoire ET sur disque, aucune vente '
      'orpheline', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

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
      stockActuel: 10,
      devise: 'XOF',
    );

    // Fermer la box des transactions simule une écriture impossible
    // (disque plein, base corrompue...) : HiveError('Box has already
    // been closed.') est levée par le put, après les décréments de stock.
    await HiveService.transactionsBox.close();

    final panier = [itemPour(riz, 2), itemPour(huile, 3)];
    await expectLater(
      caisseService.finaliserVente(panier: panier, devise: 'XOF'),
      // L'erreur d'origine (HiveError, un Error) est ré-levée telle
      // quelle par le rollback ; l'appelant voit bien un échec.
      throwsA(anyOf(isA<Exception>(), isA<HiveError>())),
    );

    // Mémoire : stocks restaurés.
    expect(produitService.trouverParId(riz.id)!.stockActuel, 10);
    expect(produitService.trouverParId(huile.id)!.stockActuel, 10);

    // Disque : on rouvre la box produits pour reprendre les valeurs
    // réellement persistées (hydratées depuis le fichier, pas la mémoire).
    await HiveService.produitsBox.close();
    final produitsReouverts = await Hive.openBox<Produit>(HiveBoxes.produits);
    expect(produitsReouverts.get(riz.id)!.stockActuel, 10);
    expect(produitsReouverts.get(huile.id)!.stockActuel, 10);

    // Aucune vente orpheline : après réouverture, la box transactions
    // est vide. (transactionsBox fermée lors du test : on la rouvre pour
    // les suivants.)
    final transactionsReouvertes = await Hive.openBox<model.Transaction>(
      HiveBoxes.transactions,
    );
    expect(transactionsReouvertes.values, isEmpty);
  });

  test('erreur pendant l\'écriture d\'un stock (après décrémentation '
      'persistée) : rollback complet en mémoire et sur disque', () async {
    final riz = await ProduitService().ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );
    final huile = await ProduitService().ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 10,
      devise: 'XOF',
    );

    // Le service défaillant décrémente PERSISTE chaque stock puis échoue
    // sur le dernier article : les deux stocks sont donc déjà modifiés
    // deux fois (mémoire + disque) quand le rollback démarre.
    final produitService = _ProduitServiceDefectueux(huile.id);
    final caisseService = CaisseService(produitService: produitService);
    final panier = [itemPour(riz, 2), itemPour(huile, 3)];

    await expectLater(
      caisseService.finaliserVente(panier: panier, devise: 'XOF'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains("Erreur disque simulée"),
        ),
      ),
    );

    // Mémoire : les deux stocks sont restaurés (12/7 -> 10/10).
    expect(produitService.trouverParId(riz.id)!.stockActuel, 10);
    expect(produitService.trouverParId(huile.id)!.stockActuel, 10);

    // Disque : vérification avec une box réhydratée depuis le fichier.
    await HiveService.produitsBox.close();
    final produitsReouverts = await Hive.openBox<Produit>(HiveBoxes.produits);
    expect(produitsReouverts.get(riz.id)!.stockActuel, 10);
    expect(produitsReouverts.get(huile.id)!.stockActuel, 10);

    // Aucune transaction n'a été enregistrée.
    expect(HiveService.transactionsBox.values, isEmpty);
  });
}
