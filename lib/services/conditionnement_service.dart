import 'package:uuid/uuid.dart';

import '../models/conditionnement.dart';
import '../models/produit.dart';
import 'device_id_service.dart';
import 'hive_service.dart';

/// Une ligne de conditionnement telle que saisie dans le formulaire produit
/// (lib/screens/stock/produit_form_sheet.dart), avant d'être persistée.
class ConditionnementBrouillon {
  final String nom;
  final int quantiteEnUniteBase;
  final double prixVente;
  final bool parDefaut;

  const ConditionnementBrouillon({
    required this.nom,
    required this.quantiteEnUniteBase,
    required this.prixVente,
    required this.parDefaut,
  });
}

/// Gère les conditionnements de vente d'un produit (Casier, Bouteille,
/// Sachet...). Le stock du produit reste toujours compté en unité de base ;
/// un conditionnement n'est qu'un multiplicateur de vente, figé dans
/// l'ItemVendu au moment de la vente (voir CaisseProvider.ajouterAuPanier)
/// pour que l'historique ne bouge jamais si le conditionnement est modifié
/// ou supprimé ensuite.
class ConditionnementService {
  static const _uuid = Uuid();

  List<Conditionnement> listerTous() =>
      HiveService.conditionnementsBox.values.toList();

  List<Conditionnement> listerPour(String produitId) {
    final liste = HiveService.conditionnementsBox.values
        .where((c) => c.produitId == produitId)
        .toList()
      ..sort((a, b) {
        if (a.parDefaut != b.parDefaut) return a.parDefaut ? -1 : 1;
        return a.quantiteEnUniteBase.compareTo(b.quantiteEnUniteBase);
      });
    return liste;
  }

  /// Le conditionnement proposé en premier sur l'écran Caisse. `null` si le
  /// produit n'a aucun conditionnement enregistré (voir [conditionnementSynthetique]
  /// pour l'affichage sans écriture, et [migrerSiAbsent] pour en créer un
  /// réellement).
  Conditionnement? parDefautPour(String produitId) {
    final liste = listerPour(produitId);
    if (liste.isEmpty) return null;
    return liste.firstWhere((c) => c.parDefaut, orElse: () => liste.first);
  }

  Future<Conditionnement> ajouter({
    required String produitId,
    required String nom,
    required int quantiteEnUniteBase,
    required double prixVente,
    required String devise,
    bool parDefaut = false,
  }) async {
    final conditionnement = Conditionnement(
      id: _uuid.v4(),
      produitId: produitId,
      nom: nom,
      quantiteEnUniteBase: quantiteEnUniteBase,
      prixVente: prixVente,
      parDefaut: parDefaut,
      devise: devise,
      deviceId: DeviceIdService.obtenir(),
      lastModified: DateTime.now(),
    );
    await HiveService.conditionnementsBox.put(
        conditionnement.id, conditionnement);
    return conditionnement;
  }

  Future<void> supprimer(String id) async {
    await HiveService.conditionnementsBox.delete(id);
  }

  /// Remplace en bloc tous les conditionnements d'un produit par [brouillons]
  /// — c'est ainsi que le formulaire produit enregistre l'ajout, la
  /// modification et la suppression de lignes en une seule opération. Sans
  /// risque pour l'historique : une [Transaction] passée ne référence jamais
  /// un Conditionnement par id, seulement par son nom et sa quantité figés
  /// au moment de la vente (voir lib/models/item_vendu.dart).
  Future<List<Conditionnement>> remplacerPour({
    required String produitId,
    required List<ConditionnementBrouillon> brouillons,
    required String devise,
  }) async {
    if (brouillons.isEmpty) {
      throw Exception('Un produit doit avoir au moins un conditionnement');
    }
    for (final existant in listerPour(produitId)) {
      await HiveService.conditionnementsBox.delete(existant.id);
    }
    final crees = <Conditionnement>[];
    for (final brouillon in brouillons) {
      crees.add(await ajouter(
        produitId: produitId,
        nom: brouillon.nom,
        quantiteEnUniteBase: brouillon.quantiteEnUniteBase,
        prixVente: brouillon.prixVente,
        devise: devise,
        parDefaut: brouillon.parDefaut,
      ));
    }
    return crees;
  }

  /// Conditionnement affiché pour un produit qui n'a rien d'enregistré,
  /// sans rien écrire sur disque : quantité 1, au prix de vente courant du
  /// produit. Utilisé pour l'affichage (écrans Caisse et Stock) — voir
  /// [migrerSiAbsent] pour la version qui persiste réellement ce
  /// conditionnement (utilisée à l'import d'une sauvegarde ancienne).
  Conditionnement conditionnementSynthetique(Produit produit) => Conditionnement(
        id: '_synthetique_${produit.id}',
        produitId: produit.id,
        nom: _capitaliser(produit.uniteBase.isEmpty ? 'unité' : produit.uniteBase),
        quantiteEnUniteBase: 1,
        prixVente: produit.prixVente,
        parDefaut: true,
        devise: produit.devise,
        prixVenteMineur: produit.prixVenteMineur,
      );

  /// Crée, une seule fois, un conditionnement unique de quantité 1 au prix
  /// de vente courant pour un produit qui n'en a aucun (produit créé ou
  /// importé avant cette phase). Idempotent : ne touche rien si le produit a
  /// déjà au moins un conditionnement.
  Future<Conditionnement> migrerSiAbsent(Produit produit) async {
    final existants = listerPour(produit.id);
    if (existants.isNotEmpty) return existants.first;
    return ajouter(
      produitId: produit.id,
      nom: _capitaliser(produit.uniteBase.isEmpty ? 'unité' : produit.uniteBase),
      quantiteEnUniteBase: 1,
      prixVente: produit.prixVente,
      devise: produit.devise,
      parDefaut: true,
    );
  }

  String _capitaliser(String texte) =>
      texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}
