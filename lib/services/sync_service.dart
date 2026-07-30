import '../config/feature_flags.dart';

/// Service de synchronisation cloud.
///
/// Firebase (firebase_core, cloud_firestore) et connectivity_plus ont été
/// retirés du projet (voir CHECKLIST.md) : l'initialisation native de
/// Firebase pouvait faire échouer le démarrage de l'application sans
/// configuration valide (pas de firebase_options.dart), ce qui provoquait
/// un crash silencieux au lancement sur un appareil réel.
///
/// La Phase 9 a préparé l'architecture d'une synchronisation
/// **bidirectionnelle** (contrairement à l'ancien envoi à sens unique vers
/// Firestore, qui ne permettait aucune restauration) : chaque enregistrement
/// syncable porte désormais un `deviceId` et un `lastModified` (voir
/// Produit, Transaction, Dette, PaiementDette, Depense), et
/// [SyncConflictResolver] sait déjà trancher deux versions divergentes par
/// « dernier écrit gagne ». Ce qui manque encore est le seul transport
/// réseau réel — volontairement absent tant qu'aucun projet Firebase n'est
/// configuré. Tant que [syncActivee] est faux, cette classe ne fait jamais
/// rien : l'application fonctionne entièrement hors-ligne. Ne pas activer
/// ce drapeau avant que le propriétaire ait lancé `flutterfire configure`
/// sur son propre projet.
class SyncService {
  Future<void> demarrer() async {
    if (!syncActivee) return;
  }

  void arreter() {}

  /// Ne fait rien tant que [syncActivee] est faux : la synchronisation
  /// cloud n'est pas configurée.
  Future<void> synchroniserMaintenant() async {
    if (!syncActivee) return;
  }
}
