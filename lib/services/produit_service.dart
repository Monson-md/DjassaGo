import 'package:uuid/uuid.dart';

import '../models/produit.dart';
import 'hive_service.dart';

/// Gère le CRUD des produits ainsi que les mouvements de stock.
class ProduitService {
  static const _uuid = Uuid();

  List<Produit> listerTous() {
    return HiveService.produitsBox.values.toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
  }

  List<Produit> listerEnRupture() {
    return listerTous().where((p) => p.enRupture).toList();
  }

  List<Produit> listerStockFaible() {
    return listerTous().where((p) => p.stockFaible).toList();
  }

  Produit? trouverParId(String id) {
    try {
      return HiveService.produitsBox.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Produit> ajouter({
    required String nom,
    required double prixAchat,
    required double prixVente,
    required int stockActuel,
    required String devise,
  }) async {
    final produit = Produit(
      id: _uuid.v4(),
      nom: nom,
      prixAchat: prixAchat,
      prixVente: prixVente,
      stockActuel: stockActuel,
      devise: devise,
    );
    await HiveService.produitsBox.put(produit.id, produit);
    return produit;
  }

  Future<void> modifier(Produit produit) async {
    produit.dateModification = DateTime.now();
    await produit.save();
  }

  Future<void> supprimer(String id) async {
    await HiveService.produitsBox.delete(id);
  }

  /// Décrémente le stock lors d'une vente. Lève une exception si le stock
  /// disponible est insuffisant.
  Future<void> decrementerStock(String produitId, int quantite) async {
    final produit = trouverParId(produitId);
    if (produit == null) {
      throw Exception('Produit introuvable');
    }
    if (produit.stockActuel < quantite) {
      throw Exception('Stock insuffisant pour ${produit.nom}');
    }
    produit.stockActuel -= quantite;
    await produit.save();
  }

  /// Réapprovisionne le stock (achat/livraison).
  Future<void> reapprovisionner(String produitId, int quantite) async {
    final produit = trouverParId(produitId);
    if (produit == null) {
      throw Exception('Produit introuvable');
    }
    produit.stockActuel += quantite;
    await produit.save();
  }
}
