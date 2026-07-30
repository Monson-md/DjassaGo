import 'package:uuid/uuid.dart';

import '../models/item_vendu.dart';
import '../models/mode_paiement.dart';
import '../models/transaction.dart' as model;
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import '../utils/periodes.dart';
import 'dette_service.dart';
import 'hive_service.dart';
import 'produit_service.dart';

/// Gère l'enregistrement des ventes (transactions) et les statistiques
/// de caisse (total et marge brute du jour, et par période pour le
/// tableau de bord — voir [totalMineurSur]/[margeBruteMineurSur]).
class CaisseService {
  static const _uuid = Uuid();

  final ProduitService _produitService;
  final DetteService _detteService;

  CaisseService({ProduitService? produitService, DetteService? detteService})
      : _produitService = produitService ?? ProduitService(),
        _detteService = detteService ?? DetteService();

  /// Finalise une vente : décrémente le stock de chaque produit vendu,
  /// calcule le total et le bénéfice net, puis enregistre la transaction.
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
  }) async {
    if (panier.isEmpty) {
      throw Exception('Le panier est vide');
    }

    for (final item in panier) {
      await _produitService.decrementerStock(item.produitId, item.quantite);
    }

    // Fige les prix unitaires en unités mineures au moment de la vente
    // (ItemVendu ne connaît pas sa propre devise, elle est globale à la
    // boutique) : le calcul du total et de la marge de cette transaction
    // ne dépendra plus jamais du prix courant du produit ni d'un
    // arrondi flottant.
    final decimales = decimalesPourCodeIso(devise);
    for (final item in panier) {
      item.prixUnitaireVenteMineur =
          versUnitesMineures(item.prixUnitaireVente, decimales);
      item.prixUnitaireAchatMineur =
          versUnitesMineures(item.prixUnitaireAchat, decimales);
    }

    final montantTotal = panier.fold<double>(0, (s, i) => s + i.sousTotal);
    final margeBrute = panier.fold<double>(0, (s, i) => s + i.margeBrute);
    final montantTotalMineur =
        panier.fold<int>(0, (s, i) => s + i.sousTotalMineur);
    final margeBruteMineur =
        panier.fold<int>(0, (s, i) => s + i.margeBruteMineur);

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
    );

    await HiveService.transactionsBox.put(transaction.id, transaction);
    return transaction;
  }

  /// Finalise une vente à crédit : le stock est décrémenté et la vente est
  /// actée comme n'importe quelle transaction (voir [finaliserVente]), mais
  /// aucun argent n'est encaissé — une [Dette] liée est créée pour le suivi
  /// du recouvrement (relance WhatsApp/SMS, paiements partiels).
  Future<model.Transaction> finaliserVenteACredit({
    required List<ItemVendu> panier,
    required String devise,
    required String nomClient,
    required String telephone,
  }) async {
    final transaction = await finaliserVente(
      panier: panier,
      devise: devise,
      modePaiement: ModePaiement.credit,
    );

    await _detteService.ajouter(
      nomClient: nomClient,
      telephone: telephone,
      montantDu: transaction.montantTotal,
      devise: devise,
      dateDette: transaction.date,
      transactionId: transaction.id,
    );

    return transaction;
  }

  /// Annule une vente : remet en stock chaque article vendu et marque la
  /// transaction comme annulée (voir [model.Transaction.marquerAnnulee]) —
  /// elle n'est jamais supprimée physiquement, seulement exclue des
  /// statistiques du jour ([transactionsDuJour]) tout en restant
  /// consultable dans le journal ([toutesLesTransactions]).
  ///
  /// Si la vente était à crédit, la dette liée est supprimée (la vente est
  /// nulle, il n'y a plus rien à recouvrer) — mais seulement si aucun
  /// paiement n'a encore été reçu dessus. Dans le cas contraire,
  /// l'annulation est bloquée : supprimer la dette ferait disparaître un
  /// encaissement réel déjà en caisse.
  Future<model.Transaction> annulerTransaction({
    required String transactionId,
    required String motif,
  }) async {
    final transaction = HiveService.transactionsBox.get(transactionId);
    if (transaction == null) {
      throw Exception('Transaction introuvable');
    }
    if (transaction.annulee) {
      throw Exception('Cette vente est déjà annulée');
    }

    if (transaction.modePaiement == ModePaiement.credit) {
      final dette = _detteService.trouverParTransactionId(transaction.id);
      if (dette != null) {
        if (_detteService.paiementsPour(dette.id).isNotEmpty) {
          throw Exception(
              "Impossible d'annuler : des paiements ont déjà été reçus sur la dette liée.");
        }
        await _detteService.supprimer(dette.id);
      }
    }

    for (final item in transaction.itemsVendus) {
      await _produitService.reapprovisionner(item.produitId, item.quantite);
    }

    transaction.marquerAnnulee(motif: motif);
    await transaction.save();
    return transaction;
  }

  /// Transactions du jour, hors ventes annulées (voir
  /// [model.Transaction.annulee]) : source des statistiques de caisse.
  /// Pour un journal incluant les ventes annulées, voir
  /// [toutesLesTransactions].
  List<model.Transaction> transactionsDuJour({DateTime? jour}) {
    final j = jour ?? DateTime.now();
    return HiveService.transactionsBox.values
        .where((t) =>
            !t.annulee &&
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

  double margeBruteDuJour({DateTime? jour}) {
    return transactionsDuJour(jour: jour)
        .fold<double>(0, (s, t) => s + t.margeBrute);
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
            s + _mineurOuRecalcule(t.montantTotalMineur, t.montantTotal, t.devise));
  }

  int margeBruteDuJourMineur({DateTime? jour}) {
    return transactionsDuJour(jour: jour).fold<int>(
        0,
        (s, t) =>
            s + _mineurOuRecalcule(t.margeBruteMineur, t.margeBrute, t.devise));
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
            (s, t) => s +
                _mineurOuRecalcule(t.montantTotalMineur, t.montantTotal, t.devise));
    final paiementsDettes = HiveService.paiementsDetteBox.values
        .where((p) =>
            p.date.year == j.year &&
            p.date.month == j.month &&
            p.date.day == j.day)
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
            s + _mineurOuRecalcule(t.montantTotalMineur, t.montantTotal, t.devise));
  }

  int margeBruteMineurSur(Periode periode, {DateTime? reference}) {
    final plage = plagePour(periode, reference: reference);
    return _transactionsSur(plage).fold<int>(
        0,
        (s, t) =>
            s + _mineurOuRecalcule(t.margeBruteMineur, t.margeBrute, t.devise));
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
