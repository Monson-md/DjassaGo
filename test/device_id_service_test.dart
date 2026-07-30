// Test de la Phase 9 : l'identifiant d'appareil est généré une seule fois
// et reste stable d'un appel à l'autre (nécessaire pour le départage des
// conflits de synchronisation — voir sync_conflict_resolver_test.dart).

import 'dart:io';

import 'package:caisse_de_poche/services/device_id_service.dart';
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
        .createTemp('caisse_de_poche_device_id_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('obtenir() génère un identifiant non vide et le garde stable', () {
    final id1 = DeviceIdService.obtenir();
    expect(id1, isNotEmpty);

    final id2 = DeviceIdService.obtenir();
    expect(id2, id1);

    final stocke =
        HiveService.parametresBox.get('device_id') as String?;
    expect(stocke, id1);
  });
}
