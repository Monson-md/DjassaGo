import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/dette.dart';
import '../models/paiement_dette.dart';
import '../utils/devises_disponibles.dart';
import '../utils/money.dart';
import 'hive_service.dart';

/// Gère le carnet de dettes : CRUD, paiements, et génération de messages
/// de relance prêts à être envoyés par WhatsApp ou SMS.
class DetteService {
  static const _uuid = Uuid();

  List<Dette> listerToutes() {
    return HiveService.dettesBox.values.toList()
      ..sort((a, b) => b.dateDette.compareTo(a.dateDette));
  }

  List<Dette> listerEnCours() {
    return listerToutes()
        .where((d) => d.statut != StatutDette.payee)
        .toList();
  }

  /// Retrouve la dette générée par une vente à crédit (voir
  /// CaisseService.finaliserVenteACredit / annulerTransaction). `null` si la
  /// transaction n'a pas de dette liée, ou si elle a déjà été supprimée.
  Dette? trouverParTransactionId(String transactionId) {
    try {
      return HiveService.dettesBox.values
          .firstWhere((d) => d.transactionId == transactionId);
    } catch (_) {
      return null;
    }
  }

  double totalDettesEnCours() {
    return listerEnCours().fold<double>(0, (s, d) => s + d.montantDu);
  }

  Future<Dette> ajouter({
    required String nomClient,
    required String telephone,
    required double montantDu,
    required String devise,
    DateTime? dateDette,
    String? note,
    String? transactionId,
  }) async {
    final dette = Dette(
      id: _uuid.v4(),
      nomClient: nomClient,
      telephone: telephone,
      montantDu: montantDu,
      dateDette: dateDette ?? DateTime.now(),
      devise: devise,
      note: note,
      transactionId: transactionId,
    );
    await HiveService.dettesBox.put(dette.id, dette);
    return dette;
  }

  /// Enregistre un paiement (total ou partiel) contre une dette. Contrairement
  /// au chiffre d'affaires (reconnu au moment de la vente à crédit), ceci est
  /// un encaissement pur : il ne doit jamais être recompté comme une vente.
  /// Un [PaiementDette] immuable est conservé pour l'historique et pour le
  /// calcul des encaissements du jour (voir CaisseService.encaissementsDuJourMineur).
  Future<void> enregistrerPaiement(Dette dette, double montantPaye) async {
    final nouveauMontant = dette.montantDu - montantPaye;
    dette.definirMontantDu(nouveauMontant <= 0 ? 0 : nouveauMontant);
    dette.statut = dette.montantDu <= 0
        ? StatutDette.payee
        : StatutDette.partiellementPayee;
    await dette.save();

    final paiement = PaiementDette(
      id: _uuid.v4(),
      detteId: dette.id,
      montant: montantPaye,
      date: DateTime.now(),
      devise: dette.devise,
    );
    await HiveService.paiementsDetteBox.put(paiement.id, paiement);
  }

  List<PaiementDette> paiementsPour(String detteId) {
    return HiveService.paiementsDetteBox.values
        .where((p) => p.detteId == detteId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int totalDettesEnCoursMineur() {
    return listerEnCours().fold<int>(0, (s, d) => s + d.montantDuMineur);
  }

  Future<void> supprimer(String id) async {
    await HiveService.dettesBox.delete(id);
  }

  /// Génère un message de relance formaté et personnalisé pour une dette.
  String genererMessageRelance(Dette dette, {String nomCommerce = 'notre boutique'}) {
    final formateurDate = DateFormat('dd/MM/yyyy');
    final montant = formaterMontantMineur(
      dette.montantDuMineur,
      decimales: decimalesPourCodeIso(dette.devise),
    );
    final date = formateurDate.format(dette.dateDette);

    return 'Bonjour ${dette.nomClient}, '
        'ceci est un rappel amical de $nomCommerce. '
        'Vous avez une dette de $montant ${dette.devise} '
        'depuis le $date. '
        'Merci de bien vouloir régulariser dès que possible. '
        'Bonne journée !';
  }

  String _nettoyerTelephone(String telephone) {
    return telephone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  /// Ouvre WhatsApp avec le message de relance pré-rempli pour ce client.
  Future<bool> envoyerRelanceWhatsApp(Dette dette, {String? nomCommerce}) async {
    final telephone = _nettoyerTelephone(dette.telephone).replaceFirst('+', '');
    final message = genererMessageRelance(dette, nomCommerce: nomCommerce ?? 'notre boutique');
    final uri = Uri.parse('https://wa.me/$telephone?text=${Uri.encodeComponent(message)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Ouvre l'application SMS avec le message de relance pré-rempli.
  Future<bool> envoyerRelanceSms(Dette dette, {String? nomCommerce}) async {
    final telephone = _nettoyerTelephone(dette.telephone);
    final message = genererMessageRelance(dette, nomCommerce: nomCommerce ?? 'notre boutique');
    final uri = Uri(
      scheme: 'sms',
      path: telephone,
      queryParameters: {'body': message},
    );
    return launchUrl(uri);
  }
}
