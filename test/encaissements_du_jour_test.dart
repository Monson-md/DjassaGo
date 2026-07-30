// Test de la Phase 3 : le chiffre d'affaires du jour compte les ventes à
// crédit dès la vente, mais les encaissements du jour ne comptent que
// l'argent réellement reçu (ventes au comptant + paiements de dettes).

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
        .createTemp('caisse_de_poche_encaissements_test');
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
      'le CA du jour compte les ventes à crédit, mais les encaissements du '
      "jour n'incluent que l'argent réellement reçu", () async {
    final produitService = ProduitService();
    final detteService = DetteService();
    final caisseService = CaisseService(
      produitService: produitService,
      detteService: detteService,
    );

    final produit = await produitService.ajouter(
      nom: 'Sucre 1kg',
      prixAchat: 400,
      prixVente: 600,
      stockActuel: 10,
      devise: 'XOF',
    );
    ItemVendu item() => ItemVendu(
          produitId: produit.id,
          nomProduit: produit.nom,
          quantite: 1,
          prixUnitaireVente: produit.prixVente,
          prixUnitaireAchat: produit.prixAchat,
        );

    final venteCredit = await caisseService.finaliserVenteACredit(
      panier: [item()],
      devise: 'XOF',
      nomClient: 'Koffi',
      telephone: '+2250700000001',
    );
    await caisseService.finaliserVente(panier: [item()], devise: 'XOF');

    // CA du jour : les deux ventes comptent, encaissée ou non.
    expect(caisseService.totalDuJourMineur(),
        venteCredit.montantTotalMineur + 600);
    // Encaissements du jour : seule la vente au comptant a rapporté du cash.
    expect(caisseService.encaissementsDuJourMineur(), 600);

    final dette = detteService
        .listerToutes()
        .firstWhere((d) => d.transactionId == venteCredit.id);
    await detteService.enregistrerPaiement(dette, 300);

    // Le paiement de dette est un encaissement, jamais une nouvelle vente.
    expect(caisseService.totalDuJourMineur(),
        venteCredit.montantTotalMineur + 600);
    expect(caisseService.encaissementsDuJourMineur(), 600 + 300);
  });
}
