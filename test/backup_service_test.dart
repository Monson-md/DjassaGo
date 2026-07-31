// Test de la Phase 10 : export puis import d'une sauvegarde, sans perte
// de données (produits, ventes, dettes, paiements de dette, dépenses).

import 'dart:io';

import 'package:caisse_de_poche/models/categorie_depense.dart';
import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/services/backup_service.dart';
import 'package:caisse_de_poche/services/caisse_service.dart';
import 'package:caisse_de_poche/services/depense_service.dart';
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
        await Directory.systemTemp.createTemp('caisse_de_poche_backup_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('export puis import (remplacement) restaure toutes les données',
      () async {
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);
    final detteService = DetteService();
    final depenseService = DepenseService();
    final backupService = BackupService();

    final produit = await produitService.ajouter(
      nom: 'Sac de riz',
      prixAchat: 8000,
      prixVente: 10000,
      stockActuel: 30,
      devise: 'XOF',
    );
    await caisseService.finaliserVente(
      panier: [
        ItemVendu(
          produitId: produit.id,
          nomProduit: produit.nom,
          quantite: 2,
          prixUnitaireVente: produit.prixVente,
          prixUnitaireAchat: produit.prixAchat,
        ),
      ],
      devise: 'XOF',
    );
    final dette = await detteService.ajouter(
      nomClient: 'Kouassi',
      telephone: '',
      montantDu: 3000,
      devise: 'XOF',
    );
    await detteService.enregistrerPaiement(dette, 1000);
    await depenseService.ajouter(
      libelle: 'Transport',
      montant: 500,
      categorie: CategorieDepense.transport,
      devise: 'XOF',
    );

    final fichier = await backupService.exporter();

    // Remplacement : vide tout, puis restaure depuis le fichier exporté.
    await HiveService.produitsBox.clear();
    await HiveService.transactionsBox.clear();
    await HiveService.dettesBox.clear();
    await HiveService.paiementsDetteBox.clear();
    await HiveService.depensesBox.clear();
    expect(produitService.listerTous(), isEmpty);

    await backupService.restaurer(fichier, remplacer: true);

    expect(produitService.listerTous(), hasLength(1));
    expect(produitService.listerTous().first.nom, 'Sac de riz');
    expect(produitService.listerTous().first.stockActuel, 28);

    expect(caisseService.toutesLesTransactions(), hasLength(1));
    expect(caisseService.toutesLesTransactions().first.montantTotal, 20000);

    expect(detteService.listerToutes(), hasLength(1));
    final detteRestauree = detteService.listerToutes().first;
    expect(detteRestauree.montantDu, 2000);
    expect(detteService.paiementsPour(detteRestauree.id), hasLength(1));

    expect(depenseService.listerToutes(), hasLength(1));
    expect(depenseService.listerToutes().first.montant, 500);
  });
}
