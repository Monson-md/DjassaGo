import 'package:uuid/uuid.dart';

import '../models/dette.dart';
import '../models/item_vendu.dart';
import '../models/mode_paiement.dart';
import '../models/produit.dart';
import '../models/transaction.dart' as model;
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import '../utils/periodes.dart';
import '../utils/verrou_asynchrone.dart';
import 'dette_service.dart';
import 'device_id_service.dart';
import 'hive_service.dart';
import 'produit_service.dart';

/// Gère l'enregistrement des ventes (transactions) et les statistiques
/// de caisse (total et marge brute du jour, et par période pour le
/// tableau de bord — voir [totalMineurSur]/[margeBruteMineurSur]).
class CaisseService {
  static const _uuid = Uuid();

  /// Verrou sérialisant les cycles de vente / annulation (voir
  /// [VerrouAsynchrone]). **Statique** : partagé par toutes les instances
  /// de [CaisseService] — deux finalisations peuvent être lancées
  /// « simultanément » depuis des instances différentes (double tap,
  /// deux écrans actifs, tests), donc un verrou par instance ne suffirait
  /// pas. Pas de re-entrance : ne pas ré-acquérir depuis une action déjà
  /// sous verrou — c'est pourquoi [finaliserVenteACredit] appelle la
  /// logique interne [_finaliserVenteSousVerrou] plutôt que le point
  /// d'entrée public [finaliserVente].
  static final VerrouAsynchrone _verrouVentes = VerrouAsynchrone();

  final ProduitService _produitService;
  final DetteService _detteService;

  CaisseService({ProduitService? produitService, DetteService? detteService})
    : _produitService = produitService ?? ProduitService(),
      _detteService = detteService ?? DetteService();

  /// Finalise une vente de façon **atomique et sérialisée** : le stock ne
  /// peut jamais être décrémenté sans transaction enregistrée, ni
  /// l'inverse — pas plus qu'une vente ne peut s'entrelacer avec une
  /// autre.
  ///
  /// Cette méthode est le point d'entrée public : elle exécute toute la
  /// logique ci-dessous **sous le verrou statique des ventes**
  /// ([_verrouVentes]). Sans ce verrou, deux ventes « simultanées »
  /// (l'event loop Dart entrelace leurs awaits) peuvent occulter des
  /// écritures l'une de l'autre — le rollback de l'une pouvant par
  /// exemple restaurer un snapshot qui écrase le décrément déjà persisté
  /// de l'autre.
  ///
  /// Trois phases (correction C1) :
  ///
  /// 1. Validation complète **avant la moindre écriture** — les retraits
  ///    sont agrégés par produit (un panier peut contenir plusieurs lignes
  ///    du même produit avec des conditionnements différents : 2 casiers
  ///    puis 3 bouteilles du même Coca, voir CaisseProvider.ajouterAuPanier)
  ///    et vérifiés d'une seule traite contre le stock courant. Toute
  ///    erreur ici (panier vide, produit inexistant, stock insuffisant)
  ///    laisse l'état intact : ni stock, ni transaction.
  /// 2. Préparation en mémoire — figeage des prix en unités mineures et
  ///    calculs (inchangés).
  /// 3. Écritures avec rollback par compensation — chaque stock est
  ///    décrémenté et persisté, puis la transaction est écrite. Si une
  ///    écriture échoue (disque plein, box fermée, produit modifié entre
  ///    les deux...), tous les stocks touchés sont restaurés en mémoire
  ///    depuis un snapshot pris avant la vente **et** réécrits sur disque,
  ///    et une transaction partiellement écrite est supprimée : l'état de
  ///    la boutique reste tel qu'avant la tentative de vente.
  ///
  /// Règle comptable (voir docs/PHASES.md Phase 3) : le chiffre d'affaires
  /// et la marge sont reconnus ici, au moment de la vente, quel que soit
  /// [modePaiement] — y compris pour une vente à crédit non encore payée.
  /// Un paiement de dette ultérieur (DetteService.enregistrerPaiement)
  /// est un encaissement, jamais une nouvelle vente : voir
  /// [encaissementsDuJourMineur] qui garde les deux notions séparées.
  Future<model.Transaction> finaliserVente({
    required List<ItemVendu> panier,
    required String devise,
    ModePaiement modePaiement = ModePaiement.especes,
  }) {
    return _verrouVentes.executer(
      () => _finaliserVenteSousVerrou(
        panier: panier,
        devise: devise,
        modePaiement: modePaiement,
      ),
    );
  }

  /// Logique de finalisation d'une vente — le contrat et les trois
  /// phases sont documentés sur [finaliserVente]. Méthode **privée**
  /// destinée aux appels internes qui tiennent déjà [_verrouVentes] :
  /// - [finaliserVente], point d'entrée public, qui pose d'abord le
  ///   verrou puis délègue ici ;
  /// - [finaliserVenteACredit], qui garde le verrou posé pendant toute
  ///   l'écriture de la [Dette] liée à la vente.
  /// En cas de ventes potentiellement concurrentes, toujours passer par
  /// [finaliserVente] : cette méthode ne protège rien par elle-même.
  Future<model.Transaction> _finaliserVenteSousVerrou({
    required List<ItemVendu> panier,
    required String devise,
    ModePaiement modePaiement = ModePaiement.especes,
  }) async {
    if (panier.isEmpty) {
      throw Exception('Le panier est vide');
    }

    // Le stock est toujours compté en unité de base : un item du panier
    // représente [quantite] exemplaires d'un conditionnement qui vaut
    // [quantiteEnUniteBase] unités de base chacun (1 pour un produit
    // simple, 20 pour un casier de 20 bouteilles...) — voir
    // lib/models/conditionnement.dart et CaisseProvider.ajouterAuPanier.
    // Agrégation par produit : deux lignes du même produit (conditionnements
    // différents) consomment un stock commun et doivent être validées
    // ensemble, pas ligne par ligne.
    final retraitsParProduit = <String, int>{};
    for (final item in panier) {
      retraitsParProduit[item.produitId] =
          (retraitsParProduit[item.produitId] ?? 0) +
          item.quantite * item.quantiteEnUniteBase;
    }

    // Phase 1 : validation complète, avant toute écriture. Si cette
    // phase échoue, rien n'a été modifié : ni stock, ni transaction.
    final produitsTouches = <String, Produit>{};
    for (final retrait in retraitsParProduit.entries) {
      final produit = _produitService.trouverParId(retrait.key);
      if (produit == null) {
        throw Exception('Produit introuvable');
      }
      if (produit.stockActuel < retrait.value) {
        throw Exception('Stock insuffisant pour ${produit.nom}');
      }
      produitsTouches[retrait.key] = produit;
    }

    // Fige les prix unitaires en unités mineures au moment de la vente
    // (ItemVendu ne connaît pas sa propre devise, elle est globale à la
    // boutique) : le calcul du total et de la marge de cette transaction
    // ne dépendra plus jamais du prix courant du produit ni d'un
    // arrondi flottant.
    final decimales = decimalesPourCodeIso(devise);
    for (final item in panier) {
      item.prixUnitaireVenteMineur = versUnitesMineures(
        item.prixUnitaireVente,
        decimales,
      );
      item.prixUnitaireAchatMineur = versUnitesMineures(
        item.prixUnitaireAchat,
        decimales,
      );
    }

    final montantTotal = panier.fold<double>(0, (s, i) => s + i.sousTotal);
    final margeBrute = panier.fold<double>(0, (s, i) => s + i.margeBrute);
    final montantTotalMineur = panier.fold<int>(
      0,
      (s, i) => s + i.sousTotalMineur,
    );
    final margeBruteMineur = panier.fold<int>(
      0,
      (s, i) => s + i.margeBruteMineur,
    );

    final transaction = model.Transaction(
      id: _uuid.v4(),
      date: DateTime.now(),
      itemsVendus: panier,
      montantTotal: montantTotal,
      margeBrute: margeBrute,
      devise: devise,
      montantTotalMineur: montantTotalMineur,
      margeBruteMineur: margeBruteMineur,
      modePaiement: modePaiement,
      deviceId: DeviceIdService.obtenir(),
      lastModified: DateTime.now(),
    );

    // Phase 3 : écritures. Un snapshot du stock de chaque produit validé
    // est pris AVANT la moindre écriture : c'est lui qui sert au rollback,
    // donc il couvre aussi les produits validés jamais décrémentés
    // (restauration à valeur identique, sans effet).
    final stockAvantVente = <String, int>{
      for (final e in produitsTouches.entries) e.key: e.value.stockActuel,
    };
    var transactionEcrit = false;
    try {
      for (final retrait in retraitsParProduit.entries) {
        await _produitService.decrementerStock(retrait.key, retrait.value);
      }
      await HiveService.transactionsBox.put(transaction.id, transaction);
      transactionEcrit = true;
      return transaction;
    } catch (erreur) {
      // Rollback par compensation : remise en état mémoire + disque.
      // Si la persistance du rollback échoue elle aussi, la mémoire reste
      // juste et on le signale à l'appelant plutôt que de laisser croire
      // à un échec silencieux.
      var rollbackPersiste = true;
      for (final produit in produitsTouches.values) {
        produit.stockActuel = stockAvantVente[produit.id]!;
        produit.deviceId = DeviceIdService.obtenir();
        produit.lastModified = DateTime.now();
        try {
          await produit.save();
        } catch (_) {
          rollbackPersiste = false;
        }
      }
      if (!transactionEcrit) {
        // La transaction a pu être écrite avant l'erreur (le `put` Hive
        // n'est jamais partiel en pratique, mais si un handle défaillant
        // l'a laissée passer, elle ne doit pas rester dans le journal) :
        // on la retire, best effort.
        try {
          await HiveService.transactionsBox.delete(transaction.id);
        } catch (_) {}
      }
      if (!rollbackPersiste) {
        throw Exception(
          "La vente a échoué (erreur d'origine : $erreur) et la remise "
          "en stock n'a pas pu être entièrement persistée : les valeurs "
          'en mémoire sont correctes, mais un contrôle du stock est '
          'recommandé.',
        );
      }
      rethrow;
    }
  }

  /// Finalise une vente à crédit : le stock est décrémenté et la vente est
  /// actée comme n'importe quelle transaction (voir [finaliserVente]), mais
  /// aucun argent n'est encaissé — une [Dette] liée est créée pour le suivi
  /// du recouvrement (relance WhatsApp/SMS, paiements partiels).
  ///
  /// Comme [finaliserVente], l'ensemble « vente + dette liée » s'exécute
  /// sous [_verrouVentes] en un seul geste : une vente concurrente ne
  /// peut s'intercaler ni entre le stock et la transaction, ni entre la
  /// transaction et la dette. D'où l'appel direct à
  /// [_finaliserVenteSousVerrou] (pas de ré-acquisition du verrou).
  ///
  /// L'opération est aussi **atomique du point de vue métier** : si la
  /// vente réussit mais que la création de la dette échoue, une vente
  /// sans dette liée est une incohérence financière — les écritures de la
  /// vente sont donc **compensées** (stock restauré depuis un snapshot
  /// pris sous verrou avant toute écriture, transaction retirée, dette
  /// éventuellement déjà écrite supprimée) et l'erreur d'origine est
  /// re-propagée telle quelle. Si la compensation elle-même échoue en
  /// partie, une exception explicite combine l'erreur d'origine et les
  /// actions restées incomplètes — même principe que le message de
  /// rollback de [_finaliserVenteSousVerrou]. Rien n'est compensé si c'est
  /// la *vente* qui échoue : son rollback interne traite déjà tout, et une
  /// restitution ici serait une double restauration du stock.
  Future<model.Transaction> finaliserVenteACredit({
    required List<ItemVendu> panier,
    required String devise,
    required String nomClient,
    required String telephone,
  }) {
    return _verrouVentes.executer(() async {
      // Snapshot du stock courant, sous le verrou et avant toute écriture :
      // il reflète donc l'état réel, y compris si une vente concurrente sur
      // le même produit a déjà tourné avant celle-ci. Il ne sert qu'à la
      // compensation « vente réussie / dette échouée » ci-dessous.
      final produitsTouches = <String, Produit>{};
      for (final item in panier) {
        final produit = _produitService.trouverParId(item.produitId);
        if (produit != null) produitsTouches[item.produitId] = produit;
      }
      final stockAvantVente = <String, int>{
        for (final e in produitsTouches.entries) e.key: e.value.stockActuel,
      };

      // Vente : atomique en soi (C1). Si elle échoue, son rollback interne
      // a déjà remis l'état en ordre : l'erreur est renvoyée telle quelle,
      // sans compensation supplémentaire ici.
      final transaction = await _finaliserVenteSousVerrou(
        panier: panier,
        devise: devise,
        modePaiement: ModePaiement.credit,
      );

      try {
        await _detteService.ajouter(
          nomClient: nomClient,
          telephone: telephone,
          montantDu: transaction.montantTotal,
          devise: devise,
          dateDette: transaction.date,
          transactionId: transaction.id,
        );
        return transaction;
      } catch (erreurDette) {
        // À partir d'ici la vente est un fait acquis (stock décrémenté +
        // transaction écrite). On compense de façon inverse aux écritures :
        // stock d'abord (restitution mémoire + disque), puis transaction,
        // puis une dette qui aurait été écrite avant l'erreur.
        final compensationsEchouees = <String>[];

        var stockRestaure = true;
        for (final produit in produitsTouches.values) {
          produit.stockActuel = stockAvantVente[produit.id]!;
          produit.deviceId = DeviceIdService.obtenir();
          produit.lastModified = DateTime.now();
          try {
            await produit.save();
          } catch (_) {
            stockRestaure = false;
          }
        }
        if (!stockRestaure) {
          compensationsEchouees.add('restauration du stock sur disque');
        }

        // La transaction identifiée par [transaction.id] est celle créée
        // par la vente qui vient d'échouer (identifiant interne à un uuid
        // fraîchement tiré) : la retirer ne peut toucher aucune vente
        // préexistante.
        try {
          await HiveService.transactionsBox.delete(transaction.id);
        } catch (_) {
          compensationsEchouees.add('suppression de la transaction');
        }

        // Une dette déjà écrite avant l'erreur ne doit pas survivre à une
        // vente annulée (même raisonnement : transactionId fraîchement
        // créé, aucune dette préexistante ne peut y correspondre).
        try {
          final detteOrpheline = _detteService.trouverParTransactionId(
            transaction.id,
          );
          if (detteOrpheline != null) {
            await _detteService.supprimer(detteOrpheline.id);
          }
        } catch (_) {
          compensationsEchouees.add('suppression de la dette orpheline');
        }

        if (compensationsEchouees.isNotEmpty) {
          // Compensation incomplète : erreur explicite qui emporte l'erreur
          // d'origine, pour ne jamais la masquer (même principe que le
          // message de rollback de [_finaliserVenteSousVerrou]).
          throw Exception(
            "La vente à crédit a échoué (erreur d'origine : $erreurDette) "
            'et la remise en état a été incomplète '
            '(${compensationsEchouees.join(', ')}) : un contrôle du stock, '
            'des transactions et du carnet de dettes est recommandé.',
          );
        }

        // Compensation complète : l'état est celui d'avant la tentative,
        // l'appelant voit l'erreur de création de dette, rien de plus.
        rethrow;
      }
    });
  }

  /// Annule une vente de façon **atomique et sérialisée** : remise en
  /// stock de chaque article vendu, suppression de la dette liée pour une
  /// vente à crédit (plus rien à recouvrer), puis marquage de la
  /// transaction ([model.Transaction.marquerAnnulee]) — elle n'est jamais
  /// supprimée physiquement, seulement exclue des statistiques du jour
  /// ([transactionsDuJour]) tout en restant consultable dans le journal
  /// ([toutesLesTransactions]).
  ///
  /// S'exécute sous [_verrouVentes], comme les ventes : la remise de stock
  /// ne peut s'entrelacer avec une finalisation (ni se faire écraser par
  /// le rollback d'une vente concurrente, ni s'en faire le témoin
  /// intermédiaire).
  ///
  /// Quatre phases (correction C5) :
  ///
  /// 0. Validation complète **avant la moindre écriture** :
  ///    - la transaction doit exister et n'être pas déjà annulée ;
  ///    - pour une vente à crédit, la dette liée
  ///      ([DetteService.trouverParTransactionId]) ne doit avoir reçu
  ///      **aucun** paiement — dans le cas contraire l'annulation est
  ///      bloquée sans la moindre écriture : supprimer la dette ferait
  ///      disparaître un encaissement réel déjà en caisse ;
  ///    - chaque produit à restituer doit exister encore. Les
  ///      restitutions sont **agrégées** par produit (itemsVendus peut
  ///      contenir plusieurs lignes du même produit avec des
  ///      conditionnements différents). Si un produit a été supprimé
  ///      depuis la vente, l'annulation est REFUSÉE avant tout changement
  ///      avec un message nommant le produit : la dette reste intacte,
  ///      les stocks ne bougent pas et la vente reste comptée.
  /// 1. Remise en stock : **une seule écriture par produit agrégé** (pas
  ///    une par ligne de la vente).
  /// 2. Suppression de la dette liée, seulement après une remise en stock
  ///    réussie (pas de dette : vente au comptant ou dette déjà absente —
  ///    continuer normalement).
  /// 3. Marquage de la transaction, **en dernier** : tant que tout n'a
  ///    pas réussi, la vente reste comptée dans le chiffre d'affaires.
  ///
  /// Si une écriture échoue après le début des écritures, un rollback
  /// compense dans l'ordre inverse des artefacts touchés :
  ///
  /// - **stocks** : restaurés depuis les snapshots pris sous verrou avant
  ///   toute écriture (voir [finaliserVente] pour le même principe),
  ///   re-persistés un par un — sans jamais ressusciter un produit
  ///   supprimé entre-temps ;
  /// - **dette** : si sa suppression a été tentée, elle est réécrite
  ///   **telle quelle** via HiveService.dettesBox.put — jamais
  ///   [DetteService.ajouter], qui générerait un nouvel identifiant et
  ///   re-normaliserait le téléphone ;
  /// - **transaction** : si le marquage a été tenté, ses champs
  ///   d'annulation sont restaurés depuis le snapshot et une nouvelle
  ///   tentative de sauvegarde (best-effort) est faite.
  ///
  /// Compensation complète → l'erreur d'origine est re-propagée telle
  /// quelle, sans la masquer. Compensation incomplète → une exception
  /// explicite combine l'erreur d'origine et la liste des opérations non
  /// restaurées (stock / dette / transaction) et recommande un contrôle
  /// manuel — même principe que le message de rollback de
  /// [_finaliserVenteSousVerrou].
  Future<model.Transaction> annulerTransaction({
    required String transactionId,
    required String motif,
  }) {
    return _verrouVentes.executer(() async {
      //
      // Phase 0 — validation complète, avant toute écriture. Si cette
      // phase échoue, rien n'a été modifié : ni stock, ni dette, ni
      // transaction.
      //
      final transaction = HiveService.transactionsBox.get(transactionId);
      if (transaction == null) {
        throw Exception('Transaction introuvable');
      }
      if (transaction.annulee) {
        throw Exception('Cette vente est déjà annulée');
      }

      // Agrégation des restitutions par produit : le stock est compté en
      // unité de base, [quantite] exemplaires d'une ligne valent
      // [quantite] × [quantiteEnUniteBase] unités. Deux lignes du même
      // produit (conditionnements différents) restituent un stock commun
      // et doivent être traitées ensemble, pas ligne par ligne — c'est
      // l'opération miroir de l'agrégation de _finaliserVenteSousVerrou.
      final restitutionsParProduit = <String, int>{};
      for (final item in transaction.itemsVendus) {
        restitutionsParProduit[item.produitId] =
            (restitutionsParProduit[item.produitId] ?? 0) +
            item.quantite * item.quantiteEnUniteBase;
      }

      // Vente à crédit : retrouver la dette liée. Si elle existe, aucun
      // paiement ne doit avoir été enregistré dessus — contrôle fait
      // AVANT l'existence des produits (l'encaissement réel prime),
      // refus immédiat sans la moindre écriture.
      Dette? detteLiee;
      if (transaction.modePaiement == ModePaiement.credit) {
        detteLiee = _detteService.trouverParTransactionId(transaction.id);
        if (detteLiee != null &&
            _detteService.paiementsPour(detteLiee.id).isNotEmpty) {
          throw Exception(
            "Impossible d'annuler : des paiements ont déjà été reçus "
            'sur la dette liée.',
          );
        }
      }

      // Tous les produits à restituer doivent exister encore : remettre
      // en stock un produit supprimé est impossible, et annuler sans lui
      // laisser un stock inexistant. Refus AVANT toute écriture — la
      // dette reste intacte et la vente reste comptée dans le CA.
      final produitsTouches = <String, Produit>{};
      for (final produitId in restitutionsParProduit.keys) {
        final produit = _produitService.trouverParId(produitId);
        if (produit == null) {
          final nomProduit = transaction.itemsVendus
              .firstWhere((i) => i.produitId == produitId)
              .nomProduit;
          throw Exception(
            "Impossible d'annuler la vente : le produit « $nomProduit » "
            '($produitId) n\'existe plus (supprimé depuis la vente). '
            "Aucun changement n'a été effectué : le stock, la dette "
            "liée et la transaction sont inchangés.",
          );
        }
        produitsTouches[produitId] = produit;
      }

      // Snapshots pour le rollback : stock (et champs de synchronisation)
      // de chaque produit concerné, état d'annulation de la transaction,
      // référence de la dette s'il y en a une.
      final stocksAvant = <String, _EtatProduitFigee>{
        for (final e in produitsTouches.entries)
          e.key: _EtatProduitFigee(
            stockActuel: e.value.stockActuel,
            deviceId: e.value.deviceId,
            lastModified: e.value.lastModified,
          ),
      };
      final annulationAvant = _EtatAnnulationFigee(
        annulee: transaction.annulee,
        dateAnnulation: transaction.dateAnnulation,
        motifAnnulation: transaction.motifAnnulation,
        deviceId: transaction.deviceId,
        lastModified: transaction.lastModified,
      );

      // Suivi des écritures tentées, pour ne compenser que ce qui a
      // effectivement pu être touché : une phase qui n'a pas démarré
      // n'a rien à annuler.
      var detteSupprimeeTentee = false;
      var marquageTente = false;
      try {
        // Phase 1 — remise en stock : une seule écriture par produit
        // agrégé (pas une par ligne de la vente).
        for (final restitution in restitutionsParProduit.entries) {
          await _produitService.reapprovisionner(
            restitution.key,
            restitution.value,
          );
        }

        // Phase 2 — suppression de la dette liée, uniquement après que
        // toute la remise en stock a réussi.
        if (detteLiee != null) {
          detteSupprimeeTentee = true;
          await _detteService.supprimer(detteLiee.id);
        }

        // Phase 3 — marquage en dernier : tant que tout n'a pas réussi,
        // la vente reste comptée dans le chiffre d'affaires.
        marquageTente = true;
        transaction.marquerAnnulee(motif: motif);
        transaction.deviceId = DeviceIdService.obtenir();
        await transaction.save();
        return transaction;
      } on Object catch (erreurOrigine) {
        // Rollback par compensation : remise en état mémoire + disque,
        // dans l'ordre inverse des artefacts touchés (stocks, dette,
        // transaction). Si une persistance de compensation échoue
        // elle aussi, l'opération est signalée à l'appelant plutôt que
        // de laisser croire à un échec silencieux.
        final operationsNonRestaurees = <String>[];

        // 1) Stocks : valeur du snapshot (stock, deviceId, lastModified),
        //    puis save pour chaque produit touché. Un produit supprimé
        //    entre-temps n'est PAS ressuscité : son réapprovisionnement
        //    n'a rien restitué, et un save() sur l'objet détaché
        //    réécrirait sa clé — réinjectant une fiche orpheline dans
        //    la boutique. D'où le contrôle par la box, clé absente = on
        //    passe.
        var stockPersiste = true;
        for (final produit in produitsTouches.values) {
          if (!HiveService.produitsBox.containsKey(produit.id)) continue;
          final avant = stocksAvant[produit.id]!;
          produit.stockActuel = avant.stockActuel;
          produit.deviceId = avant.deviceId;
          produit.lastModified = avant.lastModified;
          try {
            await produit.save();
          } catch (_) {
            stockPersiste = false;
          }
        }
        if (!stockPersiste) {
          operationsNonRestaurees.add('restauration du stock sur disque');
        }

        // 2) Dette : si sa suppression a été tentée (elle a peut-être
        //    déjà quitté la box quand l'erreur a surgi), la réécrire
        //    TELLE QUELLE — même objet, même id — via la box Hive.
        //    Jamais DetteService.ajouter : nouvel identifiant et
        //    re-normalisation du téléphone, donc une dette différente.
        if (detteSupprimeeTentee) {
          try {
            await HiveService.dettesBox.put(detteLiee!.id, detteLiee);
          } catch (_) {
            operationsNonRestaurees.add('réécriture de la dette');
          }
        }

        // 3) Transaction : le marquage a modifié les champs d'annulation
        //    de l'objet en mémoire — les restaurer depuis le snapshot,
        //    puis retenter une sauvegarde best-effort pour remettre le
        //    disque d'accord (l'objet reste compté dans le CA).
        if (marquageTente) {
          transaction.annulee = annulationAvant.annulee;
          transaction.dateAnnulation = annulationAvant.dateAnnulation;
          transaction.motifAnnulation = annulationAvant.motifAnnulation;
          transaction.deviceId = annulationAvant.deviceId;
          transaction.lastModified = annulationAvant.lastModified;
          try {
            await transaction.save();
          } catch (_) {
            operationsNonRestaurees.add('restauration de la transaction');
          }
        }

        if (operationsNonRestaurees.isNotEmpty) {
          // Compensation incomplète : exception explicite qui emporte
          // l'erreur d'origine, pour ne jamais la masquer.
          throw Exception(
            "L'annulation de la vente a échoué (erreur d'origine : "
            '$erreurOrigine) et la remise en état a été incomplète '
            '(${operationsNonRestaurees.join(', ')}) : un contrôle '
            'manuel du stock, de la transaction et du carnet de dettes '
            'est recommandé.',
          );
        }

        // Compensation complète : l'état est celui d'avant la tentative,
        // l'appelant voit l'erreur d'origine, rien de plus.
        rethrow;
      }
    });
  }

  /// Transactions du jour, hors ventes annulées (voir
  /// [model.Transaction.annulee]) : source des statistiques de caisse.
  /// Pour un journal incluant les ventes annulées, voir
  /// [toutesLesTransactions].
  List<model.Transaction> transactionsDuJour({DateTime? jour}) {
    final j = jour ?? DateTime.now();
    return HiveService.transactionsBox.values
        .where(
          (t) =>
              !t.annulee &&
              t.date.year == j.year &&
              t.date.month == j.month &&
              t.date.day == j.day,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double totalDuJour({DateTime? jour}) {
    return transactionsDuJour(
      jour: jour,
    ).fold<double>(0, (s, t) => s + t.montantTotal);
  }

  double margeBruteDuJour({DateTime? jour}) {
    return transactionsDuJour(
      jour: jour,
    ).fold<double>(0, (s, t) => s + t.margeBrute);
  }

  /// Additionne les montants en unités mineures (entiers) : source de
  /// vérité pour l'affichage, sans dérive d'arrondi flottant. Pour une
  /// transaction historique enregistrée avant l'introduction de ce champ
  /// (valeur par défaut 0), le montant est reconverti à la volée depuis
  /// le double existant plutôt que d'être compté comme nul.
  int totalDuJourMineur({DateTime? jour}) {
    return transactionsDuJour(jour: jour).fold<int>(
      0,
      (s, t) =>
          s +
          _mineurOuRecalcule(t.montantTotalMineur, t.montantTotal, t.devise),
    );
  }

  int margeBruteDuJourMineur({DateTime? jour}) {
    return transactionsDuJour(jour: jour).fold<int>(
      0,
      (s, t) =>
          s + _mineurOuRecalcule(t.margeBruteMineur, t.margeBrute, t.devise),
    );
  }

  /// Encaissements réels du jour, en unités mineures : à distinguer du
  /// chiffre d'affaires ([totalDuJourMineur]), qui inclut les ventes à
  /// crédit non encore payées. Additionne les ventes réglées au comptant
  /// aujourd'hui et les paiements de dettes reçus aujourd'hui — que la
  /// dette d'origine date d'aujourd'hui ou d'un jour antérieur. Un paiement
  /// de dette n'est jamais compté comme une vente : voir
  /// DetteService.enregistrerPaiement.
  int encaissementsDuJourMineur({DateTime? jour}) {
    final j = jour ?? DateTime.now();
    final ventesEncaissees = transactionsDuJour(jour: j)
        .where((t) => t.modePaiement != ModePaiement.credit)
        .fold<int>(
          0,
          (s, t) =>
              s +
              _mineurOuRecalcule(
                t.montantTotalMineur,
                t.montantTotal,
                t.devise,
              ),
        );
    final paiementsDettes = HiveService.paiementsDetteBox.values
        .where(
          (p) =>
              p.date.year == j.year &&
              p.date.month == j.month &&
              p.date.day == j.day,
        )
        .fold<int>(0, (s, p) => s + p.montantMineur);
    return ventesEncaissees + paiementsDettes;
  }

  int _mineurOuRecalcule(int mineur, double montant, String devise) {
    if (mineur != 0 || montant == 0) return mineur;
    return versUnitesMineures(montant, decimalesPourCodeIso(devise));
  }

  /// Transactions non annulées dont la date tombe dans [plage] — sert au
  /// tableau de bord par période (jour/semaine/mois), séparé de
  /// [transactionsDuJour] pour ne jamais modifier le comportement déjà
  /// testé de l'écran Caisse.
  List<model.Transaction> _transactionsSur(PlagePeriode plage) {
    return HiveService.transactionsBox.values
        .where((t) => !t.annulee && plage.contient(t.date))
        .toList();
  }

  /// Chiffre d'affaires sur une [Periode] (jour, semaine ou mois),
  /// utilisé par le tableau de bord de la Phase 7 (voir DepenseService
  /// pour les dépenses de la même période, et [margeBruteMineurSur] pour
  /// la marge).
  int totalMineurSur(Periode periode, {DateTime? reference}) {
    final plage = plagePour(periode, reference: reference);
    return _transactionsSur(plage).fold<int>(
      0,
      (s, t) =>
          s +
          _mineurOuRecalcule(t.montantTotalMineur, t.montantTotal, t.devise),
    );
  }

  int margeBruteMineurSur(Periode periode, {DateTime? reference}) {
    final plage = plagePour(periode, reference: reference);
    return _transactionsSur(plage).fold<int>(
      0,
      (s, t) =>
          s + _mineurOuRecalcule(t.margeBruteMineur, t.margeBrute, t.devise),
    );
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

/// État d'un produit figé par [CaisseService.annulerTransaction] avant
/// toute écriture : sert au rollback à restaurer exactement le stock tel
/// qu'il était sous verrou (deviceId et lastModified y sont figés aussi,
/// car c'est le triple que réapprovisionner modifie).
class _EtatProduitFigee {
  final int stockActuel;
  final String deviceId;
  final DateTime? lastModified;

  const _EtatProduitFigee({
    required this.stockActuel,
    required this.deviceId,
    required this.lastModified,
  });
}

/// Champs d'annulation d'une transaction figés par
/// [CaisseService.annulerTransaction] avant toute écriture :
/// [model.Transaction.marquerAnnulee] modifie annulee, dateAnnulation,
/// motifAnnulation et lastModified — et l'écriture finale recycle
/// deviceId. Le rollback restaure les cinq à l'identique.
class _EtatAnnulationFigee {
  final bool annulee;
  final DateTime? dateAnnulation;
  final String? motifAnnulation;
  final String deviceId;
  final DateTime? lastModified;

  const _EtatAnnulationFigee({
    required this.annulee,
    required this.dateAnnulation,
    required this.motifAnnulation,
    required this.deviceId,
    required this.lastModified,
  });
}
