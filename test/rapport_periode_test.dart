// Test de la Phase 7 : le tableau de bord (CA, marge brute, dépenses)
// n'agrège que ce qui tombe dans la période demandée (jour/semaine/mois),
// à partir d'une date de référence fixe pour un test déterministe.

import 'dart:io';

import 'package:caisse_de_poche/models/categorie_depense.dart';
import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/services/caisse_service.dart';
import 'package:caisse_de_poche/services/depense_service.dart';
import 'package:caisse_de_poche/services/hive_service.dart';
import 'package:caisse_de_poche/services/produit_service.dart';
import 'package:caisse_de_poche/utils/periodes.dart';
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
        await Directory.systemTemp.createTemp('caisse_de_poche_rapport_test');
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
      "totalMineurSur/margeBruteMineurSur (CaisseService) et "
      'totalMineurSur (DepenseService) ne comptent que la période demandée',
      () async {
    // Jeudi 30 juillet 2026 : référence fixe pour un test déterministe.
    final reference = DateTime(2026, 7, 30, 10);
    final produitService = ProduitService();
    final caisseService = CaisseService(produitService: produitService);
    final depenseService = DepenseService();

    final produit = await produitService.ajouter(
      nom: 'Sac de riz',
      prixAchat: 8000,
      prixVente: 10000,
      stockActuel: 30,
      devise: 'XOF',
    );
    ItemVendu item() => ItemVendu(
          produitId: produit.id,
          nomProduit: produit.nom,
          quantite: 1,
          prixUnitaireVente: produit.prixVente,
          prixUnitaireAchat: produit.prixAchat,
        );

    Future<void> venteA(DateTime date) async {
      final transaction =
          await caisseService.finaliserVente(panier: [item()], devise: 'XOF');
      transaction.date = date;
      await transaction.save();
    }

    // Aujourd'hui (jeudi 30/07), dans la semaine du 27/07 au 02/08, et dans
    // le mois de juillet.
    await venteA(reference);
    // Semaine précédente (lundi 20/07), toujours en juillet.
    await venteA(DateTime(2026, 7, 20));
    // Mois précédent (juin).
    await venteA(DateTime(2026, 6, 15));

    await depenseService.ajouter(
      libelle: 'Facture électricité',
      montant: 5000,
      categorie: CategorieDepense.electricite,
      devise: 'XOF',
      date: reference,
    );
    await depenseService.ajouter(
      libelle: 'Loyer de juin',
      montant: 20000,
      categorie: CategorieDepense.loyer,
      devise: 'XOF',
      date: DateTime(2026, 6, 10),
    );

    // Jour : seule la vente/dépense d'aujourd'hui.
    expect(
        caisseService.totalMineurSur(Periode.jour, reference: reference),
        10000);
    expect(
        caisseService.margeBruteMineurSur(Periode.jour, reference: reference),
        2000);
    expect(
        depenseService.totalMineurSur(Periode.jour, reference: reference),
        5000);

    // Semaine : aujourd'hui, mais pas la vente de la semaine précédente.
    expect(
        caisseService.totalMineurSur(Periode.semaine, reference: reference),
        10000);

    // Mois : les deux ventes de juillet, mais pas celle de juin.
    expect(
        caisseService.totalMineurSur(Periode.mois, reference: reference),
        20000);
    expect(
        caisseService.margeBruteMineurSur(Periode.mois, reference: reference),
        4000);
    // Dépenses de juillet seulement (la facture d'électricité), pas le
    // loyer de juin.
    expect(
        depenseService.totalMineurSur(Periode.mois, reference: reference),
        5000);
  });
}
