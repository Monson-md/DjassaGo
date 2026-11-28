import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;

import '../services/pin_service.dart';

/// Pilote le verrouillage par code PIN de l'application. `verrouille` est
/// vrai au premier chargement si un PIN est configuré (verrouillage au
/// lancement), et remis à vrai lorsque l'app repasse en arrière-plan (voir
/// [GardienRetour] dans main.dart).
class PinProvider extends ChangeNotifier {
  PinProvider({
    PinService? service,
    this.delaiReessai = const Duration(milliseconds: 500),
  }) : _service = service ?? PinService() {
    _charger();
  }

  final PinService _service;

  /// Délai entre deux tentatives de lecture du stockage sécurisé.
  final Duration delaiReessai;

  bool _pinConfigure = false;
  bool _verrouille = false;
  bool _pret = false;
  bool _erreurStockage = false;

  bool get pinConfigure => _pinConfigure;
  bool get verrouille => _verrouille;
  bool get pret => _pret;

  /// Vrai quand le stockage sécurisé existe mais est illisible. L'écran de
  /// verrouillage affiche alors un message, un bouton « Réessayer » et la
  /// récupération — jamais de contournement du verrou.
  bool get erreurStockage => _erreurStockage;

  /// Vrai si l'application est au premier plan (ou si l'état n'est pas encore
  /// connu, cas des tests unitaires sans cycle de vie simulé).
  bool get _auPremierPlan {
    final etat = WidgetsBinding.instance.lifecycleState;
    return etat == null || etat == AppLifecycleState.resumed;
  }

  Future<void> _charger() async {
    Object? derniereErreur;
    for (var tentative = 0; tentative < 3; tentative++) {
      try {
        _pinConfigure = await _service.pinConfigure();
        _erreurStockage = false;
        derniereErreur = null;
        break;
      } on MissingPluginException {
        // Tests, desktop ou plateforme sans plugin : aucun PIN ne peut
        // exister. On ne verrouille pas, sinon l'app serait inutilisable.
        _pinConfigure = false;
        _erreurStockage = false;
        derniereErreur = null;
        break;
      } catch (e) {
        derniereErreur = e;
        if (tentative < 2) {
          await Future<void>.delayed(delaiReessai);
        }
      }
    }

    if (derniereErreur != null) {
      // Fail-closed : on ne peut pas prouver l'absence de PIN. On verrouille
      // et on laisse l'utilisateur réessayer ou passer par la récupération.
      _pinConfigure = true;
      _erreurStockage = true;
    }

    _verrouille = _pinConfigure;
    _pret = true;
    notifyListeners();
  }

  /// Relance la lecture du stockage sécurisé après une erreur
  /// (« Réessayer » sur l'écran de verrouillage).
  Future<void> recharger() => _charger();

  Future<void> definirPin(
    String pin, {
    required String question,
    required String reponse,
  }) async {
    try {
      await _service.definirPin(pin, question: question, reponse: reponse);
    } catch (_) {
      _erreurStockage = true;
      notifyListeners();
      rethrow;
    }
    _pinConfigure = true;
    _erreurStockage = false;
    // Si l'app a été mise en arrière-plan pendant l'écriture, on reste
    // verrouillé au retour : le PIN vient seulement d'être défini.
    _verrouille = !_auPremierPlan;
    notifyListeners();
  }

  Future<bool> deverrouiller(String pin) async {
    try {
      final ok = await _service.verifierPin(pin);
      if (ok) {
        _verrouille = false;
        _erreurStockage = false;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      _erreurStockage = true;
      notifyListeners();
      return false;
    }
  }

  /// Reverrouille l'app : appelé au retour d'arrière-plan si un PIN est
  /// configuré. Sans effet si aucun PIN n'a été activé.
  void verrouiller() {
    if (_pinConfigure && !_verrouille) {
      _verrouille = true;
      notifyListeners();
    }
  }

  Future<String?> question() => _service.question();

  Future<bool> verifierReponse(String reponse) =>
      _service.verifierReponse(reponse);

  /// Réinitialise le PIN après vérification de la réponse secrète — à
  /// utiliser uniquement depuis le parcours « code oublié ».
  Future<void> reinitialiserPinAvecReponse(String nouveauPin) async {
    try {
      await _service.reinitialiserPin(nouveauPin);
    } catch (_) {
      _erreurStockage = true;
      notifyListeners();
      rethrow;
    }
    _erreurStockage = false;
    // Même garde que definirPin : une réinitialisation qui se termine alors
    // que l'app est en arrière-plan ne doit pas la laisser déverrouillée.
    _verrouille = !_auPremierPlan;
    notifyListeners();
  }

  /// Change le PIN en confirmant d'abord l'ancien. Renvoie `false` sans
  /// rien modifier si l'ancien PIN est incorrect.
  Future<bool> changerPin(String ancienPin, String nouveauPin) async {
    try {
      final ok = await _service.verifierPin(ancienPin);
      if (!ok) return false;
      await _service.reinitialiserPin(nouveauPin);
      _erreurStockage = false;
      notifyListeners();
      return true;
    } catch (_) {
      _erreurStockage = true;
      notifyListeners();
      return false;
    }
  }

  /// Désactive complètement le verrouillage, après confirmation du PIN
  /// actuel.
  Future<bool> desactiverVerrouillage(String pinActuel) async {
    try {
      final ok = await _service.verifierPin(pinActuel);
      if (!ok) return false;
      await _service.supprimerVerrouillage();
      _pinConfigure = false;
      // Il n'existe plus aucun PIN : conserver le voile affiché ici
      // bloquerait définitivement l'application, puisqu'aucun code ni
      // aucune question secrète ne pourrait le lever. La garde de cycle de
      // vie n'a donc de sens que pour les opérations qui laissent un PIN.
      _verrouille = false;
      _erreurStockage = false;
      notifyListeners();
      return true;
    } catch (_) {
      _erreurStockage = true;
      notifyListeners();
      return false;
    }
  }
}
