import 'package:flutter/foundation.dart';

import '../models/item_vendu.dart';
import '../models/produit.dart';
import '../models/transaction.dart' as model;
import '../services/caisse_service.dart';

/// Gère le panier en cours et les statistiques de caisse du jour.
/// Pensé pour un affichage instantané : chaque ajout/retrait recalcule
/// immédiatement le total et le bénéfice net sans appel réseau.
class CaisseProvider extends ChangeNotifier {
  final CaisseService _service = CaisseService();

  final List<ItemVendu> _panier = [];
  List<ItemVendu> get panier => List.unmodifiable(_panier);

  double get totalPanier =>
      _panier.fold<double>(0, (s, i) => s + i.sousTotal);

  double get beneficePanier =>
      _panier.fold<double>(0, (s, i) => s + i.benefice);

  int get nombreArticlesPanier =>
      _panier.fold<int>(0, (s, i) => s + i.quantite);

  double totalDuJour() => _service.totalDuJour();

  double beneficeNetDuJour() => _service.beneficeNetDuJour();

  List<model.Transaction> transactionsDuJour() => _service.transactionsDuJour();

  void ajouterAuPanier(Produit produit, {int quantite = 1}) {
    final indexExistant =
        _panier.indexWhere((i) => i.produitId == produit.id);
    if (indexExistant != -1) {
      _panier[indexExistant].quantite += quantite;
    } else {
      _panier.add(ItemVendu(
        produitId: produit.id,
        nomProduit: produit.nom,
        quantite: quantite,
        prixUnitaireVente: produit.prixVente,
        prixUnitaireAchat: produit.prixAchat,
      ));
    }
    notifyListeners();
  }

  void modifierQuantite(int index, int quantite) {
    if (index < 0 || index >= _panier.length) return;
    if (quantite <= 0) {
      _panier.removeAt(index);
    } else {
      _panier[index].quantite = quantite;
    }
    notifyListeners();
  }

  void retirerDuPanier(int index) {
    if (index < 0 || index >= _panier.length) return;
    _panier.removeAt(index);
    notifyListeners();
  }

  void viderPanier() {
    _panier.clear();
    notifyListeners();
  }

  Future<model.Transaction> finaliserVente({required String devise}) async {
    final transaction = await _service.finaliserVente(
      panier: List.of(_panier),
      devise: devise,
    );
    _panier.clear();
    notifyListeners();
    return transaction;
  }
}
