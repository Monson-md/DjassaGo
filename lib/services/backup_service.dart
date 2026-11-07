import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/conditionnement.dart';
import '../models/depense.dart';
import '../models/dette.dart';
import '../models/paiement_dette.dart';
import '../models/produit.dart';
import '../models/transaction.dart' as model;
import 'conditionnement_service.dart';
import 'hive_service.dart';

/// Aperçu du contenu d'un fichier de sauvegarde, affiché avant
/// restauration pour que le commerçant sache ce qu'il s'apprête à
/// importer (ex: « 42 produits, 318 ventes, 12 dettes »).
class ApercuSauvegarde {
  final int nombreProduits;
  final int nombreVentes;
  final int nombreDettes;
  final DateTime? exporteLe;

  const ApercuSauvegarde({
    required this.nombreProduits,
    required this.nombreVentes,
    required this.nombreDettes,
    this.exporteLe,
  });
}

/// Le fichier annonce une version de format que cette version de
/// l'application ne sait pas lire (sauvegarde produite par une version
/// plus récente, ou fichier corrompu). Levée pendant la validation en
/// mémoire : AUCUNE donnée locale n'a été touchée.
class VersionSauvegardeNonSupporteeException implements Exception {
  /// Version de format lue dans le fichier.
  final int versionFichier;

  /// Version de format maximum reconnue par cette version de l'app
  /// ([BackupService.formatVersion]).
  final int versionMaxSupportee;

  const VersionSauvegardeNonSupporteeException({
    required this.versionFichier,
    required this.versionMaxSupportee,
  });

  @override
  String toString() =>
      'Restauration refusée : cette sauvegarde est au format $versionFichier, '
      'trop récent pour cette version de l\'application (maximum reconnu : '
      '$versionMaxSupportee). Mettez l\'application à jour puis réessayez. '
      'Aucune donnée locale n\'a été modifiée.';
}

/// Sauvegarde lisible mais contenu refusé : enregistrement corrompu,
/// identifiant vide ou dupliqué dans une même collection, référence vers
/// un enregistrement absent. Levée pendant la validation en mémoire :
/// AUCUNE donnée locale n'a été touchée (pas même un point de
/// restauration : il n'est créé qu'après qu'on a décidé d'importer).
class SauvegardeInvalideException implements Exception {
  final String details;

  const SauvegardeInvalideException(this.details);

  @override
  String toString() => 'Sauvegarde refusée : $details';
}

/// L'import a échoué APRÈS le début des écritures Hive (un échec de
/// validation est signalé par les autres exceptions). [donneesRestaurees]
/// dit si le retour en arrière en mémoire (rollback par clichés des boxes)
/// a réussi : vrai → les données locales sont exactement celles d'avant
/// l'import. Faux → elles ne le sont probablement pas : le point de
/// restauration [cheminPointRestauration] doit être utilisé. Ce fichier
/// n'est JAMAIS supprimé, y compris par la rotation.
class RestaurationSauvegardeEchoueeException implements Exception {
  final bool donneesRestaurees;

  /// Chemin du point de restauration écrit AVANT la moindre écriture Hive.
  /// `null` seulement si sa création a elle-même échoué (aucune donnée
  /// n'avait alors été touchée).
  final String? cheminPointRestauration;

  final Object? cause;

  const RestaurationSauvegardeEchoueeException({
    required this.donneesRestaurees,
    this.cheminPointRestauration,
    this.cause,
  });

  @override
  String toString() {
    final etat = donneesRestaurees
        ? 'Les données locales sont INTACTES : état exact d\'avant import.'
        : "Le retour automatique à l'état d'avant import a ÉCHOUÉ : "
              'utilisez le point de restauration ci-dessous.';
    final chemin = cheminPointRestauration == null
        ? ''
        : ' Point de restauration : $cheminPointRestauration.';
    return "Restauration de sauvegarde échouée. $etat$chemin Cause : $cause";
  }
}

/// Résultat de la validation complète en mémoire d'un fichier de
/// sauvegarde ([BackupService._validerContenu]). Les modèles sont déjà
/// parsés : la restauration n'exécute donc aucun `depuisJson` après avoir
/// commencé à écrire. [collectionsPresents] recense les clés réellement
/// présentes dans le fichier : en mode remplacer, une collection ABSENTE
/// (clé nulle ou absente, ex: sauvegarde v1 sans dépenses) ne déclenche
/// JAMAIS l'élagage de sa box, seules les collections présentes le font.
class _SauvegardeValidee {
  final int version;
  final DateTime? exporteLe;
  final List<Produit> produits;
  final List<model.Transaction> transactions;
  final List<Dette> dettes;
  final List<PaiementDette> paiementsDette;
  final List<Depense> depenses;
  final List<Conditionnement> conditionnements;

  /// Noms des collections réellement présentes dans le fichier
  /// (produits, transactions, dettes, paiementsDette, depenses,
  /// conditionnements). produits/transactions/dettes sont toujours
  /// présents (validation obligatoire) ; les autres le sont selon le
  /// fichier — une v1 ne les mentionne pas.
  final Set<String> collectionsPresents;

  const _SauvegardeValidee({
    required this.version,
    required this.exporteLe,
    required this.produits,
    required this.transactions,
    required this.dettes,
    required this.paiementsDette,
    required this.depenses,
    required this.conditionnements,
    required this.collectionsPresents,
  });
}

/// Export/import de toutes les données locales (produits, ventes,
/// dettes) vers/depuis un unique fichier JSON. Sert de filet de sécurité
/// en cas de perte du téléphone : sans ça, tout l'historique du
/// commerçant disparaît avec l'appareil.
class BackupService {
  // Version 2 : ajout des conditionnements de vente (voir
  // lib/models/conditionnement.dart). Une sauvegarde v1 reste importable :
  // chaque produit sans conditionnement dans le fichier en reçoit
  // automatiquement un, unique, de quantité 1 (voir
  // ConditionnementService.migrerSiAbsent).
  static const int formatVersion = 2;
  static const String _cleDerniereSauvegarde = 'derniere_sauvegarde_le';

  /// Dossier (dans le répertoire documents de l'app) qui reçoit un point
  /// de restauration au format export avant TOUTE restauration : si le
  /// rollback en mémoire échoue, le commerçant réimporte ce fichier.
  static const String _dossierRestaurations = 'restaurations_auto';

  /// Rotation : nombre de points de restauration conservés. Le dernier
  /// créé n'est jamais supprimé, quel que soit le résultat de l'import.
  static const int _maxPointsRestauration = 3;

  /// Départage des noms de fichiers de point de restauration créés dans
  /// la même milliseconde (sécurise aussi l'ordre de tri de la rotation).
  static int _sequencePointRestauration = 0;

  final ConditionnementService _conditionnementService =
      ConditionnementService();

  /// Écrit un fichier JSON contenant toutes les boxes Hive et retourne
  /// son chemin. N'inclut jamais les paramètres de pays/devise : ce
  /// sont des réglages de l'appareil, pas des données à restaurer.
  Future<File> exporter() async {
    final donnees = _donneesExport();

    final dossier = await getApplicationDocumentsDirectory();
    final horodatage = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final fichier = File(
      '${dossier.path}/caisse_de_poche_sauvegarde_$horodatage.json',
    );
    await fichier.writeAsString(jsonEncode(donnees));

    // Seul l'export manuel met à jour le rappel « dernière sauvegarde » :
    // un point de restauration automatique est transparent pour lui.
    await HiveService.parametresBox.put(
      _cleDerniereSauvegarde,
      DateTime.now().toIso8601String(),
    );

    return fichier;
  }

  /// État courant des données, au format export. Utilisé par [exporter]
  /// et par les points de restauration — NE touche jamais à
  /// `derniere_sauvegarde_le`.
  Map<String, dynamic> _donneesExport() => {
    'formatVersion': formatVersion,
    'exporteLe': DateTime.now().toIso8601String(),
    'produits': HiveService.produitsBox.values
        .map((p) => p.versJson())
        .toList(),
    'transactions': HiveService.transactionsBox.values
        .map((t) => t.versJson())
        .toList(),
    'dettes': HiveService.dettesBox.values.map((d) => d.versJson()).toList(),
    'paiementsDette': HiveService.paiementsDetteBox.values
        .map((p) => p.versJson())
        .toList(),
    'depenses': HiveService.depensesBox.values
        .map((d) => d.versJson())
        .toList(),
    'conditionnements': HiveService.conditionnementsBox.values
        .map((c) => c.versJson())
        .toList(),
  };

  /// Ouvre la feuille de partage native (WhatsApp, Drive, e-mail...).
  Future<void> partager(File fichier) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(fichier.path)],
        text: 'Sauvegarde Caisse de Poche',
      ),
    );
  }

  DateTime? derniereSauvegardeLe() {
    final valeur =
        HiveService.parametresBox.get(_cleDerniereSauvegarde) as String?;
    return valeur == null ? null : DateTime.tryParse(valeur);
  }

  /// Vrai s'il n'y a jamais eu de sauvegarde ou si la dernière date de
  /// plus de 7 jours : sert au rappel discret dans l'app.
  bool sauvegardeRecommandee() {
    final derniere = derniereSauvegardeLe();
    if (derniere == null) return true;
    return DateTime.now().difference(derniere) > const Duration(days: 7);
  }

  /// Lit le fichier et retourne le JSON décodé. Sert de première barrière
  /// commune à l'analyse et à la restauration.
  Future<Map<String, dynamic>> _lireJson(File fichier) async {
    final Object decode;
    try {
      decode = jsonDecode(await fichier.readAsString());
    } on Object {
      throw const FormatException(
        "Ce fichier n'est pas une sauvegarde Caisse de Poche valide.",
      );
    }
    if (decode is! Map<String, dynamic>) {
      throw const FormatException(
        "Ce fichier n'est pas une sauvegarde Caisse de Poche valide.",
      );
    }
    return decode;
  }

  /// Validation complète du contenu, ENTIÈREMENT en mémoire : version de
  /// format, parsing de chaque enregistrement, identifiants. Aucune
  /// écriture (ni Hive ni disque) tant que tout n'est pas validé. C'est
  /// la même logique pour [analyserFichier] (aperçu) et [restaurer].
  Future<_SauvegardeValidee> _validerContenu(File fichier) async {
    final json = await _lireJson(fichier);

    // formatVersion : entier strict, 1 <= version <= formatVersion
    // courant. Une chaîne (« 2 »), un décimal (2.0) ou une valeur
    // absente signale un fichier non produit par l'app : refus explicite.
    final versionBrute = json['formatVersion'];
    if (versionBrute is! int) {
      throw const FormatException(
        "formatVersion absent ou invalide : ce fichier n'est pas une "
        'sauvegarde Caisse de Poche reconnue.',
      );
    }
    if (versionBrute < 1 || versionBrute > formatVersion) {
      throw VersionSauvegardeNonSupporteeException(
        versionFichier: versionBrute,
        versionMaxSupportee: formatVersion,
      );
    }

    final produitsBrut = _exigerListe(json, 'produits', obligatoire: true);
    final transactionsBrut = _exigerListe(
      json,
      'transactions',
      obligatoire: true,
    );
    final dettesBrut = _exigerListe(json, 'dettes', obligatoire: true);
    // Collections ajoutées après la v1 : absence acceptée (liste vide,
    // import d'une sauvegarde ancienne), liste corrompue refusée.
    final paiementsBrut = _exigerListe(json, 'paiementsDette');
    final depensesBrut = _exigerListe(json, 'depenses');
    final conditionnementsBrut = _exigerListe(json, 'conditionnements');

    final produits = _analyserListe<Produit>(
      produitsBrut,
      'produits',
      Produit.depuisJson,
    );
    final transactions = _analyserListe<model.Transaction>(
      transactionsBrut,
      'transactions',
      model.Transaction.depuisJson,
    );
    final dettes = _analyserListe<Dette>(
      dettesBrut,
      'dettes',
      Dette.depuisJson,
    );
    final paiementsDette = _analyserListe<PaiementDette>(
      paiementsBrut,
      'paiementsDette',
      PaiementDette.depuisJson,
    );
    final depenses = _analyserListe<Depense>(
      depensesBrut,
      'depenses',
      Depense.depuisJson,
    );
    final conditionnements = _analyserListe<Conditionnement>(
      conditionnementsBrut,
      'conditionnements',
      Conditionnement.depuisJson,
    );

    _verifierIdentifiants<Produit>(produits, 'produits', (p) => p.id);
    _verifierIdentifiants(transactions, 'transactions', (t) => t.id);
    _verifierIdentifiants(dettes, 'dettes', (d) => d.id);
    _verifierIdentifiants(paiementsDette, 'paiementsDette', (p) => p.id);
    _verifierIdentifiants(depenses, 'depenses', (d) => d.id);
    _verifierIdentifiants(conditionnements, 'conditionnements', (c) => c.id);

    final exporteLeBrut = json['exporteLe'] as String?;
    // Collections réellement présentes (clé non nulle) — même sémantique
    // que _exigerListe : clé nulle ou absente = collection absente. Une
    // v2 avec `depenses: []` *affirme* qu'il n'y a rien ; une v1 sans clé
    // `depenses` ne parle simplement pas des dépenses.
    final collectionsPresents = <String>{
      for (final cle in const [
        'produits',
        'transactions',
        'dettes',
        'paiementsDette',
        'depenses',
        'conditionnements',
      ])
        if (json[cle] != null) cle,
    };
    return _SauvegardeValidee(
      version: versionBrute,
      exporteLe: exporteLeBrut == null
          ? null
          : DateTime.tryParse(exporteLeBrut),
      produits: produits,
      transactions: transactions,
      dettes: dettes,
      paiementsDette: paiementsDette,
      depenses: depenses,
      conditionnements: conditionnements,
      collectionsPresents: collectionsPresents,
    );
  }

  /// Récupère une collection sous forme de liste. [obligatoire] : les
  /// trois collections d'origine (produits/transactions/dettes) doivent
  /// exister ; les collections ajoutées ensuite sont facultatives
  /// (absentes des sauvegardes v1).
  List _exigerListe(
    Map<String, dynamic> json,
    String cle, {
    bool obligatoire = false,
  }) {
    final valeur = json[cle];
    if (valeur == null) {
      if (obligatoire) {
        throw SauvegardeInvalideException(
          'La collection « $cle » est absente du fichier.',
        );
      }
      return const [];
    }
    if (valeur is! List) {
      throw SauvegardeInvalideException(
        'La collection « $cle » doit être une liste.',
      );
    }
    return valeur;
  }

  /// Parse chaque enregistrement. Toute erreur de parsing est convertie
  /// en [SauvegardeInvalideException] avec le lot et l'index fautifs :
  /// l'utilisateur sait quoi corriger, et rien n'a été écrit.
  List<T> _analyserListe<T>(
    List brut,
    String collection,
    T Function(Map<String, dynamic> json) depuisJson,
  ) {
    final resultats = <T>[];
    for (var i = 0; i < brut.length; i++) {
      final element = brut[i];
      if (element is! Map<String, dynamic>) {
        throw SauvegardeInvalideException(
          '$collection : l\'enregistrement $i n\'est pas un objet JSON.',
        );
      }
      try {
        resultats.add(depuisJson(element));
      } on Object catch (e) {
        throw SauvegardeInvalideException(
          '$collection : enregistrement $i corrompu ($e).',
        );
      }
    }
    return resultats;
  }

  /// Refuse les identifiants vides et les doublons dans une même
  /// collection : Hive les écraserait silencieusement (même clé = même
  /// case), ce qui détruirait sans avertir des enregistrements viables.
  void _verifierIdentifiants<T>(
    List<T> objets,
    String collection,
    String Function(T) idDe,
  ) {
    final vus = <String>{};
    for (final objet in objets) {
      final id = idDe(objet);
      if (id.isEmpty) {
        throw SauvegardeInvalideException(
          '$collection : identifiant vide (chaque enregistrement doit en '
          'avoir un).',
        );
      }
      if (!vus.add(id)) {
        throw SauvegardeInvalideException(
          '$collection : identifiant dupliqué « $id ».',
        );
      }
    }
  }

  /// Vérifie les références entre collections, toujours en mémoire :
  /// - [remplacer] = true : les données locales vont disparaître, toute
  ///   référence doit donc pointer vers un enregistrement du FICHIER —
  ///   une référence orpheline produirait une donnée cassée, on refuse ;
  /// - [remplacer] = false : les données locales restent, une référence
  ///   vers un enregistrement présent localement est donc acceptable.
  /// Les références vérifiées : conditionnement.produitId,
  /// paiement.detteId.
  void _verifierReferences(
    _SauvegardeValidee validee, {
    required bool remplacer,
  }) {
    final produitsConnus = <String>{
      for (final produit in validee.produits) produit.id,
    };
    final dettesConnues = <String>{
      for (final dette in validee.dettes) dette.id,
    };
    if (!remplacer) {
      // Fusion : le local subsiste, il peut satisfaire les références.
      produitsConnus.addAll(HiveService.produitsBox.keys.cast<String>());
      dettesConnues.addAll(HiveService.dettesBox.keys.cast<String>());
    }

    for (final conditionnement in validee.conditionnements) {
      if (!produitsConnus.contains(conditionnement.produitId)) {
        throw SauvegardeInvalideException(
          'conditionnements : le produit « ${conditionnement.produitId} » '
          'référencé n\'existe ni dans la sauvegarde'
          '${remplacer ? '' : ' ni dans les données locales'}.',
        );
      }
    }
    for (final paiement in validee.paiementsDette) {
      if (!dettesConnues.contains(paiement.detteId)) {
        throw SauvegardeInvalideException(
          'paiementsDette : la dette « ${paiement.detteId} » référencée '
          'n\'existe ni dans la sauvegarde'
          '${remplacer ? '' : ' ni dans les données locales'}.',
        );
      }
    }
  }

  /// Analyse le fichier pour l'aperçu de restauration : la validation est
  /// la même que pour [restaurer] (mission C4) — un fichier refusé là
  /// serait refusé plus bas, autant le dire avant la question
  /// « fusionner ou remplacer ».
  Future<ApercuSauvegarde> analyserFichier(File fichier) async {
    final validee = await _validerContenu(fichier);
    return ApercuSauvegarde(
      nombreProduits: validee.produits.length,
      nombreVentes: validee.transactions.length,
      nombreDettes: validee.dettes.length,
      exporteLe: validee.exporteLe,
    );
  }

  /// Restaure un fichier de sauvegarde et retourne le chemin du point de
  /// restauration créé (au format export, contenant l'état d'avant
  /// import). Déroulé exact (mission C4) :
  ///
  /// 1. validation COMPLÈTE en mémoire ([_validerContenu], puis
  ///    [_verifierReferences]) — si le contenu est refusé, aucune
  ///    écriture n'a eu lieu, la levée signale quoi corriger ;
  /// 2. point de restauration durable sur disque
  ///    ([_creerPointRestauration]) — jamais de modification de
  ///    `derniere_sauvegarde_le`, jamais de suppression du dernier point ;
  /// 3. photographie des six boxes en mémoire, base exacte du rollback ;
  /// 4. écritures par [Box.putAll] (upsert) :
  ///    en mode [remplacer], élagage ensuite des clés locales absentes du
  ///    fichier — UNIQUEMENT pour les collections réellement présentes
  ///    dans le fichier : une collection ABSENTE (clé absente ou nulle,
  ///    ex: sauvegarde v1 sans dépenses) ne déclenche JAMAIS d'élagage,
  ///    ses données locales survivent ; une collection PRÉSENTE mais
  ///    vide reste un élagage normal. UNE box n'est donc JAMAIS vidée
  ///    avant que les nouvelles données soient écrites ; en mode fusion,
  ///    aucune suppression ;
  /// 5. conditionnements par défaut pour les produits importés sans
  ///    conditionnement (fichiers v1, produits simples en v2) ;
  /// 6. sur échec : restauration des clichés (rollback), puis levée de
  ///    [RestaurationSauvegardeEchoueeException] avec le chemin du point
  ///    de restauration.
  ///
  /// [echecApresEtape] : UNIQUEMENT POUR LES TESTS — simule un échec après
  /// une étape nommée, pour vérifier le rollback. Étapes acceptées :
  /// `ecriture_produits`, `ecriture_transactions`, `ecriture_dettes`,
  /// `ecriture_paiements`, `ecriture_depenses`, `elagage`,
  /// `conditionnements_par_defaut`.
  ///
  /// Limite documentée : le rollback est EN MÉMOIRE. Une coupure de
  /// courant ou un kill du processus pendant l'import n'est pas couvert :
  /// le point de restauration de l'étape 2 est alors la seule planche de
  /// salut, sa reprise automatique relève de C5.
  Future<String> restaurer(
    File fichier, {
    required bool remplacer,
    @visibleForTesting String? echecApresEtape,
  }) async {
    // 1) Validation entièrement en mémoire : rien n'est écrit avant.
    final validee = await _validerContenu(fichier);
    _verifierReferences(validee, remplacer: remplacer);

    // 2) Point de restauration durable, avant la moindre écriture Hive.
    final String cheminPoint;
    try {
      cheminPoint = await _creerPointRestauration();
    } on Object catch (e) {
      // Aucune écriture Hive n'a eu lieu : les données sont intactes.
      throw RestaurationSauvegardeEchoueeException(
        donneesRestaurees: true,
        cause: e,
      );
    }

    // 3) Clichés des six boxes : référence exacte du rollback.
    final cliches = _photographierBoxes();

    try {
      // 4) Écritures en upsert (putAll) — une box jamais vidée avant
      //    d'avoir reçu les nouvelles données.
      await HiveService.produitsBox.putAll({
        for (final produit in validee.produits) produit.id: produit,
      });
      _pointInjectionApresEtape('ecriture_produits', echecApresEtape);

      await HiveService.transactionsBox.putAll({
        for (final transaction in validee.transactions)
          transaction.id: transaction,
      });
      _pointInjectionApresEtape('ecriture_transactions', echecApresEtape);

      await HiveService.dettesBox.putAll({
        for (final dette in validee.dettes) dette.id: dette,
      });
      _pointInjectionApresEtape('ecriture_dettes', echecApresEtape);

      await HiveService.paiementsDetteBox.putAll({
        for (final paiement in validee.paiementsDette) paiement.id: paiement,
      });
      _pointInjectionApresEtape('ecriture_paiements', echecApresEtape);

      await HiveService.depensesBox.putAll({
        for (final depense in validee.depenses) depense.id: depense,
      });
      _pointInjectionApresEtape('ecriture_depenses', echecApresEtape);

      await HiveService.conditionnementsBox.putAll({
        for (final conditionnement in validee.conditionnements)
          conditionnement.id: conditionnement,
      });
      _pointInjectionApresEtape('ecriture_conditionnements', echecApresEtape);

      // Élagage, en mode remplacer UNIQUEMENT : les enregistrements
      // locaux absents du fichier sont retirés maintenant que les
      // nouvelles données sont toutes écrites. En mode fusion : aucune
      // suppression.
      if (remplacer) {
        // produits/transactions/dettes sont obligatoirement présentes
        // dans le fichier (validées) : élagage systématique.
        await _elaguer(
          HiveService.produitsBox,
          validee.produits.map((p) => p.id).toSet(),
        );
        await _elaguer(
          HiveService.transactionsBox,
          validee.transactions.map((t) => t.id).toSet(),
        );
        await _elaguer(
          HiveService.dettesBox,
          validee.dettes.map((d) => d.id).toSet(),
        );
        // Collections facultatives : une collection ABSENTE du fichier
        // (clé absente ou nulle — ex: sauvegarde v1 sans dépenses) ne
        // déclenche JAMAIS d'élagage : les données locales de cette box
        // survivent à l'import, le fichier n'a rien affirmé à leur
        // sujet. Une collection PRÉSENTE mais vide (« [] ») reste un
        // élagage normal : le fichier affirme qu'il n'y en a aucune.
        if (validee.collectionsPresents.contains('paiementsDette')) {
          await _elaguer(
            HiveService.paiementsDetteBox,
            validee.paiementsDette.map((p) => p.id).toSet(),
          );
        }
        if (validee.collectionsPresents.contains('depenses')) {
          await _elaguer(
            HiveService.depensesBox,
            validee.depenses.map((d) => d.id).toSet(),
          );
        }
        if (validee.collectionsPresents.contains('conditionnements')) {
          await _elaguer(
            HiveService.conditionnementsBox,
            validee.conditionnements.map((c) => c.id).toSet(),
          );
        }
        _pointInjectionApresEtape('elagage', echecApresEtape);
      }

      // 5) Une sauvegarde antérieure au format v2 (ou un produit
      //    enregistré sans conditionnement) reçoit un conditionnement
      //    unique de quantité 1 au prix de vente importé — voir
      //    ConditionnementService.migrerSiAbsent (idempotent).
      for (final produit in validee.produits) {
        await _conditionnementService.migrerSiAbsent(produit);
      }
      _pointInjectionApresEtape('conditionnements_par_defaut', echecApresEtape);
    } on Object catch (e) {
      // 6) Rollback en mémoire : remettre les six boxes à l'état exact
      //    photographié en (3), avant la première écriture. En cas de
      //    doute ([retabli] = false), le point de restauration reste
      //    disponible sur disque, toujours.
      var retabli = true;
      try {
        await _retablirCliches(cliches);
      } on Object {
        retabli = false;
      }
      throw RestaurationSauvegardeEchoueeException(
        donneesRestaurees: retabli,
        cheminPointRestauration: cheminPoint,
        cause: e,
      );
    }

    return cheminPoint;
  }

  /// Crée, avant toute écriture Hive, un point de restauration durable :
  /// un fichier au format export dans `restaurations_auto/`, contenant
  /// l'état courant des données. Ne touche JAMAIS à
  /// `derniere_sauvegarde_le` (c'est le rappel de l'export manuel, pas
  /// d'un import). Rotation après écriture ([_faireRotationPoints]).
  Future<String> _creerPointRestauration() async {
    final dossier = await getApplicationDocumentsDirectory();
    final dossierPoints = Directory('${dossier.path}/$_dossierRestaurations');
    await dossierPoints.create(recursive: true);

    final horodatage = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final nomFichier =
        'avant_import_${horodatage}_${_sequencePointRestauration++}.json';
    final fichier = File('${dossierPoints.path}/$nomFichier');
    await fichier.writeAsString(jsonEncode(_donneesExport()));

    await _faireRotationPoints(dossierPoints, fichierAConserver: fichier.path);
    return fichier.path;
  }

  /// Rotation des points de restauration : seuls les
  /// [_maxPointsRestauration] plus récents subsistent (tri par nom — les
  /// horodatages y sont encodés). Le fichier [fichierAConserver] — le
  /// dernier créé — n'est JAMAIS supprimé. Un échec de suppression ne
  /// bloque jamais l'import : conserver un point de trop est sans danger.
  Future<void> _faireRotationPoints(
    Directory dossierPoints, {
    required String fichierAConserver,
  }) async {
    final points =
        dossierPoints
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .where((f) => f.uri.pathSegments.last.startsWith('avant_import_'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (var i = 0; i < points.length - _maxPointsRestauration; i++) {
      final point = points[i];
      if (point.path == fichierAConserver) continue; // jamais le dernier
      try {
        await point.delete();
      } on Object {
        // Ignoré volontairement : ne jamais faire échouer un import pour
        // la rotation, les points excédentaires resteront tolérés.
      }
    }
  }

  /// Supprime des clés présentes localement mais absentes de l'ensemble
  /// [clesFichier] (mode remplacer — uniquement APRÈS putAll). N'est
  /// appelée que pour les collections réellement présentes dans le
  /// fichier : une collection absente ne parle pas de ses données, la
  /// box locale reste intacte.
  Future<void> _elaguer(Box box, Set<String> clesFichier) async {
    for (final cle in box.keys.toList()) {
      if (!clesFichier.contains(cle)) {
        await box.delete(cle);
      }
    }
  }

  /// Clichés des six boxes concernées par l'import, pris avant la
  /// première écriture : la base complète du rollback en mémoire.
  Map<Box, Map<dynamic, dynamic>> _photographierBoxes() => {
    HiveService.produitsBox: HiveService.produitsBox.toMap(),
    HiveService.transactionsBox: HiveService.transactionsBox.toMap(),
    HiveService.dettesBox: HiveService.dettesBox.toMap(),
    HiveService.paiementsDetteBox: HiveService.paiementsDetteBox.toMap(),
    HiveService.depensesBox: HiveService.depensesBox.toMap(),
    HiveService.conditionnementsBox: HiveService.conditionnementsBox.toMap(),
  };

  /// Rollback en mémoire : pour chaque box, retire ce qui a été ajouté
  /// (clés absentes du cliché) puis réécrit l'état photographié. Si une
  /// écriture n'a jamais eu lieu, c'est un no-op sans danger.
  Future<void> _retablirCliches(Map<Box, Map<dynamic, dynamic>> cliches) async {
    for (final cliche in cliches.entries) {
      final box = cliche.key;
      final contenu = cliche.value;
      for (final cle in box.keys.toList()) {
        if (!contenu.containsKey(cle)) {
          await box.delete(cle);
        }
      }
      if (contenu.isNotEmpty) {
        await box.putAll(contenu);
      }
    }
  }

  /// Point d'injection réservé aux tests : simule un échec après l'étape
  /// [etape] si [echecApresEtape] porte ce nom.
  void _pointInjectionApresEtape(String etape, String? echecApresEtape) {
    if (echecApresEtape != null && echecApresEtape == etape) {
      throw StateError("Échec simulé par les tests après l'étape « $etape ».");
    }
  }
}
