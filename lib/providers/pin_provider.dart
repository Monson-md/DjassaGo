import 'package:flutter/foundation.dart';

import '../services/pin_service.dart';

/// Pilote le verrouillage par code PIN de l'application. `verrouille` est
/// vrai au premier chargement si un PIN est configuré (verrouillage au
/// lancement), et remis à vrai lorsque l'app repasse en arrière-plan (voir
/// l'observateur de cycle de vie dans main.dart).
class PinProvider extends ChangeNotifier {
  PinProvider({PinService? service}) : _service = service ?? PinService() {
    _charger();
  }

  final PinService _service;

  bool _pinConfigure = false;
  bool _verrouille = false;
  bool _pret = false;

  bool get pinConfigure => _pinConfigure;
  bool get verrouille => _verrouille;
  bool get pret => _pret;

  Future<void> _charger() async {
    // Ne doit jamais faire planter l'app : si le stockage sécurisé est
    // indisponible (plateforme non supportée, environnement de test sans
    // canal natif...), on dégrade silencieusement vers « pas de PIN
    // configuré » plutôt que de bloquer le démarrage.
    try {
      _pinConfigure = await _service.pinConfigure();
    } catch (_) {
      _pinConfigure = false;
    }
    _verrouille = _pinConfigure;
    _pret = true;
    notifyListeners();
  }

  Future<void> definirPin(
    String pin, {
    required String question,
    required String reponse,
  }) async {
    await _service.definirPin(pin, question: question, reponse: reponse);
    _pinConfigure = true;
    _verrouille = false;
    notifyListeners();
  }

  Future<bool> deverrouiller(String pin) async {
    final ok = await _service.verifierPin(pin);
    if (ok) {
      _verrouille = false;
      notifyListeners();
    }
    return ok;
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
    await _service.reinitialiserPin(nouveauPin);
    _verrouille = false;
    notifyListeners();
  }

  /// Change le PIN en confirmant d'abord l'ancien. Renvoie `false` sans
  /// rien modifier si l'ancien PIN est incorrect.
  Future<bool> changerPin(String ancienPin, String nouveauPin) async {
    final ok = await _service.verifierPin(ancienPin);
    if (!ok) return false;
    await _service.reinitialiserPin(nouveauPin);
    return true;
  }

  /// Désactive complètement le verrouillage, après confirmation du PIN
  /// actuel.
  Future<bool> desactiverVerrouillage(String pinActuel) async {
    final ok = await _service.verifierPin(pinActuel);
    if (!ok) return false;
    await _service.supprimerVerrouillage();
    _pinConfigure = false;
    _verrouille = false;
    notifyListeners();
    return true;
  }
}
