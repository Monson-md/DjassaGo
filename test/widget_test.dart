// Test de fumée : vérifie que l'application démarre et affiche l'écran
// d'accueil (onboarding pays/devise) lors du tout premier lancement.

import 'dart:io';

import 'package:caisse_de_poche/main.dart';
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
    tempDir = await Directory.systemTemp.createTemp('caisse_de_poche_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets("Affiche l'écran d'onboarding au premier lancement",
      (WidgetTester tester) async {
    await tester.pumpWidget(const CaisseDePocheApp());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue sur Caisse de Poche'), findsOneWidget);
  });
}
