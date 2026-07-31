// Test de la Phase Conditionnements : import d'une sauvegarde au format v1
// (antérieure à cette phase, sans clé 'conditionnements' et sans champ
// 'uniteBase' sur le produit) — doit rester importable, avec un
// conditionnement unique de quantité 1 créé automatiquement.

import 'dart:convert';
import 'dart:io';

import 'package:caisse_de_poche/services/backup_service.dart';
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
        .createTemp('caisse_de_poche_conditionnement_import_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('import d\'une sauvegarde à l\'ancien format (sans conditionnements)',
      () async {
    final produitService = ProduitService();
    final conditionnementService = ConditionnementService();
    final backupService = BackupService();

    final ancienneSauvegarde = {
      'formatVersion': 1,
      'exporteLe': DateTime.now().toIso8601String(),
      'produits': [
        {
          'id': 'p-ancien',
          'nom': 'Farine',
          'prixAchat': 500.0,
          'prixVente': 700.0,
          'stockActuel': 25,
          'devise': 'XOF',
          'dateCreation': DateTime.now().toIso8601String(),
          'dateModification': null,
          'synchronise': false,
          'prixAchatMineur': 500,
          'prixVenteMineur': 700,
          'deviceId': '',
          'lastModified': null,
          // Pas de champ 'uniteBase' : sauvegarde antérieure à cette phase.
        },
      ],
      'transactions': [],
      'dettes': [],
      // Pas de clé 'conditionnements' du tout.
    };

    final fichier = File('${tempDir.path}/ancienne_sauvegarde.json');
    await fichier.writeAsString(jsonEncode(ancienneSauvegarde));

    await backupService.restaurer(fichier, remplacer: true);

    final produit = produitService.trouverParId('p-ancien');
    expect(produit, isNotNull);
    expect(produit!.uniteBase, 'unité');

    final conditionnements = conditionnementService.listerPour('p-ancien');
    expect(conditionnements, hasLength(1));
    expect(conditionnements.first.quantiteEnUniteBase, 1);
    expect(conditionnements.first.prixVente, 700);
  });
}
