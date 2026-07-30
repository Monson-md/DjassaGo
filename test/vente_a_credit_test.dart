// Test de la Phase 3 : une vente "mise en dette" décrémente le stock comme
// une vente normale et crée une Dette liée à la transaction d'origine.

import 'dart:io';

import 'package:caisse_de_poche/models/dette.dart';
import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/models/mode_paiement.dart';
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
    tempDir =
        await Directory.systemTemp.createTemp('caisse_de_poche_credit_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('finaliserVenteACredit décrémente le stock et crée une dette liée',
      () async {
    final produitService = ProduitService();
    final detteService = DetteService();
    final caisseService = CaisseService(
      produitService: produitService,
      detteService: detteService,
    );

    final produit = await produitService.ajouter(
      nom: 'Riz 1kg',
      prixAchat: 500,
      prixVente: 750,
      stockActuel: 10,
      devise: 'XOF',
    );
    final item = ItemVendu(
      produitId: produit.id,
      nomProduit: produit.nom,
      quantite: 2,
      prixUnitaireVente: produit.prixVente,
      prixUnitaireAchat: produit.prixAchat,
    );

    final transaction = await caisseService.finaliserVenteACredit(
      panier: [item],
      devise: 'XOF',
      nomClient: 'Awa',
      telephone: '+2250700000000',
    );

    expect(transaction.modePaiement, ModePaiement.credit);
    expect(produitService.trouverParId(produit.id)!.stockActuel, 8);

    final dettes = detteService.listerToutes();
    expect(dettes, hasLength(1));
    expect(dettes.first.transactionId, transaction.id);
    expect(dettes.first.montantDu, transaction.montantTotal);
    expect(dettes.first.statut, StatutDette.enCours);
  });
}
