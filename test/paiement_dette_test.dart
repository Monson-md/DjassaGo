// Test de la Phase 3 : chaque paiement (total ou partiel) contre une dette
// est conservé dans un historique PaiementDette immuable, distinct du solde
// courant de la Dette.

import 'dart:io';

import 'package:caisse_de_poche/models/dette.dart';
import 'package:caisse_de_poche/services/dette_service.dart';
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
        .createTemp('caisse_de_poche_paiement_dette_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('enregistrerPaiement conserve un historique PaiementDette', () async {
    final detteService = DetteService();
    final dette = await detteService.ajouter(
      nomClient: 'Fatou',
      telephone: '+2250700000002',
      montantDu: 1000,
      devise: 'XOF',
    );

    await detteService.enregistrerPaiement(dette, 400);

    final paiements = detteService.paiementsPour(dette.id);
    expect(paiements, hasLength(1));
    expect(paiements.first.montant, 400);
    expect(dette.montantDu, 600);
    expect(dette.statut, StatutDette.partiellementPayee);

    await detteService.enregistrerPaiement(dette, 600);
    expect(detteService.paiementsPour(dette.id), hasLength(2));
    expect(dette.montantDu, 0);
    expect(dette.statut, StatutDette.payee);
  });
}
