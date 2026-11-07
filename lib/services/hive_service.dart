import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/hive_boxes.dart';
import '../models/categorie_depense.dart';
import '../models/conditionnement.dart';
import '../models/conflit_synchronisation.dart';
import '../models/depense.dart';
import '../models/devise.dart';
import '../models/dette.dart';
import '../models/item_vendu.dart';
import '../models/mode_paiement.dart';
import '../models/paiement_dette.dart';
import '../models/produit.dart';
import '../models/transaction.dart' as model;
import 'hive_migrations.dart';

/// Centralise l'initialisation de Hive : enregistrement des adapters
/// et ouverture des boxes typées. Doit être appelé une seule fois,
/// avant runApp(), dans main.dart.
///
/// ## Versionnement du schéma (mission C3)
///
/// [schemaVersion] est comparé à la valeur stockée à chaque démarrage :
/// - identique → ouverture normale ;
/// - absente → installation neuve ou base pré-version : adopter la
///   version courante SANS supprimer aucune donnée ;
/// - inférieure → exécuter les migrations enregistrées
///   ([migrationsHive], voir hive_migrations.dart), après une sauvegarde
///   brute des fichiers `.hive` et une écriture au journal de migration
///   qui rend toute interruption récupérable au démarrage suivant ;
/// - supérieure → REFUS du démarrage avec [SchemaHivePlusRecentException],
///   données intactes (rétrogradation d'APK).
///
/// Il n'existe plus AUCUN effacement de boxes déclenché par une
/// différence de version : la routine destructive (présente avant la
/// mission C3) qui écrasait produits/transactions/dettes/devises lors
/// d'un changement de version a été remplacée par ce mécanisme de
/// migration récupérable.
class HiveService {
  HiveService._();

  static bool _initialise = false;

  /// Incrémenter cette valeur à chaque changement incompatible du schéma
  /// Hive (ex: un champ qui change de type), en enregistrant AVANT la
  /// migration correspondante et explicite dans [migrationsHive] —
  /// sinon le démarrage est refusé ([MigrationHiveManquanteException])
  /// au lieu d'effacer les données, comme l'ancien code le faisait.
  /// Voir ParametresKeys.schemaVersion et hive_migrations.dart.
  static const int schemaVersion = 1;

  static Future<void> init() => initialiser();

  /// Logique d'initialisation complète, avec points d'injection pour les
  /// tests (une version cible ou un registre de migrations de test sans
  /// toucher aux constantes de production).
  @visibleForTesting
  static Future<void> initialiser({
    List<HiveMigration>? migrations,
    int? versionCible,
  }) async {
    if (_initialise) return;

    await Hive.initFlutter();

    _registerAdapterSiAbsent(0, DeviseAdapter());
    _registerAdapterSiAbsent(1, ProduitAdapter());
    _registerAdapterSiAbsent(2, ItemVenduAdapter());
    _registerAdapterSiAbsent(3, model.TransactionAdapter());
    _registerAdapterSiAbsent(4, StatutDetteAdapter());
    _registerAdapterSiAbsent(5, DetteAdapter());
    _registerAdapterSiAbsent(6, ModePaiementAdapter());
    _registerAdapterSiAbsent(7, PaiementDetteAdapter());
    _registerAdapterSiAbsent(8, CategorieDepenseAdapter());
    _registerAdapterSiAbsent(9, DepenseAdapter());
    _registerAdapterSiAbsent(10, ConflitSynchronisationAdapter());
    _registerAdapterSiAbsent(11, ConditionnementAdapter());

    // La box de paramètres est ouverte en premier et seule : elle stocke
    // des types primitifs (bool/String/int/Map plate), jamais d'objets
    // Hive personnalisés, donc son ouverture ne peut pas échouer à cause
    // d'un schéma incompatible sur Produit/Transaction/Dette/Devise.
    await Hive.openBox(HiveBoxes.parametres);

    // Récupération d'une éventuelle migration interrompue, AVANT
    // d'ouvrir les boxes métier ni de changer la moindre version : en
    // cas d'interruption, la sauvegarde brute est restaurée (ou
    // identifiée comme non nécessaire) et le démarrage s'arrête avec un
    // signal explicite — jamais de poursuite avec une base partielle.
    await _recupererMigrationInterrompue();
    final parametresBox = Hive.box(HiveBoxes.parametres);

    final versionStockee =
        parametresBox.get(ParametresKeys.schemaVersion) as int?;
    final cible = versionCible ?? schemaVersion;
    final migrationsAUtiliser = migrations ?? migrationsHive;

    if (versionStockee == null) {
      // Première installation, ou base créée avant l'introduction du
      // versionnement : adopter la version courante sans effacer
      // quoi que ce soit (les adaptateurs ont toujours été
      // rétrocompatibles, voir le registre vide migrationsHive).
      await _ouvrirBoxesDonnees();
      _validerBoxesLisibles();
      await parametresBox.put(ParametresKeys.schemaVersion, cible);
    } else if (versionStockee > cible) {
      // Rétrogradation : refus explicite, aucune donnée touchée.
      throw SchemaHivePlusRecentException(
        versionStockee: versionStockee,
        versionCode: cible,
      );
    } else if (versionStockee < cible) {
      // Mise à jour : exécuter les migrations enregistrées, protégées
      // par sauvegarde brute + journal récupérable.
      final chaine = _chaineMigrations(
        migrationsAUtiliser,
        versionStockee,
        cible,
      );
      await _executerMigration(versionStockee, cible, chaine);
      // Validation complète AVANT d'officialiser la nouvelle version.
      _validerBoxesLisibles();
      // Les instances de boxes ont été fermées/réouvertes pendant la
      // sauvegarde brute : repartir de l'instance actuelle, pas de celle
      // lue avant la migration.
      final boiteParametres = Hive.box(HiveBoxes.parametres);
      await boiteParametres.put(ParametresKeys.schemaVersion, cible);
      // Journal supprimé uniquement après succès complet.
      await boiteParametres.delete(ParametresKeys.migrationHiveEnCours);
    } else {
      // Version identique : ouverture normale.
      await _ouvrirBoxesDonnees();
      _validerBoxesLisibles();
    }

    _initialise = true;
  }

  /// Ne réinitialise QUE le marqueur de test, jamais les données. Permet
  /// aux tests de simuler un redémarrage de l'application (les boxes
  /// doivent au préalable être fermées via Hive.close()).
  @visibleForTesting
  static void reinitialiserPourTest() {
    _initialise = false;
  }

  static void _registerAdapterSiAbsent<T>(int typeId, TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  /// Lit le journal de migration, s'il existe. Une entrée présente
  /// signale une migration interrompue entre sa création et sa validation
  /// complète (voir _executerMigration).
  static Map<dynamic, dynamic>? _lireJournalMigration(Box parametresBox) {
    final valeur = parametresBox.get(ParametresKeys.migrationHiveEnCours);
    if (valeur == null) return null;
    if (valeur is Map) {
      return valeur;
    }
    // Journal corrompu (jamais censé se produire : on n'écrit que des
    // maps). Signal explicite plutôt que d'ignorer une migration
    // potentiellement en cours — on ne peut pas savoir si des données
    // ont bougé, donc on ne touche à rien.
    throw const MigrationHiveInterrompueException(
      restaurationEffectuee: false,
      details:
          'Journal de migration illisible dans parametres_box : impossible '
          'de déterminer automatiquement ce qui a été touché. Ne rien '
          'modifier, examiner la sauvegarde migrations_hive/ si elle '
          'existe.',
    );
  }

  /// Détecte une migration interrompue (journal présent dans
  /// parametres_box) et la récupère :
  /// - état `preparation` : la migration s'était arrêtée avant la
  ///   sauvegarde brute, donc avant de toucher au moindre fichier de
  ///   données → journal supprimé, signal explicite, rien d'autre ;
  /// - état `sauvegarde_creee` : la sauvegarde brute existe → restaurer
  ///   ces fichiers AVANT d'ouvrir les boxes métier, puis supprimer le
  ///   journal et signaler l'interruption. La version stockée reste
  ///   l'ancienne (elle a été restaurée avec le reste ;
  ///   `schemaVersion` n'est écrit qu'après validation complète).
  ///
  /// Si la restauration échoue : ni le journal ni la sauvegarde ne sont
  /// supprimés et l'initialisation est bloquée avec une erreur explicite
  /// ([MigrationHiveEchoueeException]) — jamais la suppression de la
  /// seule sauvegarde disponible, jamais de démarrage « au pif ».
  static Future<void> _recupererMigrationInterrompue() async {
    final parametresBox = Hive.box(HiveBoxes.parametres);
    final journal = _lireJournalMigration(parametresBox);
    if (journal == null) return;

    final etat = journal[ChampsJournalMigration.etat] as String?;
    if (etat == EtatJournalMigration.preparation) {
      // Rien n'a été modifié (le journal est écrit avant la moindre
      // manip de fichiers) : on peut simplement reprendre le cycle à zéro.
      await parametresBox.delete(ParametresKeys.migrationHiveEnCours);
      throw const MigrationHiveInterrompueException(
        restaurationEffectuee: false,
      );
    }

    // Sinon (sauvegarde_creee, ou état inconnu par prudence) : la
    // sauvegarde brute a probablement été créée, les fichiers peuvent ne
    // plus refléter l'état d'avant migration → restaurer.
    final dossier = journal[ChampsJournalMigration.dossier] as String?;
    try {
      await SauvegardeBruteHive.restaurer(
        nomDossier: dossier!,
        rouvrirBoxes: _rouvrirToutesLesBoxes,
      );
    } on Object catch (e) {
      // Restaurer a déjà fait son possible ; on ne supprime NI le
      // journal NI la sauvegarde : le blocage est explicite et réparable.
      throw MigrationHiveEchoueeException(
        phase: 'recuperation_demarrage',
        restaurationReussie: false,
        dossierSauvegarde: dossier,
        cause: e,
      );
    }
    // Le fichier parametres_box restauré contient encore l'ancien
    // journal (émis avant la sauvegarde) : le supprimer explicitement.
    final parametresRestaures = Hive.box(HiveBoxes.parametres);
    await parametresRestaures.delete(ParametresKeys.migrationHiveEnCours);
    throw MigrationHiveInterrompueException(
      restaurationEffectuee: true,
      dossierSauvegarde: dossier,
    );
  }

  /// Résout la chaîne de migrations à exécuter de [versionDe] à
  /// [versionCible] dans [migrations], en suivant les [HiveMigration] les
  /// unes après les autres. S'arrête avec
  /// [MigrationHiveManquanteException] si un maillon manque : le
  /// démarrage est refusé, aucune donnée n'est effacée (comportement qui
  /// remplace l'ancien effacement automatique des boxes).
  static List<HiveMigration> _chaineMigrations(
    List<HiveMigration> migrations,
    int versionDe,
    int versionCible,
  ) {
    final chaine = <HiveMigration>[];
    var courant = versionDe;
    while (courant < versionCible) {
      final suivantes = migrations.where((m) => m.versionDe == courant).toList()
        ..sort((a, b) => a.versionVers.compareTo(b.versionVers));
      final suivante = suivantes
          .where(
            (m) => m.versionVers > courant && m.versionVers <= versionCible,
          )
          .firstOrNull;
      if (suivante == null) {
        throw MigrationHiveManquanteException(
          versionManquante: courant,
          versionCible: versionCible,
        );
      }
      chaine.add(suivante);
      courant = suivante.versionVers;
    }
    return chaine;
  }

  /// Exécute une migration [chaine] de [de] vers [vers] avec filet
  /// complet : journal → sauvegarde brute (flush, fermeture contrôlée,
  /// copie des `.hive`, manifeste, réouverture) → étapes ordonnées avec
  /// mise à jour du journal après chacune → restauration en cas d'échec.
  ///
  /// NE s'occupe PAS de `schemaVersion` ni de la suppression du journal :
  /// l'appelant écrit la nouvelle version et supprime le journal
  /// uniquement après validation complète.
  ///
  /// Invariant : les boxes métier ne sont modifiées par les étapes qu'une
  /// fois la sauvegarde créée et le journal passé à
  /// [EtatJournalMigration.sauvegardeCreee].
  static Future<void> _executerMigration(
    int de,
    int vers,
    List<HiveMigration> chaine,
  ) async {
    assert(chaine.isNotEmpty);
    final nomDossier =
        'v${de}_vers_v${vers}_${DateTime.now().microsecondsSinceEpoch}';
    final parametresBox = Hive.box(HiveBoxes.parametres);

    // 1) Journal AVANT tout : la moindre interruption deviendra
    //    récupérable au démarrage suivant.
    await parametresBox
        .put(ParametresKeys.migrationHiveEnCours, <String, dynamic>{
          ChampsJournalMigration.etat: EtatJournalMigration.preparation,
          ChampsJournalMigration.de: de,
          ChampsJournalMigration.vers: vers,
          ChampsJournalMigration.dossier: nomDossier,
          ChampsJournalMigration.debut: DateTime.now(),
          ChampsJournalMigration.etapes: <String>[],
        });

    try {
      // 2) Sauvegarde brute : flush + fermeture contrôlée + copie des
      //    fichiers `.hive` + manifeste + réouverture. Seule la box
      //    paramètres est ouverte à ce stade ; sauvegarder TOUS les
      //    fichiers `.hive` couvre de toute façon toutes les boxes.
      await SauvegardeBruteHive.creer(
        versionDe: de,
        versionVers: vers,
        nomDossier: nomDossier,
        boxesOuvertes: {HiveBoxes.parametres: parametresBox},
        rouvrirBoxes: _rouvrirToutesLesBoxes,
      );

      // 3) À partir d'ici (sauvegarde validée), les étapes peuvent
      //    modifier les données : le journal bascule d'abord.
      await _mettreAJourJournal(
        Hive.box(HiveBoxes.parametres),
        etat: EtatJournalMigration.sauvegardeCreee,
      );

      // 4) Étapes ordonnées, journalisées une à une.
      //    Note : la réouverture a re-créé les instances de boxes ; on
      //    repart systématiquement de Hive.box(...), jamais des
      //    références d'avant fermeture.
      for (final etape in chaine) {
        await etape.executer();
        await _mettreAJourJournal(
          Hive.box(HiveBoxes.parametres),
          etapeFaite: etape.nom,
        );
      }
    } on Object catch (e) {
      // Échec d'une étape (ou de la sauvegarde) : remettre les données
      // dans leur état exact d'avant migration, puis arrêter TOUT.
      final journal =
          Hive.box(
                HiveBoxes.parametres,
              ).get(ParametresKeys.migrationHiveEnCours)
              as Map?;
      final sauvegardeExiste =
          journal?[ChampsJournalMigration.etat] ==
          EtatJournalMigration.sauvegardeCreee;
      if (sauvegardeExiste) {
        try {
          await SauvegardeBruteHive.restaurer(
            nomDossier: nomDossier,
            rouvrirBoxes: _rouvrirToutesLesBoxes,
          );
          // Restauration réussie : les données sont revenues à l'état
          // d'avant. Le journal (recopié de la sauvegarde) est alors
          // nettoyé ; la sauvegarde, elle, reste conservée sur disque.
          await Hive.box(
            HiveBoxes.parametres,
          ).delete(ParametresKeys.migrationHiveEnCours);
          throw MigrationHiveEchoueeException(
            phase: 'execution_migration_retablie',
            restaurationReussie: true,
            dossierSauvegarde: nomDossier,
            cause: e,
          );
        } on MigrationHiveEchoueeException {
          rethrow;
        } on Object catch (e2) {
          // Même la restauration a échoué : signaler, ne rien effacer,
          // ne jamais supprimer la sauvegarde.
          throw MigrationHiveEchoueeException(
            phase: 'restauration_apres_echec_execution',
            restaurationReussie: false,
            dossierSauvegarde: nomDossier,
            cause: e2,
          );
        }
      }
      // La sauvegarde elle-même a échoué : RIEN n'a été modifié (la
      // sauvegarde est le premier geste de la migration). Journal
      // supprimé pour repartir propre au prochain démarrage — sur
      // l'instance ACTUELLE de la box : la réouverture de secours de
      // SauvegardeBruteHive a remplacé l'ancienne.
      await Hive.box(
        HiveBoxes.parametres,
      ).delete(ParametresKeys.migrationHiveEnCours);
      throw MigrationHiveEchoueeException(
        phase: 'sauvegarde',
        restaurationReussie: true,
        dossierSauvegarde: nomDossier,
        cause: e,
      );
    }
  }

  /// Met à jour le journal de migration (état, ou étape terminée) et le
  /// réécrit entièrement pour garantir sa persistance.
  static Future<void> _mettreAJourJournal(
    Box parametresBox, {
    String? etat,
    String? etapeFaite,
  }) async {
    final brut = parametresBox.get(ParametresKeys.migrationHiveEnCours);
    if (brut is! Map) {
      throw StateError(
        'Journal de migration absent ou corrompu pendant une migration.',
      );
    }
    final journal = Map<String, dynamic>.from(brut);
    if (etat != null) {
      journal[ChampsJournalMigration.etat] = etat;
    }
    if (etapeFaite != null) {
      final etapes = List<String>.from(
        journal[ChampsJournalMigration.etapes] as List? ?? [],
      );
      etapes.add(etapeFaite);
      journal[ChampsJournalMigration.etapes] = etapes;
    }
    await parametresBox.put(ParametresKeys.migrationHiveEnCours, journal);
  }

  /// Ferme tout et rouvre la box paramètres + toutes les boxes métier.
  /// Callback passé à [SauvegardeBruteHive.creer]/[SauvegardeBruteHive.
  /// restaurer] : HiveService reste le seul endroit qui connaît les
  /// types des boxes (hive_migrations.dart n'importe pas les modèles).
  static Future<void> _rouvrirToutesLesBoxes() async {
    await Hive.close();
    await Hive.openBox(HiveBoxes.parametres);
    await _ouvrirBoxesDonnees();
  }

  static Future<void> _ouvrirBoxesDonnees() async {
    await Future.wait([
      Hive.openBox<Produit>(HiveBoxes.produits),
      Hive.openBox<model.Transaction>(HiveBoxes.transactions),
      Hive.openBox<Dette>(HiveBoxes.dettes),
      Hive.openBox<Devise>(HiveBoxes.devises),
      Hive.openBox<PaiementDette>(HiveBoxes.paiementsDette),
      Hive.openBox<Depense>(HiveBoxes.depenses),
      Hive.openBox<ConflitSynchronisation>(HiveBoxes.conflitsSynchronisation),
      Hive.openBox<Conditionnement>(HiveBoxes.conditionnements),
    ]);
  }

  /// Force la lecture complète de chaque box métier : si un schéma
  /// résiduel restait incompatible (adaptateur, champ non nullable sans
  /// défaut...), l'échec se produit ICI — avant l'écriture de la
  /// nouvelle version, avant tout effacement, données conservées.
  static void _validerBoxesLisibles() {
    HiveService.produitsBox.values.toList();
    HiveService.transactionsBox.values.toList();
    HiveService.dettesBox.values.toList();
    HiveService.devisesBox.values.toList();
    HiveService.paiementsDetteBox.values.toList();
    HiveService.depensesBox.values.toList();
    HiveService.conflitsSynchronisationBox.values.toList();
    HiveService.conditionnementsBox.values.toList();
    HiveService.parametresBox.keys.toList();
  }

  static Box<Produit> get produitsBox => Hive.box<Produit>(HiveBoxes.produits);

  static Box<model.Transaction> get transactionsBox =>
      Hive.box<model.Transaction>(HiveBoxes.transactions);

  static Box<Dette> get dettesBox => Hive.box<Dette>(HiveBoxes.dettes);

  static Box<Devise> get devisesBox => Hive.box<Devise>(HiveBoxes.devises);

  static Box<PaiementDette> get paiementsDetteBox =>
      Hive.box<PaiementDette>(HiveBoxes.paiementsDette);

  static Box<Depense> get depensesBox => Hive.box<Depense>(HiveBoxes.depenses);

  static Box<ConflitSynchronisation> get conflitsSynchronisationBox =>
      Hive.box<ConflitSynchronisation>(HiveBoxes.conflitsSynchronisation);

  static Box<Conditionnement> get conditionnementsBox =>
      Hive.box<Conditionnement>(HiveBoxes.conditionnements);

  static Box get parametresBox => Hive.box(HiveBoxes.parametres);
}
