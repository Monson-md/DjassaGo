/// Versionnement et migration du schéma Hive.
///
/// Ce fichier contient tout ce qui concerne les migrations de schéma Hive
/// sécurisées par la mission C3 :
///
/// - [HiveMigration] : une étape de migration explicite (v1→v2 ...),
/// - [migrationsHive] : le registre ordonné des migrations enregistrées,
/// - le journal de migration (écrit dans `parametres_box`) qui rend
///   chaque migration récupérable après un arrêt brutal de l'application,
/// - [SauvegardeBruteHive] : copie brute des fichiers `.hive` avant toute
///   migration, avec manifeste, et restauration de cette copie,
/// - les exceptions explicites signalées à l'écran de diagnostic.
///
/// Règle absolue (mission C3) : AUCUNE fonction de ce fichier n'efface de
/// données métier. La sauvegarde brute n'est jamais supprimée ; les
/// exceptions n'autorisent jamais la poursuite avec une base partielle
/// ou vide.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Une migration de schéma Hive, du schéma [versionDe] vers [versionVers].
///
/// Règles pour toute migration future :
/// - [versionDe] doit être la version stockée par les utilisateurs à
///   migrer, [versionVers] la version du code qui l'introduit ;
/// - `executer` doit être idempotente (relancée après une restauration,
///   elle doit produire le même résultat) et ne doit JAMAIS supprimer
///   d'enregistrement : les données non convertibles sont conservées
///   telles quelles, réécrites ou signalées, pas effacées ;
/// - la nouvelle `schemaVersion` n'est écrite qu'après la validation
///   complète de toutes les étapes (voir HiveService.initialiser).
class HiveMigration {
  final int versionDe;
  final int versionVers;

  /// Nom explicite de l'étape, inscrit au journal (`etapes`) après
  /// sa réussite, pour le diagnostic.
  final String nom;

  final Future<void> Function() executer;

  const HiveMigration({
    required this.versionDe,
    required this.versionVers,
    required this.nom,
    required this.executer,
  });
}

/// Registre ordonné des migrations de schéma.
///
/// VOLONTAIREMENT VIDE : l'audit C3 a montré que chaque changement de
/// modèle jusqu'ici (champs en unités mineures, margeBrute, deviceId,
/// conditionnements) est rétrocompatible (champs ajoutés avec
/// `defaultValue`), donc aucune migration 1→2 n'existe. Toute future
/// migration doit être déclarée ICI, explicitement, avant tout
/// incrément de `HiveService.schemaVersion` — sinon le démarrage est
/// refusé avec [MigrationHiveManquanteException] plutôt que de détruire
/// les données (règle qui remplace l'ancienne routine d'effacement).
const List<HiveMigration> migrationsHive = [];

/// Clés de la map-journal stockée dans `parametres_box` sous la clé
/// `migration_hive_en_cours` (ParametresKeys.migrationHiveEnCours) pendant
/// toute la durée d'une migration.
class ChampsJournalMigration {
  ChampsJournalMigration._();

  /// État d'avancement : [EtatJournalMigration.preparation] puis
  /// [EtatJournalMigration.sauvegardeCreee].
  static const String etat = 'etat';
  static const String de = 'de';
  static const String vers = 'vers';

  /// Nom du dossier de sauvegarde brute associé, pour que le démarrage
  /// suivant puisse restaurer les fichiers correspondants.
  static const String dossier = 'dossier';
  static const String debut = 'debut';

  /// Noms des étapes de migration déjà terminées avec succès.
  static const String etapes = 'etapes';
}

/// Valeurs de [ChampsJournalMigration.etat].
class EtatJournalMigration {
  EtatJournalMigration._();

  /// Le journal est créé mais la sauvegarde brute n'existe pas encore :
  /// rien n'a été touché, la reprise peut passer à la suite sans
  /// restauration.
  static const String preparation = 'preparation';

  /// La sauvegarde brute existe (copie complète des fichiers `.hive`) :
  /// toute relance après interruption restaure cette copie avant
  /// d'ouvrir les boxes métier.
  static const String sauvegardeCreee = 'sauvegarde_creee';
}

/// Dossier (dans le répertoire documents de l'application) qui reçoit les
/// sauvegardes brutes de migration. Sauvegarde BRUTE (fichiers `.hive`
/// copiés tels quels) et non export JSON : les copies restent
/// restaurables même si les adaptateurs Hive changent entre-temps.
const String dossierSauvegardesMigration = 'migrations_hive';

/// Manifeste écrit dans chaque dossier de sauvegarde : version source,
/// version cible, date, fichiers copiés, tailles et empreintes SHA-256.
const String nomFichierManifeste = 'manifeste.json';

/// Le schéma stocké sur disque est PLUS RÉCENT que celui du code (ex:
/// rétrogradation d'APK, bascule de variante). Le démarrage est refusé :
/// les adaptateurs actuels pourraient lire des champs disparus mais
/// surtout le code pourrait réécrire les données dans un format que la
/// version plus récente ne reconnaîtrait plus. Aucune donnée modifiée.
class SchemaHivePlusRecentException implements Exception {
  final int versionStockee;
  final int versionCode;

  const SchemaHivePlusRecentException({
    required this.versionStockee,
    required this.versionCode,
  });

  @override
  String toString() =>
      'Démarrage refusé : le schéma Hive des données locales ($versionStockee) '
      'est PLUS RÉCENT que celui de cette version de l\'application '
      '($versionCode), probablement suite à l\'installation d\'un APK plus '
      'ancien. Aucune donnée n\'a été modifiée ni effacée. Il faut réinstaller '
      'une version de l\'application au moins aussi récente que celle qui a '
      'créé ces données.';
}

/// La version du code est plus récente que les données mais AUCUNE
/// migration n'a été enregistrée pour enchaîner jusqu'à elle. Le
/// démarrage est refusé : c'est le filet qui remplace l'ancien
/// effacement automatique des boxes. Données intactes.
class MigrationHiveManquanteException implements Exception {
  /// Version (stockée) depuis laquelle il manque un migrateur.
  final int versionManquante;
  final int versionCible;

  const MigrationHiveManquanteException({
    required this.versionManquante,
    required this.versionCible,
  });

  @override
  String toString() =>
      'Démarrage refusé : aucune migration enregistrée depuis le schéma Hive '
      '$versionManquante vers $versionCible. Aucune donnée n\'a été modifiée. '
      'Il faut corriger le code : enregistrer la migration manquante dans '
      'migrationsHive (lib/services/hive_migrations.dart) ou ne pas '
      'incrémenter schemaVersion.';
}

/// La migration (ou sa récupération) a échoué en cours d'exécution.
/// [restaurationReussie] indique si les données ont pu être remises à
/// l'état d'avant migration via la sauvegarde brute.
class MigrationHiveEchoueeException implements Exception {
  /// Où l'échec s'est produit (ex: 'sauvegarde', 'execution',
  /// 'recuperation_demarrage').
  final String phase;
  final bool restaurationReussie;
  final String? dossierSauvegarde;
  final Object? cause;

  const MigrationHiveEchoueeException({
    required this.phase,
    required this.restaurationReussie,
    this.dossierSauvegarde,
    this.cause,
  });

  @override
  String toString() {
    final etatDonnees = restaurationReussie
        ? 'Les données locales sont INTACTES : c\'est l\'état exact d\'avant '
              'migration.'
        : 'La restauration automatique a ÉCHOUÉ : les données ne sont '
              'probablement pas dans leur état d\'avant migration, la '
              'sauvegarde existe toujours et ne doit en aucun cas être '
              'supprimée.';
    final dossier = dossierSauvegarde == null
        ? ''
        : ' Dossier de sauvegarde : migrations_hive/$dossierSauvegarde.';
    return 'Migration du schéma Hive échouée (phase : $phase). '
        '$etatDonnees$dossier Cause : $cause';
  }
}

/// Une migration précédente a été interrompue (arrêt brutal de
/// l'application, coupure de courant...) : détectée au démarrage suivant
/// via le journal `migration_hive_en_cours`. La restauration a déjà été
/// appliquée (ou n'était pas nécessaire) ; le démarrage s'arrête pour
/// laisser un signal explicite ; la migration pourra être relancée au
/// démarrage suivant, sur les données restituées.
class MigrationHiveInterrompueException implements Exception {
  /// Vrai si une restauration de sauvegarde brute a été appliquée à ce
  /// démarrage ; faux si la migration s'était arrêtée avant d'avoir
  /// touché quoi que ce soit.
  final bool restaurationEffectuee;

  /// Dossier de sauvegarde restitué, s'il y a lieu.
  final String? dossierSauvegarde;

  /// Complément explicatif optionnel (case particulière).
  final String? details;

  const MigrationHiveInterrompueException({
    required this.restaurationEffectuee,
    this.dossierSauvegarde,
    this.details,
  });

  @override
  String toString() {
    final etatDonnees = restaurationEffectuee
        ? 'Les données locales ont été restaurées exactement depuis la '
              'sauvegarde brute : rien n\'a été perdu ni modifié.'
        : 'La migration s\'était arrêtée AVANT de toucher aux données : '
              'aucune donnée modifiée, aucune restauration nécessaire.';
    final dossier = dossierSauvegarde == null
        ? ''
        : ' Sauvegarde : migrations_hive/$dossierSauvegarde.';
    final complement = details == null ? '' : ' $details';
    return 'Migration du schéma Hive interrompue puis récupérée au '
        'démarrage. $etatDonnees$dossier$complement La migration pourra '
        'être retentée au prochain démarrage de l\'application.';
  }
}

/// Copie brute (fichiers `.hive` copiés tels quels) de TOUTE la base Hive
/// de l'application, avant toute migration de schéma, et restauration de
/// cette copie.
///
/// Contraintes Hive respectées :
/// - un fichier `.hive` ouvert/mis à jour n'est JAMAIS copié : on
///   `flush()` chaque box, puis `Hive.close()` ferme toutes les boxes et
///   tous leurs descripteurs (et supprime les fichiers `.lock`) AVANT la
///   copie ; les boxes sont rouvertes ensuite via le callback
///   [rouvrirBoxes] fourni par HiveService (pour le découplage des
///   imports) ;
/// - la sauvegarde couvre TOUS les fichiers `.hive` présents (pas une
///   liste figée de boxes) : toute box présente ou future est couverte,
///   aucune donnée peut rester hors sauvegarde ;
/// - la copie brute reste restaurable même si les adaptateurs changent,
///   contrairement à un export JSON ;
/// - chaque fichier copié est accompagné, dans le manifeste, de sa taille
///   et de son empreinte SHA-256 : une restauration est REFUSÉE d'office
///   si une sauvegarde est incomplète (fichier/manifeste manquant), les
///   données existantes n'étant jamais touchées dans ce cas ; chaque
///   fichier restauré est revérifié APRÈS la copie ;
/// - jamais la sauvegarde elle-même n'est supprimée ici.
class SauvegardeBruteHive {
  SauvegardeBruteHive._();

  static Future<String> _cheminDocuments() async =>
      (await getApplicationDocumentsDirectory()).path;

  /// Normalise un nom de dossier (venant du journal) pour ne jamais
  /// sortir du répertoire de sauvegarde, quel que soit le système.
  static String _normaliserNomDossier(String nom) =>
      nom.replaceAll(RegExp(r'[^0-9A-Za-z_.-]'), '-');

  /// Crée la sauvegarde brute dans
  /// `<documents>/migrations_hive/<nomDossier>/`.
  ///
  /// [boxesOuvertes] : les boxes actuellement ouvertes, flushées avant
  /// fermeture pour garantir que chaque fichier `.hive` reflète tout le
  /// contenu en mémoire. En pratique HiveService n'a que `parametres_box`
  /// ouverte au moment de la création du journal.
  ///
  /// [rouvrirBoxes] : rouvre toutes les boxes (paramètres + données
  /// métier) après la copie ; aussi appelé en cas d'échec pour ne jamais
  /// laisser l'application sans boxes ouvertes.
  ///
  /// Lève une exception et ne touche à rien d'autre si la copie échoue :
  /// dans ce cas aucune donnée métier n'a été modifiée (la sauvegarde est
  /// la toute première étape de la migration) et le démarrage suivant
  /// pourra tout retenter.
  static Future<void> creer({
    required int versionDe,
    required int versionVers,
    required String nomDossier,
    required Map<String, BoxBase> boxesOuvertes,
    required Future<void> Function() rouvrirBoxes,
  }) async {
    final documents = await _cheminDocuments();
    final dossier = Directory(
      '$documents/$dossierSauvegardesMigration/'
      '${_normaliserNomDossier(nomDossier)}',
    );
    try {
      // 1) Flush de chaque box ouverte : le contenu mémoire est écrit
      //    dans le fichier avant toute fermeture.
      for (final box in boxesOuvertes.values) {
        await box.flush();
      }
      // 2) Fermeture contrôlée de TOUTES les boxes (et suppression des
      //    fichiers `.lock`) : aucun fichier copié ne peut être modifié
      //    pendant la copie.
      await Hive.close();
      // 3) Copie brute de chaque fichier `.hive` présent, avec taille
      //    et empreinte SHA-256 relevées au moment de la copie.
      await dossier.create(recursive: true);
      final fichiers = <Map<String, dynamic>>[];
      await for (final entite in Directory(documents).list()) {
        if (entite is! File || !entite.path.endsWith('.hive')) continue;
        final nom = entite.uri.pathSegments.last;
        final contenu = await entite.readAsBytes();
        await File('${dossier.path}/$nom').writeAsBytes(contenu, flush: true);
        fichiers.add({
          'nom': nom,
          'taille': contenu.length,
          'sha256': sha256.convert(contenu).toString(),
        });
      }
      // 4) Auto-vérification : chaque copie doit avoir la taille annoncée
      //    (disque plein, fichier tronqué...). Si une copie est déjà
      //    incomplète, la migration ne doit pas continuer avec cette
      //    sauvegarde.
      for (final f in fichiers) {
        final copie = File('${dossier.path}/${f['nom'] as String}');
        if (copie.lengthSync() != (f['taille'] as int)) {
          throw Exception(
            'Copie de sauvegarde tronquée : ${f['nom']} '
            '(attendu ${f['taille']} octets).',
          );
        }
      }
      // 5) Manifeste : versions, date, fichiers copiés + tailles +
      //    empreintes.
      final manifeste = const JsonEncoder.withIndent('  ').convert({
        'versionSource': versionDe,
        'versionCible': versionVers,
        'date': DateTime.now().toIso8601String(),
        'fichiers': fichiers,
      });
      await File(
        '${dossier.path}/$nomFichierManifeste',
      ).writeAsString(manifeste);
    } catch (e) {
      // Échec de la sauvegarde : les données sont inchangées (premier
      // geste de la migration), il ne reste qu'à garantir des boxes
      // rouvertes puis laisser l'erreur remonter.
      try {
        await rouvrirBoxes();
      } catch (_) {
        // rouvrirBoxes a déjà été appelé sur des boxes fermées ; s'il
        // n'a pas lui-même pu rouvrir, l'application est dans un état de
        // toute façon signalé comme en échec (prochaine initialisation
        // retentera openBox, opération tolerante aux boxes déjà ouvertes).
      }
      rethrow;
    }
    // 6) Réouverture des boxes : le code appelant continue avec des
    //    boxes valides (nouvelles instances).
    await rouvrirBoxes();
  }

  /// Lit et valide une sauvegarde AVANT tout effet de bord :
  /// - manifeste présent et JSON lisible ;
  /// - chaque fichier annoncé présent dans le dossier de sauvegarde ;
  /// - taille conforme, empreinte SHA-256 conforme quand elle est
  ///   déclarée.
  ///
  /// Toute anomaly lève [MigrationHiveEchoueeException] avec
  /// `restaurationReussie: false` : la sauvegarde est incomplète ou
  /// corrompue, elle ne doit JAMAIS être utilisée pour remplacer les
  /// données existantes ; rien n'a été touché à ce stade (Hive pas encore
  /// fermé, fichiers vivants intacts).
  static List<Map<String, dynamic>> _validerSauvegarde(Directory dossier) {
    final fichierManifeste = File('${dossier.path}/$nomFichierManifeste');
    if (!fichierManifeste.existsSync()) {
      throw MigrationHiveEchoueeException(
        phase: 'validation_sauvegarde',
        restaurationReussie: false,
        cause:
            'Manifeste ABSENT du dossier de sauvegarde (sauvegarde '
            'incomplète, jamais restaurable) : ${dossier.path}.',
      );
    }
    Map<String, dynamic> manifeste;
    try {
      final decode = jsonDecode(fichierManifeste.readAsStringSync());
      if (decode is! Map) {
        throw const FormatException(
          'Le manifeste ne contient pas un objet JSON.',
        );
      }
      manifeste = Map<String, dynamic>.from(decode);
    } on Object catch (e) {
      throw MigrationHiveEchoueeException(
        phase: 'validation_sauvegarde',
        restaurationReussie: false,
        cause: 'Manifeste illisible (JSON corrompu) dans ${dossier.path} : $e',
      );
    }
    final fichiers = manifeste['fichiers'];
    if (fichiers is! List || fichiers.isEmpty) {
      throw MigrationHiveEchoueeException(
        phase: 'validation_sauvegarde',
        restaurationReussie: false,
        cause:
            'Manifeste sans aucun fichier déclaré (sauvegarde incomplète) : '
            '${dossier.path}.',
      );
    }
    final entrees = <Map<String, dynamic>>[];
    for (final brut in fichiers) {
      if (brut is! Map) {
        throw MigrationHiveEchoueeException(
          phase: 'validation_sauvegarde',
          restaurationReussie: false,
          cause: 'Entrée de manifeste invalide dans ${dossier.path}.',
        );
      }
      final entree = Map<String, dynamic>.from(brut);
      final nom = entree['nom'] as String?;
      if (nom == null ||
          nom.isEmpty ||
          nom.contains('/') ||
          nom.contains(r'\') ||
          nom.contains('..')) {
        throw MigrationHiveEchoueeException(
          phase: 'validation_sauvegarde',
          restaurationReussie: false,
          cause:
              'Nom de fichier non sûr dans le manifeste de ${dossier.path} : '
              '$nom.',
        );
      }
      final fichier = File('${dossier.path}/$nom');
      if (!fichier.existsSync()) {
        throw MigrationHiveEchoueeException(
          phase: 'validation_sauvegarde',
          restaurationReussie: false,
          cause:
              'Fichier "$nom" annoncé par le manifeste mais ABSENT du dossier '
              'de sauvegarde (sauvegarde incomplète) : ${dossier.path}.',
        );
      }
      final taille = entree['taille'] as int?;
      final tailleReelle = fichier.lengthSync();
      if (taille == null || tailleReelle != taille) {
        throw MigrationHiveEchoueeException(
          phase: 'validation_sauvegarde',
          restaurationReussie: false,
          cause:
              'Fichier "$nom" tronqué ou modifié : $tailleReelle octets sur '
              'disque contre $taille annoncés dans le manifeste.',
        );
      }
      final empreinte = entree['sha256'] as String?;
      if (empreinte != null && empreinte.isNotEmpty) {
        final empreinteReelle = sha256
            .convert(fichier.readAsBytesSync())
            .toString();
        if (empreinteReelle != empreinte) {
          throw MigrationHiveEchoueeException(
            phase: 'validation_sauvegarde',
            restaurationReussie: false,
            cause:
                'Fichier "$nom" CORROMPU : empreinte SHA-256 différente de '
                'celle du manifeste (données impropres à la restauration).',
          );
        }
      }
      entrees.add(entree);
    }
    return entrees;
  }

  /// Vérifie APRÈS la copie que chaque fichier restauré est bien celui de
  /// la sauvegarde (taille puis empreinte) : détecte une copie interrompue
  /// ou un disque défaillant au lieu de laisser un état perdu au silence.
  static void _verifierApresRestauration(
    String documents,
    List<Map<String, dynamic>> entrees,
  ) {
    for (final entree in entrees) {
      final nom = entree['nom'] as String;
      final cible = File('$documents/$nom');
      if (!cible.existsSync() ||
          cible.lengthSync() != (entree['taille'] as int)) {
        throw Exception(
          'Fichier "$nom" invalide après restauration (absent ou tronqué) : '
          'la restauration n\'a pas été complète.',
        );
      }
      final empreinte = entree['sha256'] as String?;
      if (empreinte != null && empreinte.isNotEmpty) {
        final empreinteReelle = sha256
            .convert(cible.readAsBytesSync())
            .toString();
        if (empreinteReelle != empreinte) {
          throw Exception(
            'Fichier "$nom" corrompu après restauration (empreinte '
            'SHA-256 différente de la sauvegarde).',
          );
        }
      }
    }
  }

  /// Restaure la sauvegarde brute
  /// `<documents>/migrations_hive/<nomDossier>/` : remplace chaque
  /// fichier `.hive` par celui de la sauvegarde, supprime les fichiers
  /// `.hive` apparus depuis (boxes créées après la sauvegarde — donc
  /// vides au moment de la sauvegarde).
  ///
  /// REFUSE préalablement toute sauvegarde incomplète ou corrompue
  /// (manifeste absent/illisible, fichier annoncé manquant, taille ou
  /// empreinte SHA-256 non conformes) SANS toucher aux données
  /// existantes : la validation a lieu avant la fermeture de Hive, avant
  /// la moindre modification de fichier.
  ///
  /// Vérifie chaque fichier restauré APRÈS la copie : une restauration
  /// interrompue ou corrompue est signalée explicitement au lieu d'être
  /// poursuivie en silence.
  ///
  /// Ne supprime JAMAIS le dossier de sauvegarde : une restauration
  /// réussie peut être suivie d'autres tentatives de la même migration.
  static Future<void> restaurer({
    required String nomDossier,
    required Future<void> Function() rouvrirBoxes,
  }) async {
    final documents = await _cheminDocuments();
    final dossier = Directory(
      '$documents/$dossierSauvegardesMigration/'
      '${_normaliserNomDossier(nomDossier)}',
    );
    if (!dossier.existsSync()) {
      // Échec avant tout effet de bord : Hive n'est pas encore fermé,
      // les fichiers n'ont pas bougé. Le journal et la possibilité de
      // réparer restent en place.
      throw MigrationHiveEchoueeException(
        phase: 'restauration',
        restaurationReussie: false,
        dossierSauvegarde: nomDossier,
        cause: 'Dossier de sauvegarde introuvable : ${dossier.path}',
      );
    }
    // Validation complète AVANT tout effet de bord : données existantes
    // jamais touchées si la sauvegarde est incomplète ou corrompue.
    final entrees = _validerSauvegarde(dossier);
    try {
      // Fermeture contrôlée avant de toucher aux fichiers.
      await Hive.close();
      final nomsSauvegardes = <String>{};
      for (final entree in entrees) {
        final nom = entree['nom'] as String;
        nomsSauvegardes.add(nom);
        await File('${dossier.path}/$nom').copy('$documents/$nom');
      }
      await for (final entite in Directory(documents).list()) {
        if (entite is! File || !entite.path.endsWith('.hive')) continue;
        if (!nomsSauvegardes.contains(entite.uri.pathSegments.last)) {
          // Fichier de box absent de la sauvegarde : box créée depuis la
          // sauvegarde (donc vide à ce moment-là). File.delete() direct,
          // jamais l'ancienne routine d'effacement de box de Hive.
          await entite.delete();
        }
      }
      // Chaque fichier restauré doit être exactement celui de la
      // sauvegarde : une copie interrompue est signalée, jamais tolérée.
      _verifierApresRestauration(documents, entrees);
      // Le dossier de sauvegarde lui-même est volontairement conservé.
    } on MigrationHiveEchoueeException {
      try {
        await rouvrirBoxes();
      } catch (_) {
        // cf. creer : état signalé comme en échec de toute façon.
      }
      rethrow;
    } on Object catch (e) {
      try {
        await rouvrirBoxes();
      } catch (_) {
        // cf. creer : état signalé comme en échec de toute façon.
      }
      throw MigrationHiveEchoueeException(
        phase: 'restauration_fichiers',
        restaurationReussie: false,
        dossierSauvegarde: nomDossier,
        cause: e,
      );
    }
    await rouvrirBoxes();
  }
}
