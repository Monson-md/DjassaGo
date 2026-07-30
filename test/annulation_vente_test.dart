// Test de la Phase 4 : annuler une vente remet le stock, marque la
// transaction comme annulée sans jamais la supprimer, l'exclut des
// statistiques du jour mais la garde consultable dans le journal.

import 'dart:io';

import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/services/caisse_service.dart';
import 'package:caisse_de_poche/services/produit_service.dart';
import 'package:caisse_de_poche/services/hive_service.dart';
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
        .createTemp('caisse_de_poche_annulation_test');
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
      'annulerTransaction remet le stock, exclut la vente des statistiques '
      "mais la garde dans le journal ; une deuxième annulation échoue",
      () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

    final produit = await produitService.ajouter(
      nom: 'Huile 1L',
      prixAchat: 700,
      prixVente: 1000,
      stockActuel: 10,
      devise: 'XOF',
    );
    ItemVendu item(int quantite) => ItemVendu(
          produitId: produit.id,
          nomProduit: produit.nom,
          quantite: quantite,
          prixUnitaireVente: produit.prixVente,
          prixUnitaireAchat: produit.prixAchat,
        );

    final venteAnnulee =
        await caisseService.finaliserVente(panier: [item(3)], devise: 'XOF');
    final venteConservee =
        await caisseService.finaliserVente(panier: [item(2)], devise: 'XOF');

    expect(produitService.trouverParId(produit.id)!.stockActuel, 5);
    expect(
        caisseService.totalDuJourMineur(),
        venteAnnulee.montantTotalMineur +
            venteConservee.montantTotalMineur);

    final annulee = await caisseService.annulerTransaction(
      transactionId: venteAnnulee.id,
      motif: 'Erreur de saisie',
    );

    expect(annulee.annulee, isTrue);
    expect(annulee.motifAnnulation, 'Erreur de saisie');
    expect(annulee.dateAnnulation, isNotNull);
    // Le stock est remis : 10 - 3 - 2 + 3 = 8.
    expect(produitService.trouverParId(produit.id)!.stockActuel, 8);

    // Statistiques : seule la vente restante compte désormais.
    expect(caisseService.totalDuJourMineur(), venteConservee.montantTotalMineur);
    expect(caisseService.beneficeNetDuJourMineur(),
        venteConservee.beneficeNetMineur);

    // Journal : les deux ventes restent consultables.
    final journal = caisseService.toutesLesTransactions();
    expect(journal.map((t) => t.id),
        containsAll([venteAnnulee.id, venteConservee.id]));

    await expectLater(
      () => caisseService.annulerTransaction(
        transactionId: venteAnnulee.id,
        motif: 'Nouvelle tentative',
      ),
      throwsException,
    );
  });
}
