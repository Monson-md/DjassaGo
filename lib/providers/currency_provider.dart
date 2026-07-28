import 'package:flutter/foundation.dart';

import '../config/hive_boxes.dart';
import '../services/hive_service.dart';
import '../utils/devises_disponibles.dart';

/// Gère le pays et la devise choisis par le commerçant au premier
/// lancement de l'application. L'information est persistée localement
/// (Hive) et disponible dans toute l'application.
class CurrencyProvider extends ChangeNotifier {
  bool _premierLancementTermine = false;
  String _codePays = 'CI';
  String _nomPays = "Côte d'Ivoire";
  InfoDevise _devise = deviseParDefaut;

  bool get premierLancementTermine => _premierLancementTermine;
  String get codePays => _codePays;
  String get nomPays => _nomPays;
  InfoDevise get devise => _devise;
  String get symboleDevise => _devise.symbole;
  String get codeIsoDevise => _devise.codeIso;

  CurrencyProvider() {
    _charger();
  }

  void _charger() {
    final box = HiveService.parametresBox;
    _premierLancementTermine =
        box.get(ParametresKeys.premierLancementTermine, defaultValue: false)
            as bool;
    _codePays = box.get(ParametresKeys.paysCode, defaultValue: 'CI') as String;
    _nomPays = box.get(ParametresKeys.paysNom, defaultValue: "Côte d'Ivoire")
        as String;
    final codeIsoStocke = box.get(ParametresKeys.devisePrincipale) as String?;
    _devise = codeIsoStocke == null
        ? deviseSelonPays(_codePays)
        : devisesParPays.values.firstWhere(
            (d) => d.codeIso == codeIsoStocke,
            orElse: () => deviseSelonPays(_codePays),
          );
  }

  Future<void> definirPaysEtDevise({
    required String codePays,
    required String nomPays,
  }) async {
    final devise = deviseSelonPays(codePays);
    final box = HiveService.parametresBox;
    await box.put(ParametresKeys.paysCode, codePays);
    await box.put(ParametresKeys.paysNom, nomPays);
    await box.put(ParametresKeys.devisePrincipale, devise.codeIso);
    await box.put(ParametresKeys.premierLancementTermine, true);

    _codePays = codePays;
    _nomPays = nomPays;
    _devise = devise;
    _premierLancementTermine = true;
    notifyListeners();
  }
}
