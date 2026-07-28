import 'package:uuid/uuid.dart';

import '../models/item_vendu.dart';
import '../models/transaction.dart' as model;
import 'hive_service.dart';
import 'produit_service.dart';

/// Gère l'enregistrement des ventes (transactions) et les statistiques
/// de caisse (total et bénéfice net du jour).
class CaisseService {
  static const _uuid = Uuid();

  final ProduitService _produitService;

  CaisseService({ProduitService? produitService})
      : _produitService = produitService ?? ProduitService();

  /// Finalise une vente : décrémente le stock de chaque produit vendu,
  /// calcule le total et le bénéfice net, puis enregistre la transaction.
  Future<model.Transaction> finaliserVente({
    required List<ItemVendu> panier,
    required String devise,
  }) async {
    if (panier.isEmpty) {
      throw Exception('Le panier est vide');
    }

    for (final item in panier) {
      await _produitService.decrementerStock(item.produitId, item.quantite);
    }

    final montantTotal = panier.fold<double>(0, (s, i) => s + i.sousTotal);
    final beneficeNet = panier.fold<double>(0, (s, i) => s + i.benefice);

    final transaction = model.Transaction(
      id: _uuid.v4(),
      date: DateTime.now(),
      itemsVendus: panier,
      montantTotal: montantTotal,
      beneficeNet: beneficeNet,
      devise: devise,
    );

    await HiveService.transactionsBox.put(transaction.id, transaction);
    return transaction;
  }

  List<model.Transaction> transactionsDuJour({DateTime? jour}) {
    final j = jour ?? DateTime.now();
    return HiveService.transactionsBox.values
        .where((t) =>
            t.date.year == j.year &&
            t.date.month == j.month &&
            t.date.day == j.day)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double totalDuJour({DateTime? jour}) {
    return transactionsDuJour(jour: jour)
        .fold<double>(0, (s, t) => s + t.montantTotal);
  }

  double beneficeNetDuJour({DateTime? jour}) {
    return transactionsDuJour(jour: jour)
        .fold<double>(0, (s, t) => s + t.beneficeNet);
  }

  List<model.Transaction> toutesLesTransactions() {
    return HiveService.transactionsBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<model.Transaction> transactionsNonSynchronisees() {
    return HiveService.transactionsBox.values
        .where((t) => !t.synchronise)
        .toList();
  }
}
