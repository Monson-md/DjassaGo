import 'dart:convert';
import 'dart:io';

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

/// Export/import de toutes les données locales (produits, ventes,
/// dettes) vers/depuis un unique fichier JSON. Sert de filet de sécurité
/// en cas de perte du téléphone : sans ça, tout l'historique du
/// commerçant disparaît avec l'appareil.
class BackupService {
  // Version 2 : ajout des conditionnements de vente (voir
  // lib/models/conditionnement.dart). Une sauvegarde v1 reste importable :
  // chaque produit sans conditionnement dans le fichier en reçoit
  // automatiquement un, unique, de quantité 1 (voir _migrerConditionnementsAbsents).
  static const int formatVersion = 2;
  static const String _cleDerniereSauvegarde = 'derniere_sauvegarde_le';
  final ConditionnementService _conditionnementService = ConditionnementService();

  /// Écrit un fichier JSON contenant toutes les boxes Hive et retourne
  /// son chemin. N'inclut jamais les paramètres de pays/devise : ce
  /// sont des réglages de l'appareil, pas des données à restaurer.
  Future<File> exporter() async {
    final donnees = <String, dynamic>{
      'formatVersion': formatVersion,
      'exporteLe': DateTime.now().toIso8601String(),
      'produits':
          HiveService.produitsBox.values.map((p) => p.versJson()).toList(),
      'transactions': HiveService.transactionsBox.values
          .map((t) => t.versJson())
          .toList(),
      'dettes':
          HiveService.dettesBox.values.map((d) => d.versJson()).toList(),
      'paiementsDette': HiveService.paiementsDetteBox.values
          .map((p) => p.versJson())
          .toList(),
      'depenses':
          HiveService.depensesBox.values.map((d) => d.versJson()).toList(),
      'conditionnements': HiveService.conditionnementsBox.values
          .map((c) => c.versJson())
          .toList(),
    };

    final dossier = await getApplicationDocumentsDirectory();
    final horodatage =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final fichier =
        File('${dossier.path}/caisse_de_poche_sauvegarde_$horodatage.json');
    await fichier.writeAsString(jsonEncode(donnees));

    await HiveService.parametresBox
        .put(_cleDerniereSauvegarde, DateTime.now().toIso8601String());

    return fichier;
  }

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

  Future<Map<String, dynamic>> _lireEtValider(File fichier) async {
    final Map<String, dynamic> json;
    try {
      final contenu = await fichier.readAsString();
      json = jsonDecode(contenu) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
          "Ce fichier n'est pas une sauvegarde Caisse de Poche valide.");
    }
    if (json['formatVersion'] == null ||
        json['produits'] is! List ||
        json['transactions'] is! List ||
        json['dettes'] is! List) {
      throw const FormatException(
          "Ce fichier n'est pas une sauvegarde Caisse de Poche valide.");
    }
    return json;
  }

  Future<ApercuSauvegarde> analyserFichier(File fichier) async {
    final json = await _lireEtValider(fichier);
    final exporteLeBrut = json['exporteLe'] as String?;
    return ApercuSauvegarde(
      nombreProduits: (json['produits'] as List).length,
      nombreVentes: (json['transactions'] as List).length,
      nombreDettes: (json['dettes'] as List).length,
      exporteLe: exporteLeBrut == null ? null : DateTime.tryParse(exporteLeBrut),
    );
  }

  /// Restaure un fichier de sauvegarde. En mode [remplacer], les boxes
  /// produits/ventes/dettes sont d'abord vidées. En mode fusion, chaque
  /// enregistrement est ré-inséré par son id (Hive.put est un upsert) :
  /// les enregistrements locaux absents de la sauvegarde sont conservés,
  /// ceux qui partagent un même id sont écrasés par la version importée.
  Future<void> restaurer(File fichier, {required bool remplacer}) async {
    final json = await _lireEtValider(fichier);

    if (remplacer) {
      await HiveService.produitsBox.clear();
      await HiveService.transactionsBox.clear();
      await HiveService.dettesBox.clear();
      await HiveService.paiementsDetteBox.clear();
      await HiveService.depensesBox.clear();
      await HiveService.conditionnementsBox.clear();
    }

    final produitsImportes = <Produit>[];
    for (final p in json['produits'] as List) {
      final produit = Produit.depuisJson(p as Map<String, dynamic>);
      await HiveService.produitsBox.put(produit.id, produit);
      produitsImportes.add(produit);
    }
    for (final t in json['transactions'] as List) {
      final transaction =
          model.Transaction.depuisJson(t as Map<String, dynamic>);
      await HiveService.transactionsBox.put(transaction.id, transaction);
    }
    for (final d in json['dettes'] as List) {
      final dette = Dette.depuisJson(d as Map<String, dynamic>);
      await HiveService.dettesBox.put(dette.id, dette);
    }
    // Absent des sauvegardes antérieures à la Phase 3 : traité comme une
    // liste vide plutôt que de rejeter le fichier (voir _lireEtValider).
    for (final p in (json['paiementsDette'] as List? ?? const [])) {
      final paiement = PaiementDette.depuisJson(p as Map<String, dynamic>);
      await HiveService.paiementsDetteBox.put(paiement.id, paiement);
    }
    // Absent des sauvegardes antérieures à la Phase 7.
    for (final d in (json['depenses'] as List? ?? const [])) {
      final depense = Depense.depuisJson(d as Map<String, dynamic>);
      await HiveService.depensesBox.put(depense.id, depense);
    }
    // Absent des sauvegardes antérieures au format v2 (voir [formatVersion]).
    final produitsAvecConditionnement = <String>{};
    for (final c in (json['conditionnements'] as List? ?? const [])) {
      final conditionnement =
          Conditionnement.depuisJson(c as Map<String, dynamic>);
      await HiveService.conditionnementsBox
          .put(conditionnement.id, conditionnement);
      produitsAvecConditionnement.add(conditionnement.produitId);
    }
    // Une sauvegarde antérieure au format v2, ou un produit qui n'avait
    // lui-même aucun conditionnement au moment de l'export, reçoit ici un
    // conditionnement unique de quantité 1 au prix de vente importé — voir
    // ConditionnementService.migrerSiAbsent.
    for (final produit in produitsImportes) {
      if (!produitsAvecConditionnement.contains(produit.id)) {
        await _conditionnementService.migrerSiAbsent(produit);
      }
    }
  }
}
