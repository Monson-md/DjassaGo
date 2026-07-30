// Test de la Phase 9 : résolution des conflits de synchronisation
// (préparation uniquement, aucun transport réseau réel) — logique pure de
// "dernier écrit gagne", sans dépendance à Hive.

import 'package:caisse_de_poche/services/sync_conflict_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conserve la version la plus récente (locale plus récente)', () {
    final resultat = SyncConflictResolver.resoudre(
      lastModifiedLocal: DateTime(2026, 7, 30, 10),
      deviceIdLocal: 'appareil-a',
      lastModifiedDistant: DateTime(2026, 7, 30, 9),
      deviceIdDistant: 'appareil-b',
    );
    expect(resultat, ResultatResolutionConflit.conserverLocal);
  });

  test('conserve la version la plus récente (distante plus récente)', () {
    final resultat = SyncConflictResolver.resoudre(
      lastModifiedLocal: DateTime(2026, 7, 30, 9),
      deviceIdLocal: 'appareil-a',
      lastModifiedDistant: DateTime(2026, 7, 30, 10),
      deviceIdDistant: 'appareil-b',
    );
    expect(resultat, ResultatResolutionConflit.conserverDistant);
  });

  test('égalité stricte : départage déterministe par deviceId', () {
    final meme = DateTime(2026, 7, 30, 10);
    expect(
      SyncConflictResolver.resoudre(
        lastModifiedLocal: meme,
        deviceIdLocal: 'aaa',
        lastModifiedDistant: meme,
        deviceIdDistant: 'zzz',
      ),
      ResultatResolutionConflit.conserverLocal,
    );
    expect(
      SyncConflictResolver.resoudre(
        lastModifiedLocal: meme,
        deviceIdLocal: 'zzz',
        lastModifiedDistant: meme,
        deviceIdDistant: 'aaa',
      ),
      ResultatResolutionConflit.conserverDistant,
    );
  });

  test('lastModified absent d\'un côté : l\'autre gagne toujours', () {
    expect(
      SyncConflictResolver.resoudre(
        lastModifiedLocal: null,
        deviceIdLocal: 'a',
        lastModifiedDistant: DateTime(2026, 1, 1),
        deviceIdDistant: 'b',
      ),
      ResultatResolutionConflit.conserverDistant,
    );
    expect(
      SyncConflictResolver.resoudre(
        lastModifiedLocal: DateTime(2026, 1, 1),
        deviceIdLocal: 'a',
        lastModifiedDistant: null,
        deviceIdDistant: 'b',
      ),
      ResultatResolutionConflit.conserverLocal,
    );
  });

  test('lastModified absent des deux côtés : conserve local par défaut', () {
    final resultat = SyncConflictResolver.resoudre(
      lastModifiedLocal: null,
      deviceIdLocal: 'a',
      lastModifiedDistant: null,
      deviceIdDistant: 'b',
    );
    expect(resultat, ResultatResolutionConflit.conserverLocal);
  });
}
