import 'package:flutter/foundation.dart';

import '../models/produit.dart';
import '../services/produit_service.dart';

class ProduitProvider extends ChangeNotifier {
  final ProduitService _service = ProduitService();

  List<Produit> _produits = [];
  List<Produit> get produits => List.unmodifiable(_produits);

  List<Produit> get produitsEnRupture =>
      _produits.where((p) => p.enRupture).toList();

  List<Produit> get produitsStockFaible =>
      _produits.where((p) => p.stockFaible && !p.enRupture).toList();

  ProduitProvider() {
    charger();
  }

  void charger() {
    _produits = _service.listerTous();
    notifyListeners();
  }

  Future<Produit> ajouter({
    required String nom,
    required double prixAchat,
    required double prixVente,
    required int stockActuel,
    required String devise,
    String uniteBase = 'unité',
  }) async {
    final produit = await _service.ajouter(
      nom: nom,
      prixAchat: prixAchat,
      prixVente: prixVente,
      stockActuel: stockActuel,
      devise: devise,
      uniteBase: uniteBase,
    );
    charger();
    return produit;
  }

  Future<void> modifier(Produit produit) async {
    await _service.modifier(produit);
    charger();
  }

  Future<void> supprimer(String id) async {
    await _service.supprimer(id);
    charger();
  }

  Future<void> reapprovisionner(String produitId, int quantite) async {
    await _service.reapprovisionner(produitId, quantite);
    charger();
  }
}
