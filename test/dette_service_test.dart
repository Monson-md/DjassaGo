// Test de la Phase 10 : DetteService — normalisation E.164 à l'ajout
// (au-delà du test unitaire pur de lib/utils/telephone.dart, voir
// telephone_test.dart) et génération du message de relance.

import 'dart:io';

import 'package:caisse_de_poche/config/hive_boxes.dart';
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
    tempDir =
        await Directory.systemTemp.createTemp('caisse_de_poche_dette_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await HiveService.init();
    await HiveService.parametresBox.put(ParametresKeys.paysCode, 'CI');
    await HiveService.parametresBox.put(ParametresKeys.indicatifPays, '225');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('ajouter() normalise le numéro en E.164 et enregistrerPaiement gère un paiement partiel',
      () async {
    final service = DetteService();

    final dette = await service.ajouter(
      nomClient: 'Aminata',
      telephone: '07 12 34 56 78',
      montantDu: 500,
      devise: 'XOF',
    );
    expect(dette.telephone, '+225712345678');

    // Génération du message de relance : reprend le nom, le montant et la
    // date, prêt à être envoyé tel quel par WhatsApp/SMS. Montant < 1000
    // pour éviter toute hypothèse sur le caractère exact du séparateur de
    // milliers de la locale fr_FR (espace normale ou insécable).
    final message = service.genererMessageRelance(dette);
    expect(message, contains('Aminata'));
    expect(message, contains('500'));

    await service.enregistrerPaiement(dette, 200);
    expect(dette.montantDu, 300);
    expect(dette.statut, StatutDette.partiellementPayee);
    expect(service.paiementsPour(dette.id), hasLength(1));

    await service.enregistrerPaiement(dette, 300);
    expect(dette.montantDu, 0);
    expect(dette.statut, StatutDette.payee);
    expect(service.paiementsPour(dette.id), hasLength(2));
  });
}
