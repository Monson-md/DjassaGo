/// Drapeaux de fonctionnalités décidés au niveau code, pas par l'utilisateur.
///
/// [pubsActivees] : désactivé tant qu'AdMob n'est pas reconfiguré proprement
/// (voir CHECKLIST.md et la note dans lib/services/ad_service.dart). Aucun
/// SDK publicitaire n'est présent dans le projet aujourd'hui ; ce drapeau
/// sert de point d'activation unique le jour où une vraie implémentation
/// sera réintroduite.
const bool pubsActivees = false;

/// [syncActivee] : désactivé tant que le propriétaire n'a pas lancé
/// `flutterfire configure` sur son propre projet Firebase (voir CLAUDE.md
/// et la note dans lib/services/sync_service.dart). L'app fonctionne
/// entièrement hors-ligne sans ce drapeau — aucun réglage utilisateur ne
/// peut l'activer, seul un futur changement de code le pourra.
const bool syncActivee = false;
