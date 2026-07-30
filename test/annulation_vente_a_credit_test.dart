// Test de la Phase 4 : annuler une vente à crédit supprime la dette liée
// tant qu'aucun paiement n'a été reçu, mais bloque l'annulation si un
// paiement a déjà été enregistré (pour ne pas faire disparaître un
// encaissement réel).

import 'dart:io';

import 'package:caisse_de_poche/models/item_vendu.dart';
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp
        .createTemp('caisse_de_poche_annulation_credit_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
      'annulerTransaction supprime la dette liée sans paiement, mais est '
      'bloquée si un paiement existe déjà', () async {
    final produitService = ProduitService();
    final detteService = DetteService();
    final caisseService = CaisseService(
      produitService: produitService,
      detteService: detteService,
    );

    final produit = await produitService.ajouter(
      nom: 'Savon',
      prixAchat: 300,
      prixVente: 500,
      stockActuel: 20,
      devise: 'XOF',
    );
    ItemVendu item() => ItemVendu(
          produitId: produit.id,
          nomProduit: produit.nom,
          quantite: 1,
          prixUnitaireVente: produit.prixVente,
          prixUnitaireAchat: produit.prixAchat,
        );

    // Cas 1 : dette sans paiement -> l'annulation la supprime.
    final venteSansPaiement = await caisseService.finaliserVenteACredit(
      panier: [item()],
      devise: 'XOF',
      nomClient: 'Aya',
      telephone: '+2250700000010',
    );
    expect(
        detteService.trouverParTransactionId(venteSansPaiement.id), isNotNull);

    await caisseService.annulerTransaction(
      transactionId: venteSansPaiement.id,
      motif: 'Client a changé d\'avis',
    );

    expect(
        detteService.trouverParTransactionId(venteSansPaiement.id), isNull);
    expect(produitService.trouverParId(produit.id)!.stockActuel, 20);

    // Cas 2 : dette déjà partiellement payée -> l'annulation est bloquée.
    final venteAvecPaiement = await caisseService.finaliserVenteACredit(
      panier: [item()],
      devise: 'XOF',
      nomClient: 'Koffi',
      telephone: '+2250700000011',
    );
    final detteAvecPaiement =
        detteService.trouverParTransactionId(venteAvecPaiement.id)!;
    await detteService.enregistrerPaiement(detteAvecPaiement, 200);

    await expectLater(
      () => caisseService.annulerTransaction(
        transactionId: venteAvecPaiement.id,
        motif: 'Tentative bloquée',
      ),
      throwsException,
    );

    // Rien n'a bougé : ni la dette, ni le stock, ni la transaction.
    expect(detteAvecPaiement.montantDu, 300);
    expect(produitService.trouverParId(produit.id)!.stockActuel, 19);
    expect(
        HiveService.transactionsBox.get(venteAvecPaiement.id)!.annulee,
        isFalse);
  });
}
