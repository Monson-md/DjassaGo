// Test de la correction C2 : atomicité MÉTIER de
// CaisseService.finaliserVenteACredit. La vente elle-même est déjà
// atomique (C1) ; ici on vérifie que la vente et sa dette vont toujours
// ensemble : si la création de la dette échoue, les écritures de la vente
// sont compensées (stock restauré mémoire + disque, transaction retirée,
// dette éventuellement déjà écrite supprimée) et l'erreur d'origine est
// re-propagée. Si la compensation herself échoue en partie, une erreur
// explicite combine l'erreur d'origine et les compensations manquées.

import 'dart:io';

import 'package:caisse_de_poche/config/hive_boxes.dart';
import 'package:caisse_de_poche/models/dette.dart';
import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/models/mode_paiement.dart';
import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/services/caisse_service.dart';
import 'package:caisse_de_poche/services/dette_service.dart';
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

/// DetteService dont [ajouter] écrit réellement la dette puis échoue comme
/// une erreur disque : simule une dette déjà persistée quand l'erreur
/// survient — le cas où une compensation légitimement incomplète laisserait
/// une dette orpheline si elle n'était pas retirée explicitement.
class _DetteServiceDefectueux extends DetteService {
  @override
  Future<Dette> ajouter({
    required String nomClient,
    required String telephone,
    required double montantDu,
    required String devise,
    DateTime? dateDette,
    String? note,
    String? transactionId,
  }) async {
    await super.ajouter(
      nomClient: nomClient,
      telephone: telephone,
      montantDu: montantDu,
      devise: devise,
      dateDette: dateDette,
      note: note,
      transactionId: transactionId,
    );
    throw Exception('Erreur création dette simulée');
  }
}

/// DetteService dont [ajouter] échoue AVANT toute écriture : dit comme une
/// box fermée ou un disque plein au moment du put de la dette.
class _DetteServiceEchecAvantEcriture extends DetteService {
  @override
  Future<Dette> ajouter({
    required String nomClient,
    required String telephone,
    required double montantDu,
    required String devise,
    DateTime? dateDette,
    String? note,
    String? transactionId,
  }) async {
    throw Exception('Erreur avant écriture de la dette');
  }
}

/// DetteService qui ferme la box des PRODUITS puis échoue : la vente a
/// abouti (ses écritures sont déjà persistées quand la dette est tentée),
/// mais la compensation qui suit ne peut plus persister la restitution du
/// stock — l'appelant doit recevoir une erreur explicite combinée.
class _DetteServiceQuiFermeLesProduits extends DetteService {
  @override
  Future<Dette> ajouter({
    required String nomClient,
    required String telephone,
    required double montantDu,
    required String devise,
    DateTime? dateDette,
    String? note,
    String? transactionId,
  }) async {
    await HiveService.produitsBox.close();
    throw Exception('Erreur création dette simulée');
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'caisse_de_poche_vente_credit_atomique_test',
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

  test(
    'vente à crédit réussie : vente et dette enregistrées ensemble',
    () async {
      final produitService = ProduitService();
      final detteService = DetteService();
      final caisseService = CaisseService(
        produitService: produitService,
        detteService: detteService,
      );

      final riz = await produitService.ajouter(
        nom: 'Riz 1kg',
        prixAchat: 500,
        prixVente: 750,
        stockActuel: 10,
        devise: 'XOF',
      );

      final transaction = await caisseService.finaliserVenteACredit(
        panier: [itemPour(riz, 3)],
        devise: 'XOF',
        nomClient: 'Awa',
        telephone: '+2250700000000',
      );

      // La vente est actée (mode crédit, stock décrémenté, transaction
      // enregistrée)...
      expect(transaction.modePaiement, ModePaiement.credit);
      expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 7);
      expect(HiveService.transactionsBox.get(transaction.id), isNotNull);

      // ... et sa dette liée pointe dessus : l'ensemble est cohérent.
      final dettes = HiveService.dettesBox.values;
      expect(dettes, hasLength(1));
      expect(dettes.first.transactionId, transaction.id);
      expect(dettes.first.montantDu, transaction.montantTotal);
      expect(dettes.first.statut, StatutDette.enCours);
    },
  );

  test('échec de création de dette APRES écriture : la vente est annulée '
      '(stock restauré mémoire + disque, transaction et dette orpheline '
      'retirées) et l\'erreur d\'origine est propagée', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(
      produitService: produitService,
      detteService: _DetteServiceDefectueux(),
    );

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );

    // Le service défaillant écrit la dette PUIS échoue : au moment du
    // catch, stock décrémenté, transaction écrite ET dette orpheline
    // persistée devaient tous trois être compensés.
    await expectLater(
      caisseService.finaliserVenteACredit(
        panier: [itemPour(riz, 3)],
        devise: 'XOF',
        nomClient: 'Awa',
        telephone: '+2250700000000',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Erreur création dette simulée'),
        ),
      ),
    );

    // Mémoire : stock restauré.
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 10);

    // Disque : vérification avec une box réhydratée depuis le fichier.
    await HiveService.produitsBox.close();
    final produitsReouverts = await Hive.openBox<Produit>(HiveBoxes.produits);
    expect(produitsReouverts.get(riz.id)!.stockActuel, 10);

    // Ni vente sans dette, ni dette sans vente : l'état est celui
    // d'avant la tentative de vente.
    expect(HiveService.transactionsBox.values, isEmpty);
    expect(HiveService.dettesBox.values, isEmpty);
  });

  test('échec de création de dette AVANT toute écriture : compensation '
      'complète et erreur d\'origine propagée telle quelle', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(
      produitService: produitService,
      detteService: _DetteServiceEchecAvantEcriture(),
    );

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );

    await expectLater(
      caisseService.finaliserVenteACredit(
        panier: [itemPour(riz, 2)],
        devise: 'XOF',
        nomClient: 'Koffi',
        telephone: '+2250700000001',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Erreur avant écriture de la dette'),
        ),
      ),
    );

    // Stock restauré en mémoire, aucune transaction ni dette orpheline.
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 10);
    expect(HiveService.transactionsBox.values, isEmpty);
    expect(HiveService.dettesBox.values, isEmpty);
  });

  test('deux ventes à crédit simultanées sur le même stock : celle dont '
      'la dette échoue est compensée sans toucher à l\'autre', () async {
    final produitService = ProduitService();
    final caisseServiceA = CaisseService(
      produitService: produitService,
      detteService: DetteService(),
    );
    final caisseServiceB = CaisseService(
      produitService: produitService,
      detteService: _DetteServiceDefectueux(),
    );

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 20,
      devise: 'XOF',
    );

    // A vend à crédit 5 (réussit) ; B vend à crédit 8 (sa vente passe
    // mais sa dette échoue). Sous le verrou, B démarre APRÈS A : son
    // snapshot de compensation est pris après la vente de A (stock 15),
    // donc la remise en état de B ne peut pas écraser le décrément de A.
    final ventes = Future.wait([
      caisseServiceA.finaliserVenteACredit(
        panier: [itemPour(riz, 5)],
        devise: 'XOF',
        nomClient: 'Awa',
        telephone: '+2250700000000',
      ),
      caisseServiceB.finaliserVenteACredit(
        panier: [itemPour(riz, 8)],
        devise: 'XOF',
        nomClient: 'Koffi',
        telephone: '+2250700000001',
      ),
    ]);

    await expectLater(
      ventes,
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Erreur création dette simulée'),
        ),
      ),
    );

    // Stock : 20 - 5 (A seule) = 15 ; la compensation de B est repartie
    // de 15, pas de 20.
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 15);

    // Une seule vente (A) et une seule dette (celle de A) : B a été
    // intégralement annulée.
    expect(HiveService.transactionsBox.values, hasLength(1));
    expect(HiveService.dettesBox.values, hasLength(1));
    expect(HiveService.dettesBox.values.first.montantDu, 5 * 750.0);
  });

  test('échec de la COMPENSATION : erreur explicite combinant l\'erreur '
      'd\'origine, sans la masquer; état cohérent signalé', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(
      produitService: produitService,
      detteService: _DetteServiceQuiFermeLesProduits(),
    );

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );

    await expectLater(
      caisseService.finaliserVenteACredit(
        panier: [itemPour(riz, 3)],
        devise: 'XOF',
        nomClient: 'Awa',
        telephone: '+2250700000000',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(
            // L'erreur d'origine est toujours visible...
            contains('Erreur création dette simulée'),
            // ...et l'échec de compensation est explicitement signalé.
            contains('remise en état'),
            contains('restauration du stock sur disque'),
          ),
        ),
      ),
    );

    // La restitution du stock a réussi EN MÉMOIRE (le produit du panier
    // est restauré par référence)...
    expect(riz.stockActuel, 10);

    // ...mais elle n'a pas pu être persistée (box fermée) : sur disque,
    // le stock reste à la valeur décrémentée. C'est précisément cette
    // limite que le message d'erreur signale.
    final produitsReouverts = await Hive.openBox<Produit>(HiveBoxes.produits);
    expect(produitsReouverts.get(riz.id)!.stockActuel, 7);

    // La transaction orpheline a, elle, bien été retirée : pas de vente
    // actée sans dette.
    expect(HiveService.transactionsBox.values, isEmpty);
  });

  test('régression annulation : une vente à crédit réussie reste annulable '
      'dette et stock compris', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(
      produitService: produitService,
      detteService: DetteService(),
    );

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );

    final transaction = await caisseService.finaliserVenteACredit(
      panier: [itemPour(riz, 2)],
      devise: 'XOF',
      nomClient: 'Awa',
      telephone: '+2250700000000',
    );
    expect(HiveService.dettesBox.values, hasLength(1));

    await caisseService.annulerTransaction(
      transactionId: transaction.id,
      motif: 'Erreur de saisie',
    );

    expect(transaction.annulee, isTrue);
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 10);
    expect(HiveService.dettesBox.values, isEmpty);
    expect(HiveService.transactionsBox.get(transaction.id)!.annulee, isTrue);
  });
}
