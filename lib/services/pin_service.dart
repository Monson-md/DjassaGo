import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction du stockage clé-valeur sécurisé, pour pouvoir tester la
/// logique de hachage du PIN sans dépendre du canal natif de
/// flutter_secure_storage (voir _FakePathProviderPlatform pour le même
/// principe appliqué à path_provider).
abstract class StockageSecurise {
  Future<String?> lire(String cle);
  Future<void> ecrire(String cle, String valeur);
  Future<void> supprimer(String cle);
}

class _FlutterSecureStorageAdapter implements StockageSecurise {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> lire(String cle) => _storage.read(key: cle);

  @override
  Future<void> ecrire(String cle, String valeur) =>
      _storage.write(key: cle, value: valeur);

  @override
  Future<void> supprimer(String cle) => _storage.delete(key: cle);
}

/// Gère le code PIN de verrouillage de l'application : jamais stocké en
/// clair, seul un hash salé (SHA-256) l'est, dans le stockage sécurisé
/// natif (Keystore Android / Keychain iOS). Une question secrète permet
/// de réinitialiser le PIN en cas d'oubli, sans jamais exposer l'ancien.
class PinService {
  PinService({StockageSecurise? stockage})
      : _stockage = stockage ?? _FlutterSecureStorageAdapter();

  final StockageSecurise _stockage;

  static const _clePinHash = 'pin_hash';
  static const _clePinSel = 'pin_sel';
  static const _cleQuestion = 'pin_question';
  static const _cleReponseHash = 'pin_reponse_hash';
  static const _cleReponseSel = 'pin_reponse_sel';

  String _genererSel() {
    final aleatoire = Random.secure();
    final octets = List<int>.generate(16, (_) => aleatoire.nextInt(256));
    return base64Url.encode(octets);
  }

  String _hacher(String valeur, String sel) {
    return sha256.convert(utf8.encode('$sel:$valeur')).toString();
  }

  Future<bool> pinConfigure() async {
    return await _stockage.lire(_clePinHash) != null;
  }

  Future<void> definirPin(
    String pin, {
    required String question,
    required String reponse,
  }) async {
    final selPin = _genererSel();
    final selReponse = _genererSel();
    await _stockage.ecrire(_clePinHash, _hacher(pin, selPin));
    await _stockage.ecrire(_clePinSel, selPin);
    await _stockage.ecrire(_cleQuestion, question);
    await _stockage.ecrire(
      _cleReponseHash,
      _hacher(reponse.trim().toLowerCase(), selReponse),
    );
    await _stockage.ecrire(_cleReponseSel, selReponse);
  }

  Future<bool> verifierPin(String pin) async {
    final hash = await _stockage.lire(_clePinHash);
    final sel = await _stockage.lire(_clePinSel);
    if (hash == null || sel == null) return false;
    return _hacher(pin, sel) == hash;
  }

  Future<String?> question() => _stockage.lire(_cleQuestion);

  Future<bool> verifierReponse(String reponse) async {
    final hash = await _stockage.lire(_cleReponseHash);
    final sel = await _stockage.lire(_cleReponseSel);
    if (hash == null || sel == null) return false;
    return _hacher(reponse.trim().toLowerCase(), sel) == hash;
  }

  /// Remplace le PIN sans exiger l'ancien — n'appeler qu'après vérification
  /// de la réponse secrète ([verifierReponse]) ou de l'ancien PIN.
  Future<void> reinitialiserPin(String nouveauPin) async {
    final selPin = _genererSel();
    await _stockage.ecrire(_clePinHash, _hacher(nouveauPin, selPin));
    await _stockage.ecrire(_clePinSel, selPin);
  }

  Future<void> supprimerVerrouillage() async {
    await _stockage.supprimer(_clePinHash);
    await _stockage.supprimer(_clePinSel);
    await _stockage.supprimer(_cleQuestion);
    await _stockage.supprimer(_cleReponseHash);
    await _stockage.supprimer(_cleReponseSel);
  }
}
