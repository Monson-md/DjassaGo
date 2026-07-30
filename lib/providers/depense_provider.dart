import 'package:flutter/foundation.dart';

import '../models/categorie_depense.dart';
import '../models/depense.dart';
import '../services/depense_service.dart';
import '../utils/periodes.dart';

class DepenseProvider extends ChangeNotifier {
  final DepenseService _service = DepenseService();

  List<Depense> _depenses = [];
  List<Depense> get depenses => List.unmodifiable(_depenses);

  DepenseProvider() {
    charger();
  }

  void charger() {
    _depenses = _service.listerToutes();
    notifyListeners();
  }

  List<Depense> listerSur(Periode periode) => _service.listerSur(periode);

  int totalMineurSur(Periode periode) => _service.totalMineurSur(periode);

  Future<void> ajouter({
    required String libelle,
    required double montant,
    required CategorieDepense categorie,
    required String devise,
    DateTime? date,
  }) async {
    await _service.ajouter(
      libelle: libelle,
      montant: montant,
      categorie: categorie,
      devise: devise,
      date: date,
    );
    charger();
  }

  Future<void> supprimer(String id) async {
    await _service.supprimer(id);
    charger();
  }
}
