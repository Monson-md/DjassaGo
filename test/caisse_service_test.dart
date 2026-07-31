// Test de la Phase 10 : CaisseService.finaliserVente — total et marge
// brute calculés à partir des prix figés dans ItemVendu (pas du prix
// courant du produit), cas du panier vide, et quantités multiples.

import 'dart:io';

import 'package:caisse_de_poche/models/item_vendu.dart';
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('caisse_de_poche_caisse_test');
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
      'finaliserVente : total/marge sur quantités multiples et prix figés ; '
      'panier vide rejeté', () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);

    final sac = await produitService.ajouter(
      nom: 'Sac de riz',
      prixAchat: 8000,
      prixVente: 10000,
      stockActuel: 50,
      devise: 'XOF',
    );
    final huile = await produitService.ajouter(
      nom: "Bidon d'huile",
      prixAchat: 3000,
      prixVente: 4000,
      stockActuel: 20,
      devise: 'XOF',
    );

    final panier = [
      ItemVendu(
        produitId: sac.id,
        nomProduit: sac.nom,
        quantite: 3,
        prixUnitaireVente: sac.prixVente,
        prixUnitaireAchat: sac.prixAchat,
      ),
      ItemVendu(
        produitId: huile.id,
        nomProduit: huile.nom,
        quantite: 2,
        prixUnitaireVente: huile.prixVente,
        prixUnitaireAchat: huile.prixAchat,
      ),
    ];

    final transaction =
        await caisseService.finaliserVente(panier: panier, devise: 'XOF');

    // Total : 3*10000 + 2*4000 = 38000. Marge : 3*2000 + 2*1000 = 8000.
    expect(transaction.montantTotal, 38000);
    expect(transaction.margeBrute, 8000);
    expect(transaction.montantTotalMineur, 38000);
    expect(transaction.margeBruteMineur, 8000);

    final stockRestantSac = produitService.trouverParId(sac.id)!;
    final stockRestantHuile = produitService.trouverParId(huile.id)!;
    expect(stockRestantSac.stockActuel, 47);
    expect(stockRestantHuile.stockActuel, 18);

    // Le prix d'achat/vente du produit change ensuite : la transaction déjà
    // enregistrée ne doit jamais être recalculée depuis le prix courant.
    sac.definirPrix(prixAchat: 9000, prixVente: 12000);
    await sac.save();
    expect(transaction.montantTotal, 38000);
    expect(transaction.margeBrute, 8000);

    // Panier vide : rejeté avant tout effet de bord (aucun stock touché).
    // finaliserVente est async : l'exception est levée de façon
    // asynchrone, donc on passe le Future lui-même au matcher plutôt
    // qu'une closure (qui ne capterait qu'un throw synchrone).
    await expectLater(
      caisseService.finaliserVente(panier: [], devise: 'XOF'),
      throwsA(isA<Exception>()),
    );
  });
}
