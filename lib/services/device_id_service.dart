import 'package:uuid/uuid.dart';

import '../config/hive_boxes.dart';
import 'hive_service.dart';

/// Identifiant stable de cet appareil, généré une seule fois et persisté
/// dans la box paramètres. Sert de départage lors d'un conflit de
/// synchronisation à horodatage identique (Phase 9, préparation — voir
/// lib/services/sync_conflict_resolver.dart). N'a aucun effet tant
/// qu'aucune synchronisation réelle n'est activée.
class DeviceIdService {
  DeviceIdService._();

  static const _uuid = Uuid();
  static String? _cache;

  static String obtenir() {
    if (_cache != null) return _cache!;
    final box = HiveService.parametresBox;
    var id = box.get(ParametresKeys.deviceId) as String?;
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      box.put(ParametresKeys.deviceId, id);
    }
    _cache = id;
    return id;
  }
}
