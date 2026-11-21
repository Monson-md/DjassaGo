import 'package:uuid/uuid.dart';

import '../models/conditionnement.dart';
import '../models/produit.dart';
import 'device_id_service.dart';
import 'hive_service.dart';
import 'normalisation_conditionnements.dart';

/// Une ligne de conditionnement telle que saisie dans le formulaire produit
/// (lib/screens/stock/produit_form_sheet.dart), avant d'être persistée.
///
/// [id] est l'identifiant stable du conditionnement existant en cours
/// d'édition ; `null` pour une ligne nouvellement ajoutée. C'est lui qui
/// permet à [ConditionnementService.remplacerPour] de mettre à jour sans
/// recréer (et donc de préserver les identifiants déjà connus).
class ConditionnementBrouillon {
  final String? id;
  final String nom;
  final int quantiteEnUniteBase;
  final double prixVente;
  final bool parDefaut;

  const ConditionnementBrouillon({
    this.id,
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
    final liste =
        HiveService.conditionnementsBox.values
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
      conditionnement.id,
      conditionnement,
    );
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
  ///
  /// Deux garanties (mission I1) :
  /// - **validation avant toute suppression** : noms non vides, noms uniques
  ///   après normalisation et quantités > 0 sont vérifiés AVANT de toucher
  ///   aux conditionnements existants. En cas d'erreur, rien n'est supprimé
  ///   ni écrit ;
  /// - **identifiants stables** : un brouillon portant un [id] existant met
  ///   à jour ce conditionnement sur place (même id), un brouillon sans id
  ///   est créé, et seuls les conditionnements absents des brouillons sont
  ///   réellement supprimés.
  Future<List<Conditionnement>> remplacerPour({
    required String produitId,
    required List<ConditionnementBrouillon> brouillons,
    required String devise,
  }) async {
    final erreurValidation = validerNomsEtQuantitesConditionnements(
      noms: [for (final b in brouillons) b.nom],
      quantitesEnUniteBase: [for (final b in brouillons) b.quantiteEnUniteBase],
    );
    if (erreurValidation != null) {
      throw Exception(erreurValidation);
    }

    final idsFournis = [
      for (final b in brouillons)
        if (b.id != null) b.id!,
    ];
    if (idsFournis.length != idsFournis.toSet().length) {
      throw Exception(
        'Deux formats de vente ne peuvent pas partager le même identifiant.',
      );
    }

    final existants = listerPour(produitId);
    final existantsParId = {for (final c in existants) c.id: c};
    final idsConserves = <String>{};
    final resultat = <Conditionnement>[];

    for (final brouillon in brouillons) {
      final existant = brouillon.id == null
          ? null
          : existantsParId[brouillon.id!];
      if (existant != null) {
        final misAJour = Conditionnement(
          id: existant.id,
          produitId: produitId,
          nom: brouillon.nom,
          quantiteEnUniteBase: brouillon.quantiteEnUniteBase,
          prixVente: brouillon.prixVente,
          parDefaut: brouillon.parDefaut,
          devise: devise,
          deviceId: DeviceIdService.obtenir(),
          lastModified: DateTime.now(),
        );
        await HiveService.conditionnementsBox.put(existant.id, misAJour);
        idsConserves.add(existant.id);
        resultat.add(misAJour);
      } else {
        final cree = await ajouter(
          produitId: produitId,
          nom: brouillon.nom,
          quantiteEnUniteBase: brouillon.quantiteEnUniteBase,
          prixVente: brouillon.prixVente,
          devise: devise,
          parDefaut: brouillon.parDefaut,
        );
        idsConserves.add(cree.id);
        resultat.add(cree);
      }
    }

    // Suppression uniquement des formats réellement retirés, APRÈS la
    // validation et les écritures : un échec de validation n'a rien détruit.
    for (final existant in existants) {
      if (!idsConserves.contains(existant.id)) {
        await HiveService.conditionnementsBox.delete(existant.id);
      }
    }
    return resultat;
  }

  /// Conditionnement affiché pour un produit qui n'a rien d'enregistré,
  /// sans rien écrire sur disque : quantité 1, au prix de vente courant du
  /// produit. Utilisé pour l'affichage (écrans Caisse et Stock) — voir
  /// [migrerSiAbsent] pour la version qui persiste réellement ce
  /// conditionnement (utilisée à l'import d'une sauvegarde ancienne).
  Conditionnement conditionnementSynthetique(Produit produit) =>
      Conditionnement(
        id: '_synthetique_${produit.id}',
        produitId: produit.id,
        nom: _capitaliser(
          produit.uniteBase.isEmpty ? 'unité' : produit.uniteBase,
        ),
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
      nom: _capitaliser(
        produit.uniteBase.isEmpty ? 'unité' : produit.uniteBase,
      ),
      quantiteEnUniteBase: 1,
      prixVente: produit.prixVente,
      devise: produit.devise,
      parDefaut: true,
    );
  }

  String _capitaliser(String texte) =>
      texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);
}
