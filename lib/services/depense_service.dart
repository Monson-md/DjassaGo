import 'package:uuid/uuid.dart';

import '../models/categorie_depense.dart';
import '../models/depense.dart';
import '../utils/periodes.dart';
import 'device_id_service.dart';
import 'hive_service.dart';

/// Gère les charges du commerce (loyer, transport, électricité,
/// réapprovisionnement, autre), distinctes du prix d'achat des produits
/// déjà pris en compte dans la marge brute. Sert au calcul du résultat
/// net du tableau de bord (Phase 7 de docs/PHASES.md).
class DepenseService {
  static const _uuid = Uuid();

  List<Depense> listerToutes() {
    return HiveService.depensesBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Depense> listerSur(Periode periode, {DateTime? reference}) {
    final plage = plagePour(periode, reference: reference);
    return HiveService.depensesBox.values
        .where((d) => plage.contient(d.date))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<Depense> ajouter({
    required String libelle,
    required double montant,
    required CategorieDepense categorie,
    required String devise,
    DateTime? date,
  }) async {
    final depense = Depense(
      id: _uuid.v4(),
      libelle: libelle,
      montant: montant,
      date: date ?? DateTime.now(),
      categorie: categorie,
      devise: devise,
      deviceId: DeviceIdService.obtenir(),
      lastModified: DateTime.now(),
    );
    await HiveService.depensesBox.put(depense.id, depense);
    return depense;
  }

  Future<void> supprimer(String id) async {
    await HiveService.depensesBox.delete(id);
  }

  int totalMineurSur(Periode periode, {DateTime? reference}) {
    return listerSur(periode, reference: reference)
        .fold<int>(0, (s, d) => s + d.montantMineur);
  }
}
