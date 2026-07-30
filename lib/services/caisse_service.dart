import 'package:uuid/uuid.dart';

import '../models/item_vendu.dart';
import '../models/mode_paiement.dart';
import '../models/transaction.dart' as model;
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import 'dette_service.dart';
import 'hive_service.dart';
import 'produit_service.dart';

/// Gère l'enregistrement des ventes (transactions) et les statistiques
/// de caisse (total et bénéfice net du jour).
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
    final beneficeNet = panier.fold<double>(0, (s, i) => s + i.benefice);
    final montantTotalMineur =
        panier.fold<int>(0, (s, i) => s + i.sousTotalMineur);
    final beneficeNetMineur =
        panier.fold<int>(0, (s, i) => s + i.beneficeMineur);

    final transaction = model.Transaction(
      id: _uuid.v4(),
      date: DateTime.now(),
      itemsVendus: panier,
      montantTotal: montantTotal,
      beneficeNet: beneficeNet,
      devise: devise,
      montantTotalMineur: montantTotalMineur,
      beneficeNetMineur: beneficeNetMineur,
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

  int beneficeNetDuJourMineur({DateTime? jour}) {
    return transactionsDuJour(jour: jour).fold<int>(
        0,
        (s, t) =>
            s + _mineurOuRecalcule(t.beneficeNetMineur, t.beneficeNet, t.devise));
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
