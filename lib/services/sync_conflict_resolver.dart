/// Résolution des conflits de synchronisation (Phase 9, préparation — voir
/// lib/services/sync_service.dart). Logique pure, sans dépendance à Hive ni
/// à un vrai transport réseau, pour être testable indépendamment du jour où
/// une synchronisation réelle sera branchée.
enum ResultatResolutionConflit { conserverLocal, conserverDistant }

class SyncConflictResolver {
  SyncConflictResolver._();

  /// Dernier écrit gagne (last-write-wins), comparé sur `lastModified`.
  /// En cas d'égalité stricte (même horodatage, par exemple deux
  /// enregistrements jamais modifiés depuis leur création), l'ordre
  /// alphabétique du deviceId départage de façon déterministe — pour ne
  /// jamais dépendre de l'ordre d'arrivée réseau.
  static ResultatResolutionConflit resoudre({
    required DateTime? lastModifiedLocal,
    required String deviceIdLocal,
    required DateTime? lastModifiedDistant,
    required String deviceIdDistant,
  }) {
    if (lastModifiedLocal == null && lastModifiedDistant == null) {
      return ResultatResolutionConflit.conserverLocal;
    }
    if (lastModifiedLocal == null) {
      return ResultatResolutionConflit.conserverDistant;
    }
    if (lastModifiedDistant == null) {
      return ResultatResolutionConflit.conserverLocal;
    }
    if (lastModifiedLocal.isAfter(lastModifiedDistant)) {
      return ResultatResolutionConflit.conserverLocal;
    }
    if (lastModifiedDistant.isAfter(lastModifiedLocal)) {
      return ResultatResolutionConflit.conserverDistant;
    }
    return deviceIdLocal.compareTo(deviceIdDistant) <= 0
        ? ResultatResolutionConflit.conserverLocal
        : ResultatResolutionConflit.conserverDistant;
  }
}
