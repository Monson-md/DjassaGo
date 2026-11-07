/// Verrou d'exécution séquentielle (mutex asynchrone) local à l'isolate.
///
/// Les opérations asynchrones qui mutent un état partagé (boxes Hive)
/// s'entrelacent à chaque `await` : entre deux suspensions, une autre
/// opération peut lire un état transitoire puis l'écraser (décrément de
/// stock avalé par un rollback concurrent, validation contre une valeur
/// jamais persistée...). [executer] met chaque action en file (FIFO) :
/// pendant qu'une action tourne, aucune autre ne peut commencer, et une
/// action qui échoue n'empêche pas les suivantes de s'exécuter.
///
/// Utilisé par [CaisseService] pour sérialiser les cycles
/// vente/annulation (voir le verrou statique `_verrouVentes`, partagé
/// par toutes les instances du service).
///
/// Pas de re-entrance : une action sous verrou ne doit pas appeler une
/// méthode qui re-passe par [executer] (deadlock). Les méthodes internes
/// de CaisseService sont donc appelées après acquisition, jamais en
/// chaîne depuis une action.
class VerrouAsynchrone {
  /// Terminaison de la dernière tâche déposée. Toujours non-erreur :
  /// les échecs sont avalés ici pour la file uniquement — l'appelant
  /// concerné les reçoit via le Future retourné par [executer].
  Future<void> _queue = Future.value();

  Future<T> executer<T>(Future<T> Function() action) {
    final tache = _queue.then((_) => action());
    // La file continue même si l'action échoue.
    _queue = tache.then((_) {}, onError: (_) {});
    return tache;
  }
}
