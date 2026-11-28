import 'package:caisse_de_poche/services/pin_service.dart';
import 'package:flutter/services.dart';

/// Faux stockage sécurisé partagé par les tests.
///
/// Permet de simuler :
/// - un stockage sain (map en mémoire) ;
/// - un stockage illisible (`echecsLecture` > 0, avec l'exception voulue) ;
/// - un plugin absent (`MissingPluginException`).
class FakeStockageSecurise implements StockageSecurise {
  FakeStockageSecurise({Map<String, String>? valeurs})
    : _valeurs = {...?valeurs};

  final Map<String, String> _valeurs;

  /// Nombre de lectures qui échouent avant de reprendre un comportement
  /// normal. Mettre une grande valeur pour simuler une panne persistante.
  int echecsLecture = 0;

  /// Exception levée pendant les `echecsLecture` premières lectures.
  Object erreurLecture = PlatformException(code: 'stockage-indisponible');

  /// Nombre total de lectures effectuées (utile pour vérifier les 3 essais).
  int lectures = 0;

  Map<String, String> get valeurs => Map.unmodifiable(_valeurs);

  @override
  Future<String?> lire(String cle) async {
    lectures++;
    if (lectures <= echecsLecture) {
      throw erreurLecture;
    }
    return _valeurs[cle];
  }

  @override
  Future<void> ecrire(String cle, String valeur) async {
    _valeurs[cle] = valeur;
  }

  @override
  Future<void> supprimer(String cle) async {
    _valeurs.remove(cle);
  }
}
