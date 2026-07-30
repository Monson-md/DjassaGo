// Test de la Phase 7 : CRUD de base du carnet de dépenses.

import 'dart:io';

import 'package:caisse_de_poche/models/categorie_depense.dart';
import 'package:caisse_de_poche/services/depense_service.dart';
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
    tempDir =
        await Directory.systemTemp.createTemp('caisse_de_poche_depense_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('ajouter/supprimer une dépense, montant en unités mineures figé',
      () async {
    final service = DepenseService();

    expect(service.listerToutes(), isEmpty);

    final depense = await service.ajouter(
      libelle: 'Transport marchandises',
      montant: 2500,
      categorie: CategorieDepense.transport,
      devise: 'XOF',
    );

    expect(service.listerToutes(), hasLength(1));
    expect(depense.montantMineur, 2500); // XOF : 0 décimale.
    expect(depense.categorie, CategorieDepense.transport);

    await service.supprimer(depense.id);
    expect(service.listerToutes(), isEmpty);
  });
}
