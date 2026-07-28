import 'package:flutter/foundation.dart';

import '../models/dette.dart';
import '../services/dette_service.dart';

class DetteProvider extends ChangeNotifier {
  final DetteService _service = DetteService();

  List<Dette> _dettes = [];
  List<Dette> get dettes => List.unmodifiable(_dettes);

  List<Dette> get dettesEnCours =>
      _dettes.where((d) => d.statut != StatutDette.payee).toList();

  double get totalEnCours => _service.totalDettesEnCours();

  DetteProvider() {
    charger();
  }

  void charger() {
    _dettes = _service.listerToutes();
    notifyListeners();
  }

  Future<void> ajouter({
    required String nomClient,
    required String telephone,
    required double montantDu,
    required String devise,
    DateTime? dateDette,
    String? note,
  }) async {
    await _service.ajouter(
      nomClient: nomClient,
      telephone: telephone,
      montantDu: montantDu,
      devise: devise,
      dateDette: dateDette,
      note: note,
    );
    charger();
  }

  Future<void> enregistrerPaiement(Dette dette, double montantPaye) async {
    await _service.enregistrerPaiement(dette, montantPaye);
    charger();
  }

  Future<void> supprimer(String id) async {
    await _service.supprimer(id);
    charger();
  }

  String genererMessageRelance(Dette dette) =>
      _service.genererMessageRelance(dette);

  Future<bool> envoyerRelanceWhatsApp(Dette dette) =>
      _service.envoyerRelanceWhatsApp(dette);

  Future<bool> envoyerRelanceSms(Dette dette) =>
      _service.envoyerRelanceSms(dette);
}
