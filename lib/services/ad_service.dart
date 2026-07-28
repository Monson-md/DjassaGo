/// Service publicitaire neutre.
///
/// Google Mobile Ads a été retiré du projet (voir CHECKLIST.md) : son SDK
/// natif peut faire échouer le démarrage de l'application si la
/// meta-data AdMob est absente ou mal configurée, ce qui provoquait un
/// crash silencieux au lancement sur un appareil réel. Cette
/// implémentation ne charge aucun SDK publicitaire et ne fait jamais
/// rien — elle garde seulement l'interface utilisée ailleurs dans le
/// code, pour qu'une vraie implémentation puisse être réintroduite
/// derrière la même API le jour où AdMob sera reconfiguré proprement.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  Future<void> initialiser() async {}

  Future<void> afficherInterstitielSiOpportun() async {}
}
