// Test de la correction C5 : annulerTransaction est atomique.
// Une annulation qui échoue (produit supprimé, dette déjà payée, erreur
// d'écriture du stock / de la dette / du marquage) ne doit JAMAIS laisser
// un état partiellement écrit : validation complète avant toute écriture
// (Phase 0), remise en stock agrégée (Phase 1), suppression de la dette
// seulement après (Phase 2), marquage de la transaction en dernier
// (Phase 3) — et rollback par compensation dans l'ordre inverse pour tout
// échec survenu après le début des écritures.

import 'dart:io';

import 'package:caisse_de_poche/config/hive_boxes.dart';
import 'package:caisse_de_poche/models/dette.dart';
import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/models/transaction.dart' as model;
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

/// Construit un ItemVendu comme le fait CaisseProvider.ajouterAuPanier :
/// ["quantiteEnUniteBase"] est le multiplicateur de stock de la ligne
/// (1 pour un produit simple, 20 pour un casier de 20 bouteilles).
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

/// ProduitService dont [reapprovisionner] persiste réellement le stock
/// puis échoue comme une erreur disque : simule une remise en stock qui
/// a déjà écrit (mémoire + disque) avant de déclencher le rollback de
/// l'annulation.
class _ProduitServiceRemiseDefectueuse extends ProduitService {
  final String produitIdDefectueux;
  _ProduitServiceRemiseDefectueuse(this.produitIdDefectueux);

  @override
  Future<void> reapprovisionner(String produitId, int quantite) async {
    await super.reapprovisionner(produitId, quantite);
    if (produitId == produitIdDefectueux) {
      throw Exception("Erreur disque simulée pendant la remise en stock");
    }
  }
}

/// ProduitService qui ferme la box transactions juste après une remise
/// en stock réussie : la Phase 0 (lecture de la transaction) tourne box
/// ouverte, la remise en stock réussit, puis le MARQUAGE final (Phase 3,
/// transaction.save()) échoue comme une box fermée au disque plein.
class _ProduitServiceFermeurTransactions extends ProduitService {
  final String produitIdDeclencheur;
  _ProduitServiceFermeurTransactions(this.produitIdDeclencheur);

  @override
  Future<void> reapprovisionner(String produitId, int quantite) async {
    await super.reapprovisionner(produitId, quantite);
    if (produitId == produitIdDeclencheur) {
      await HiveService.transactionsBox.close();
    }
  }
}

/// ProduitService qui simule la suppression d'un produit APRÈS la
/// première remise en stock réussie : le produit existe encore à la
/// validation (Phase 0), disparaît entre deux lignes, et le
/// réapprovisionnement suivant échoue naturellement à
/// « Produit introuvable » — comme quand la fiche est réellement
/// supprimée entre-temps.
class _ProduitServiceSuppressionSurvenue extends ProduitService {
  final String produitIdASupprimer;
  _ProduitServiceSuppressionSurvenue(this.produitIdASupprimer);

  @override
  Future<void> reapprovisionner(String produitId, int quantite) async {
    await super.reapprovisionner(produitId, quantite);
    if (produitId != produitIdASupprimer) {
      await HiveService.produitsBox.delete(produitIdASupprimer);
    }
  }
}

/// ProduitService enregistreur : mémorise chaque appel de
/// [reapprovisionner] pour vérifier que la remise est bien agrégée (une
/// seule écriture par produit, pas une par ligne de la vente).
class _ProduitServiceEspion extends ProduitService {
  final appelsRemise = <String>[];

  @override
  Future<void> reapprovisionner(String produitId, int quantite) async {
    appelsRemise.add('$produitId:$quantite');
    await super.reapprovisionner(produitId, quantite);
  }
}

/// DetteService dont [supprimer] supprime réellement la dette (mémoire +
/// disque) puis échoue comme une erreur disque : la suppression est
/// « effective » au sens Hive quand le rollback démarre.
class _DetteServiceSuppressionDefectueuse extends DetteService {
  @override
  Future<void> supprimer(String id) async {
    await super.supprimer(id);
    throw Exception("Erreur disque simulée pendant la suppression de la dette");
  }
}

// Vérification sur disque : fermer la box puis la ROUVRIR (typée),
// pour lire les valeurs réellement persistées — hydratées depuis le
// fichier, pas celles restées en mémoire.
Future<Box<Produit>> rouvrirProduitsSurDisque() async {
  await HiveService.produitsBox.close();
  return Hive.openBox<Produit>(HiveBoxes.produits);
}

Future<Box<model.Transaction>> rouvrirTransactionsSurDisque() async {
  await HiveService.transactionsBox.close();
  return Hive.openBox<model.Transaction>(HiveBoxes.transactions);
}

Future<Box<Dette>> rouvrirDettesSurDisque() async {
  await HiveService.dettesBox.close();
  return Hive.openBox<Dette>(HiveBoxes.dettes);
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'caisse_de_poche_annulation_atomique_test',
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
  // clear() vide le contenu en mémoire ET sur disque sans fermer les
  // boxes). La box des paiements de dette est vidée elle aussi : le test
  // 3 en crée explicitement.
  setUp(() async {
    await HiveService.produitsBox.clear();
    await HiveService.transactionsBox.clear();
    await HiveService.dettesBox.clear();
    await HiveService.paiementsDetteBox.clear();
  });

  test('vente à crédit : produit supprimé depuis la vente → refus avant '
      "toute écriture, dette intacte, vente toujours comptée", () async {
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
      stockActuel: 20,
      devise: 'XOF',
    );
    final huile = await produitService.ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 15,
      devise: 'XOF',
    );

    final vente = await caisseService.finaliserVenteACredit(
      panier: [itemPour(riz, 2), itemPour(huile, 3)],
      devise: 'XOF',
      nomClient: 'Aya',
      telephone: '+2250700000010',
    );
    expect(produitService.trouverParId(riz.id)!.stockActuel, 18);
    final dette = detteService.trouverParTransactionId(vente.id)!;

    // La fiche « Huile 1L » disparaît APRÈS la vente, AVANT le tour
    // d'annulation.
    await produitService.supprimer(huile.id);

    await expectLater(
      caisseService.annulerTransaction(
        transactionId: vente.id,
        motif: 'Erreur de saisie',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(
            contains('Huile 1L'),
            contains('existe plus'),
            contains("n'a été effectué"),
          ),
        ),
      ),
    );

    // Aucune écriture : le stock de l'autre produit est intact, la
    // transaction n'est pas annulée, la vente reste comptée dans le CA
    // et visible dans le journal des ventes.
    expect(produitService.trouverParId(riz.id)!.stockActuel, 18);
    expect(HiveService.transactionsBox.get(vente.id)!.annulee, isFalse);
    expect(caisseService.totalDuJourMineur(), vente.montantTotalMineur);
    expect(
      caisseService.toutesLesTransactions().map((t) => t.id),
      contains(vente.id),
    );

    // La dette liée est intacte : même id, même montant — en mémoire
    // ET sur disque.
    final detteRelue = detteService.trouverParTransactionId(vente.id)!;
    expect(detteRelue.id, dette.id);
    expect(detteRelue.montantDu, dette.montantDu);
    final dettesReouvertes = await rouvrirDettesSurDisque();
    final detteDisque = dettesReouvertes.get(dette.id);
    expect(detteDisque, isNotNull);
    expect(detteDisque!.montantDu, vente.montantTotal);
    expect(detteDisque.transactionId, vente.id);
  });

  test(
    'vente au comptant : produit supprimé depuis la vente → refus avant '
    'toute écriture, stocks et transaction inchangés (vérifiés sur disque)',
    () async {
      final produitService = ProduitService();
      final caisseService = CaisseService(produitService: produitService);

      final riz = await produitService.ajouter(
        nom: 'Riz 1kg',
        prixAchat: 500,
        prixVente: 750,
        stockActuel: 20,
        devise: 'XOF',
      );
      final huile = await produitService.ajouter(
        nom: 'Huile 1L',
        prixAchat: 700,
        prixVente: 1000,
        stockActuel: 15,
        devise: 'XOF',
      );

      final vente = await caisseService.finaliserVente(
        panier: [itemPour(riz, 2), itemPour(huile, 3)],
        devise: 'XOF',
      );
      expect(produitService.trouverParId(riz.id)!.stockActuel, 18);

      await produitService.supprimer(huile.id);

      await expectLater(
        caisseService.annulerTransaction(
          transactionId: vente.id,
          motif: 'Erreur de saisie',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('Huile 1L'),
              contains('existe plus'),
              contains("n'a été effectué"),
            ),
          ),
        ),
      );

      expect(produitService.trouverParId(riz.id)!.stockActuel, 18);
      expect(HiveService.transactionsBox.get(vente.id)!.annulee, isFalse);
      expect(caisseService.totalDuJourMineur(), vente.montantTotalMineur);

      // Sur disque : riz toujours à 18, huile toujours absente, vente
      // toujours non annulée.
      final produitsReouverts = await rouvrirProduitsSurDisque();
      expect(produitsReouverts.get(riz.id)!.stockActuel, 18);
      expect(produitsReouverts.get(huile.id), isNull);
      final transactionsReouvertes = await rouvrirTransactionsSurDisque();
      expect(transactionsReouvertes.get(vente.id)!.annulee, isFalse);
    },
  );

  test('dette déjà partiellement payée : blocage total, aucune écriture — '
      'et le paiement reste le motif du refus même si un produit est '
      'également supprimé', () async {
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
      stockActuel: 20,
      devise: 'XOF',
    );
    final huile = await produitService.ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 15,
      devise: 'XOF',
    );

    // Cas 1 : produits existants, paiement reçu → refus sur le paiement.
    final ventePayee = await caisseService.finaliserVenteACredit(
      panier: [itemPour(riz, 2)],
      devise: 'XOF',
      nomClient: 'Koffi',
      telephone: '+2250700000011',
    );
    final dettePayee = detteService.trouverParTransactionId(ventePayee.id)!;
    await detteService.enregistrerPaiement(dettePayee, 500);
    expect(produitService.trouverParId(riz.id)!.stockActuel, 18);

    await expectLater(
      caisseService.annulerTransaction(
        transactionId: ventePayee.id,
        motif: 'Tentative bloquée',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('des paiements ont déjà été reçus'),
        ),
      ),
    );

    // Aucune écriture : stock, dette et transaction intacts.
    expect(produitService.trouverParId(riz.id)!.stockActuel, 18);
    expect(dettePayee.montantDu, 1500 - 500);
    final transactionsReouvertes = await rouvrirTransactionsSurDisque();
    expect(transactionsReouvertes.get(ventePayee.id)!.annulee, isFalse);

    // Cas 2 : paiement reçu ET produit supprimé → le paiement reste le
    // motif du refus (contrôlé AVANT l'existence des produits).
    final ventePayeeHuile = await caisseService.finaliserVenteACredit(
      panier: [itemPour(riz, 1), itemPour(huile, 2)],
      devise: 'XOF',
      nomClient: 'Fatou',
      telephone: '+2250700000012',
    );
    final dettePayeeHuile = detteService.trouverParTransactionId(
      ventePayeeHuile.id,
    )!;
    await detteService.enregistrerPaiement(dettePayeeHuile, 100);
    await produitService.supprimer(huile.id);

    await expectLater(
      caisseService.annulerTransaction(
        transactionId: ventePayeeHuile.id,
        motif: 'Tentative bloquée',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(
            contains('des paiements ont déjà été reçus'),
            isNot(contains('existe plus')),
          ),
        ),
      ),
    );

    expect(produitService.trouverParId(riz.id)!.stockActuel, 17);
    expect(dettePayeeHuile.montantDu, 2750 - 100);
    expect(
      HiveService.transactionsBox.get(ventePayeeHuile.id)!.annulee,
      isFalse,
    );
  });

  test('annulation à crédit et nouvelle vente simultanées : les deux '
      "aboutissent, stock final exact quel que soit l'ordre", () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );

    final premiere = await caisseService.finaliserVenteACredit(
      panier: [itemPour(riz, 2)],
      devise: 'XOF',
      nomClient: 'Aya',
      telephone: '+2250700000013',
    );
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 8);
    expect(HiveService.dettesBox.values, hasLength(1));

    // Annulation + nouvelle vente lancées « en même temps ». Scénario où
    // les deux aboutissent : 10 - 2 + 2 (annulation) - 3 (vente) = 7. Et
    // si l'ordre d'exécution s'inversait : 8 - 3 + 2 = 7 aussi — le
    // stock final attendu est identique dans les deux rotations.
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

    // La dette de la vente annulée a été supprimée exactement une fois.
    expect(HiveService.dettesBox.values, isEmpty);

    // Sur disque : stock et carnet cohérents.
    final produitsReouverts = await rouvrirProduitsSurDisque();
    expect(produitsReouverts.get(riz.id)!.stockActuel, 7);
    final dettesReouvertes = await rouvrirDettesSurDisque();
    expect(dettesReouvertes.values, isEmpty);
  });

  test("annulation qui échoue (produit supprimé pendant l'écriture) et "
      'vente concurrente réussie : le rollback ne réécrase jamais le '
      'stock de la vente réussie', () async {
    final produitService = ProduitService();
    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 20,
      devise: 'XOF',
    );
    final huile = await produitService.ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 10,
      devise: 'XOF',
    );

    final venteAnnulee = await CaisseService(produitService: produitService)
        .finaliserVente(
          panier: [itemPour(riz, 6), itemPour(huile, 5)],
          devise: 'XOF',
        );
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 14);
    expect(HiveService.produitsBox.get(huile.id)!.stockActuel, 5);

    // La fiche « Huile » disparaît entre la validation de l'annulation
    // (Phase 0 : les deux produits existent) et la remise en stock de la
    // deuxième ligne — le réapprovisionnement de l'huile échoue alors à
    // « Produit introuvable », APRÈS que le riz a déjà été remis.
    final serviceAvecSuppression = _ProduitServiceSuppressionSurvenue(huile.id);
    final caisseAnnulation = CaisseService(
      produitService: serviceAvecSuppression,
    );
    final caisseVente = CaisseService(produitService: produitService);

    final annulation = caisseAnnulation.annulerTransaction(
      transactionId: venteAnnulee.id,
      motif: 'Erreur de saisie',
    );
    final venteConcurrente = caisseVente.finaliserVente(
      panier: [itemPour(riz, 4)],
      devise: 'XOF',
    );

    await expectLater(
      annulation,
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Produit introuvable'),
        ),
      ),
    );

    // Le seul gagnant est le rollback sérialisé : le riz est restauré à
    // son niveau d'après-vente (14), PUIS la vente concurrente
    // décrémente — 14 - 4 = 10. Un rollback qui tournerait après la
    // vente (ou qui restaurerait un niveau pré-vente) aurait écrasé sa
    // décrémentation ; la vente annulable est terminated avant le
    // démarrage de la vente concurrente, verrou oblige.
    final venteSimultanee = await venteConcurrente;
    expect(venteSimultanee.montantTotalMineur, 4 * 750);
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 10);

    // Le produit supprimé n'a pas été ressuscité par le rollback, et la
    // vente annulable reste non annulée.
    expect(HiveService.produitsBox.get(huile.id), isNull);
    expect(HiveService.transactionsBox.get(venteAnnulee.id)!.annulee, isFalse);

    // Sur disque : mêmes valeurs que la mémoire.
    final produitsReouverts = await rouvrirProduitsSurDisque();
    expect(produitsReouverts.get(riz.id)!.stockActuel, 10);
    expect(produitsReouverts.get(huile.id), isNull);
    final transactionsReouvertes = await rouvrirTransactionsSurDisque();
    expect(transactionsReouvertes.get(venteAnnulee.id)!.annulee, isFalse);
    expect(transactionsReouvertes.get(venteSimultanee.id), isNotNull);
  });

  test('échec de remise en stock après écriture partielle : stocks restaurés '
      'en mémoire ET sur disque, transaction non annulée, erreur '
      "d'origine propagée", () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 20,
      devise: 'XOF',
    );
    final huile = await produitService.ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 15,
      devise: 'XOF',
    );

    final vente = await caisseService.finaliserVente(
      panier: [itemPour(riz, 2), itemPour(huile, 3)],
      devise: 'XOF',
    );
    const stockRizAvantAnnulation = 18;
    const stockHuileAvantAnnulation = 12;
    expect(
      produitService.trouverParId(riz.id)!.stockActuel,
      stockRizAvantAnnulation,
    );
    expect(
      produitService.trouverParId(huile.id)!.stockActuel,
      stockHuileAvantAnnulation,
    );

    // Le service défaillant remet réellement le stock du riz
    // (persisté) puis échoue sur l'huile : les deux restitutions sont
    // donc déjà inscrites quand le rollback démarre.
    final serviceDefectueux = _ProduitServiceRemiseDefectueuse(huile.id);
    await expectLater(
      CaisseService(
        produitService: serviceDefectueux,
      ).annulerTransaction(transactionId: vente.id, motif: 'Erreur de saisie'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(
            contains("Erreur disque simulée pendant la remise en stock"),
            isNot(contains('incomplète')),
          ),
        ),
      ),
    );

    // Mémoire : les deux stocks sont restaurés exactement.
    expect(
      produitService.trouverParId(riz.id)!.stockActuel,
      stockRizAvantAnnulation,
    );
    expect(
      produitService.trouverParId(huile.id)!.stockActuel,
      stockHuileAvantAnnulation,
    );

    // Disque : vérification avec des boxes réhydratées.
    final produitsReouverts = await rouvrirProduitsSurDisque();
    expect(produitsReouverts.get(riz.id)!.stockActuel, stockRizAvantAnnulation);
    expect(
      produitsReouverts.get(huile.id)!.stockActuel,
      stockHuileAvantAnnulation,
    );
    final transactionsReouvertes = await rouvrirTransactionsSurDisque();
    expect(transactionsReouvertes.get(vente.id)!.annulee, isFalse);

    // Pas de dette ici (vente au comptant) : le carnet reste vide.
    final dettesReouvertes = await rouvrirDettesSurDisque();
    expect(dettesReouvertes.values, isEmpty);
  });

  test('échec de suppression de dette après suppression effective : dette '
      "restaurée à l'identique (id, montant, statut, transactionId), "
      'stocks restaurés, transaction non annulée', () async {
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
      stockActuel: 20,
      devise: 'XOF',
    );

    final vente = await caisseService.finaliserVenteACredit(
      panier: [itemPour(riz, 2)],
      devise: 'XOF',
      nomClient: 'Aya',
      telephone: '+2250700000014',
    );
    final detteOriginale = detteService.trouverParTransactionId(vente.id)!;
    final idDette = detteOriginale.id;
    final statutDette = detteOriginale.statut;
    expect(produitService.trouverParId(riz.id)!.stockActuel, 18);

    // La suppression échoue APRÈS avoir retiré la dette de la box :
    // le rollback doit la réécrire telle quelle (même id) — jamais
    // DetteService.ajouter, qui créerait un nouvel id.
    final serviceDetteDefectueux = _DetteServiceSuppressionDefectueuse();
    await expectLater(
      CaisseService(
        produitService: produitService,
        detteService: serviceDetteDefectueux,
      ).annulerTransaction(transactionId: vente.id, motif: 'Erreur de saisie'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(
            contains(
              "Erreur disque simulée pendant la suppression de la dette",
            ),
            isNot(contains('incomplète')),
          ),
        ),
      ),
    );

    // Mémoire : le stock est restauré (snapshot = 18, pas la valeur
    // pré-vente 20) et la dette est réécrite telle quelle.
    expect(produitService.trouverParId(riz.id)!.stockActuel, 18);
    final detteRestauree = detteService.trouverParTransactionId(vente.id)!;
    expect(detteRestauree.id, idDette);
    expect(detteRestauree.montantDu, vente.montantTotal);
    expect(detteRestauree.statut, statutDette);
    expect(detteRestauree.transactionId, vente.id);
    expect(HiveService.dettesBox.get(idDette), isNotNull);

    // Disque : stock, dette et transaction cohérents.
    final produitsReouverts = await rouvrirProduitsSurDisque();
    expect(produitsReouverts.get(riz.id)!.stockActuel, 18);
    final dettesReouvertes = await rouvrirDettesSurDisque();
    final detteDisque = dettesReouvertes.get(idDette);
    expect(detteDisque, isNotNull);
    expect(detteDisque!.montantDu, vente.montantTotal);
    expect(detteDisque.transactionId, vente.id);
    final transactionsReouvertes = await rouvrirTransactionsSurDisque();
    expect(transactionsReouvertes.get(vente.id)!.annulee, isFalse);
  });

  test('échec du marquage final (box transactions fermée) : stocks et '
      'dette restaurés, transaction non annulée après réouverture, '
      "compensation incomplète signalée explicitement", () async {
    final produitService = ProduitService();
    final detteService = DetteService();

    final riz = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 20,
      devise: 'XOF',
    );

    final vente =
        await CaisseService(
          produitService: produitService,
          detteService: detteService,
        ).finaliserVenteACredit(
          panier: [itemPour(riz, 2)],
          devise: 'XOF',
          nomClient: 'Aya',
          telephone: '+2250700000015',
        );
    final dette = detteService.trouverParTransactionId(vente.id)!;
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 18);

    // La remise en stock réussit, PUIS la box transactions est fermée :
    // le marquage final (Phase 3) échoue, ET la nouvelle tentative de
    // sauvegarde du rollback échoue elle aussi (box toujours fermée) →
    // compensation incomplète, signalée explicitement avec l'erreur
    // d'origine.
    try {
      await expectLater(
        CaisseService(
          produitService: _ProduitServiceFermeurTransactions(riz.id),
          detteService: detteService,
        ).annulerTransaction(
          transactionId: vente.id,
          motif: 'Erreur de saisie',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('incomplète'),
              contains('restauration de la transaction'),
              isNot(contains('restauration du stock sur disque')),
              isNot(contains('réécriture de la dette')),
            ),
          ),
        ),
      );

      // Mémoire : stock restauré au niveau du snapshot (18, après la
      // vente, avant la tentative d'annulation) et dette réécrite.
      expect(produitService.trouverParId(riz.id)!.stockActuel, 18);
      expect(HiveService.dettesBox.get(dette.id), isNotNull);
    } finally {
      // Robustesse : quel que soit le résultat, la box transactions est
      // réouverte (typée) pour les vérifications et les tests suivants.
      if (!Hive.isBoxOpen(HiveBoxes.transactions)) {
        await Hive.openBox<model.Transaction>(HiveBoxes.transactions);
      }
    }

    // Disque : la transaction réhydratée n'est PAS annulée — la vente
    // reste comptée — et le stock comme la dette ont atteint le fichier.
    final produitsReouverts = await rouvrirProduitsSurDisque();
    expect(produitsReouverts.get(riz.id)!.stockActuel, 18);
    final dettesReouvertes = await rouvrirDettesSurDisque();
    expect(dettesReouvertes.values, hasLength(1));
    final transactionsReouvertes = await rouvrirTransactionsSurDisque();
    expect(transactionsReouvertes.get(vente.id)!.annulee, isFalse);
  });

  test('double annulation concurrente de la même vente : exactement une '
      'réussite, une erreur « déjà annulée », stock et dette touchés '
      'une seule fois', () async {
    final produitService = ProduitService();
    final detteService = DetteService();
    final caisseServiceA = CaisseService(
      produitService: produitService,
      detteService: detteService,
    );
    final caisseServiceB = CaisseService(
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

    final vente = await caisseServiceA.finaliserVenteACredit(
      panier: [itemPour(riz, 2)],
      devise: 'XOF',
      nomClient: 'Aya',
      telephone: '+2250700000016',
    );
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 8);

    final resultats = await Future.wait([
      caisseServiceA
          .annulerTransaction(transactionId: vente.id, motif: 'A')
          .then((_) => 'reussite', onError: (Object e) => 'echec: $e'),
      caisseServiceB
          .annulerTransaction(transactionId: vente.id, motif: 'B')
          .then((_) => 'reussite', onError: (Object e) => 'echec: $e'),
    ]);

    // Exactement une réussite, exactement un refus « déjà annulée ».
    expect(resultats.where((r) => r == 'reussite'), hasLength(1));
    final echecs = resultats.whereType<String>().where(
      (r) => r.startsWith('echec:'),
    );
    // UN seul échec, avec exactement ce motif.
    expect(echecs, hasLength(1));
    expect(echecs.single, contains('déjà annulée'));

    // La remise en stock n'a eu lieu qu'UNE fois : 8 + 2 = 10, pas 12.
    expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 10);
    // La dette a été supprimée une seule fois (donc absente à la fin).
    expect(HiveService.dettesBox.values, isEmpty);

    // Sur disque : mêmes valeurs.
    final produitsReouverts = await rouvrirProduitsSurDisque();
    expect(produitsReouverts.get(riz.id)!.stockActuel, 10);
    final dettesReouvertes = await rouvrirDettesSurDisque();
    expect(dettesReouvertes.values, isEmpty);
  });

  test('plusieurs lignes du même produit (casier + unités) : remise en '
      "stock agrégée — un seul réapprovisionnement, quantité exacte", () async {
    final produitService = _ProduitServiceEspion();
    final caisseService = CaisseService(produitService: produitService);

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

    // 1 casier (20 bouteilles) + 3 bouteilles du même Coca + 2 riz.
    final vente = await caisseService.finaliserVente(
      panier: [
        itemPour(
          coca,
          1,
          quantiteEnUniteBase: 20,
          prixUnitaireVente: 3000,
          prixUnitaireAchat: 1500,
        ),
        itemPour(coca, 3),
        itemPour(riz, 2),
      ],
      devise: 'XOF',
    );
    expect(produitService.trouverParId(coca.id)!.stockActuel, 77);
    expect(produitService.trouverParId(riz.id)!.stockActuel, 8);

    // La transaction contient bien deux LIGNES de Coca.
    expect(
      vente.itemsVendus.where((i) => i.produitId == coca.id),
      hasLength(2),
    );

    final annulee = await caisseService.annulerTransaction(
      transactionId: vente.id,
      motif: 'Erreur de saisie',
    );
    expect(annulee.annulee, isTrue);

    // Stock agrégé exact : 77 + (20 + 3) = 100 pour le Coca, 10 pour
    // le riz. L'espion a enregistré un SEUL appel par produit, avec la
    // quantité agrégée (pas de réappro par ligne).
    expect(produitService.trouverParId(coca.id)!.stockActuel, 100);
    expect(produitService.trouverParId(riz.id)!.stockActuel, 10);
    expect(
      produitService.appelsRemise,
      unorderedEquals(['${coca.id}:23', '${riz.id}:2']),
    );

    // Sur disque : les stocks agrégés ont bien atteint le fichier.
    final produitsReouverts = await rouvrirProduitsSurDisque();
    expect(produitsReouverts.get(coca.id)!.stockActuel, 100);
    expect(produitsReouverts.get(riz.id)!.stockActuel, 10);
    final transactionsReouvertes = await rouvrirTransactionsSurDisque();
    expect(transactionsReouvertes.get(vente.id)!.annulee, isTrue);
  });

  test(
    'vente à crédit sans dette liée (dette déjà absente) : '
    "l'annulation remet le stock et marque la transaction, sans erreur",
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

      final vente = await caisseService.finaliserVenteACredit(
        panier: [itemPour(riz, 2)],
        devise: 'XOF',
        nomClient: 'Aya',
        telephone: '+2250700000017',
      );
      expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 8);

      // La dette a disparu du carnet avant l'annulation (suppression
      // directe, comme si elle avait été purgée par un maniement hors
      // périmètre).
      final dette = HiveService.dettesBox.values.singleWhere(
        (d) => d.transactionId == vente.id,
      );
      await HiveService.dettesBox.delete(dette.id);
      expect(HiveService.dettesBox.values, isEmpty);

      // Aucune erreur : pas de dette à supprimer, la Phase 2 est
      // simplement sans objet.
      final annulee = await caisseService.annulerTransaction(
        transactionId: vente.id,
        motif: 'Erreur de saisie',
      );

      expect(annulee.annulee, isTrue);
      expect(annulee.motifAnnulation, 'Erreur de saisie');
      expect(HiveService.produitsBox.get(riz.id)!.stockActuel, 10);
      expect(HiveService.transactionsBox.get(vente.id)!.annulee, isTrue);
      expect(caisseService.totalDuJourMineur(), 0);
      expect(caisseService.toutesLesTransactions().single.annulee, isTrue);

      // Sur disque : stock restauré et transaction marquée.
      final produitsReouverts = await rouvrirProduitsSurDisque();
      expect(produitsReouverts.get(riz.id)!.stockActuel, 10);
      final transactionsReouvertes = await rouvrirTransactionsSurDisque();
      expect(transactionsReouvertes.get(vente.id)!.annulee, isTrue);
      expect(
        transactionsReouvertes.get(vente.id)!.motifAnnulation,
        'Erreur de saisie',
      );
    },
  );
}
