/// Service de synchronisation cloud, neutre pour l'instant.
///
/// Firebase (firebase_core, cloud_firestore) et connectivity_plus ont été
/// retirés du projet (voir CHECKLIST.md) : l'initialisation native de
/// Firebase pouvait faire échouer le démarrage de l'application sans
/// configuration valide (pas de firebase_options.dart), ce qui provoquait
/// un crash silencieux au lancement sur un appareil réel.
///
/// Cette implémentation ne dépend d'aucun package externe et ne fait
/// jamais rien : l'application fonctionne entièrement hors-ligne. La
/// Phase 9 réintroduira une vraie synchronisation bidirectionnelle,
/// derrière un drapeau explicite, une fois qu'un projet Firebase sera
/// réellement configuré (flutterfire configure).
class SyncService {
  Future<void> demarrer() async {}

  void arreter() {}

  /// Ne fait rien : la synchronisation cloud n'est pas configurée.
  Future<void> synchroniserMaintenant() async {}
}
