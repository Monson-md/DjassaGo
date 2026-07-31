// Test de la Phase Conditionnements : migration (idempotente) d'un produit
// existant sans conditionnement enregistré.

import 'dart:io';

import 'package:caisse_de_poche/services/conditionnement_service.dart';
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
        .createTemp('caisse_de_poche_conditionnement_migration_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('migration d\'un produit existant sans conditionnement', () async {
    final produitService = ProduitService();
    final conditionnementService = ConditionnementService();

    final produit = await produitService.ajouter(
      nom: 'Savon',
      prixAchat: 200,
      prixVente: 300,
      stockActuel: 40,
      devise: 'XOF',
    );
    expect(conditionnementService.listerPour(produit.id), isEmpty);

    final cree = await conditionnementService.migrerSiAbsent(produit);
    expect(cree.quantiteEnUniteBase, 1);
    expect(cree.prixVente, 300);
    expect(cree.parDefaut, true);
    expect(conditionnementService.listerPour(produit.id), hasLength(1));

    // Idempotent : un second appel ne crée rien de plus.
    final rappel = await conditionnementService.migrerSiAbsent(produit);
    expect(rappel.id, cree.id);
    expect(conditionnementService.listerPour(produit.id), hasLength(1));
  });
}
