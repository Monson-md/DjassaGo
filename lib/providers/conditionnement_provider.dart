import 'package:flutter/foundation.dart';

import '../models/conditionnement.dart';
import '../models/produit.dart';
import '../services/conditionnement_service.dart';

/// Conditionnements de vente de chaque produit (Bouteille, Casier,
/// Carton...), groupés par produit pour un accès instantané depuis l'écran
/// Caisse (une tuile par produit, potentiellement plusieurs formats).
///
/// Ne persiste jamais rien lors d'une simple lecture : un produit qui n'a
/// aucun conditionnement enregistré (créé ou importé avant cette phase)
/// reçoit une liste synthétique d'un seul conditionnement de quantité 1,
/// calculée à la volée (voir ConditionnementService.conditionnementSynthetique)
/// — la persistance réelle n'a lieu qu'à l'enregistrement explicite du
/// formulaire produit ou à l'import d'une sauvegarde ancienne.
class ConditionnementProvider extends ChangeNotifier {
  final ConditionnementService _service = ConditionnementService();

  Map<String, List<Conditionnement>> _parProduit = {};

  ConditionnementProvider() {
    charger();
  }

  void charger() {
    final groupes = <String, List<Conditionnement>>{};
    for (final c in _service.listerTous()) {
      groupes.putIfAbsent(c.produitId, () => []).add(c);
    }
    for (final liste in groupes.values) {
      liste.sort((a, b) {
        if (a.parDefaut != b.parDefaut) return a.parDefaut ? -1 : 1;
        return a.quantiteEnUniteBase.compareTo(b.quantiteEnUniteBase);
      });
    }
    _parProduit = groupes;
    notifyListeners();
  }

  /// Conditionnements réels du produit, ou une liste synthétique d'un seul
  /// conditionnement de quantité 1 si rien n'est enregistré.
  List<Conditionnement> listerPour(Produit produit) {
    final reels = _parProduit[produit.id];
    if (reels != null && reels.isNotEmpty) return reels;
    return [_service.conditionnementSynthetique(produit)];
  }

  bool aPlusieursFormats(Produit produit) => listerPour(produit).length > 1;

  Conditionnement parDefautPour(Produit produit) {
    final liste = listerPour(produit);
    return liste.firstWhere((c) => c.parDefaut, orElse: () => liste.first);
  }

  Future<void> remplacerPour({
    required String produitId,
    required List<ConditionnementBrouillon> brouillons,
    required String devise,
  }) async {
    await _service.remplacerPour(
      produitId: produitId,
      brouillons: brouillons,
      devise: devise,
    );
    charger();
  }
}
