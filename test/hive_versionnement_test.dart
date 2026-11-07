// Tests de la mission C3 : sécurisation du versionnement et des
// migrations Hive. Un changement de schemaVersion ne doit JAMAIS
// déclencher la moindre suppression de données : la sauvegarde brute,
// le journal de migration et la récupération au démarrage les
// remplacent. Les vérifications portent sur le contenu persisté sur
// disque (fermeture de toutes les boxes + réouverture fraîche), pas
// seulement sur des objets en mémoire.

import 'dart:convert';
import 'dart:io';

import 'package:caisse_de_poche/config/hive_boxes.dart';
import 'package:caisse_de_poche/models/categorie_depense.dart';
import 'package:caisse_de_poche/models/conditionnement.dart';
import 'package:caisse_de_poche/models/conflit_synchronisation.dart';
import 'package:caisse_de_poche/models/depense.dart';
import 'package:caisse_de_poche/models/devise.dart';
import 'package:caisse_de_poche/models/dette.dart';
import 'package:caisse_de_poche/models/item_vendu.dart';
import 'package:caisse_de_poche/models/mode_paiement.dart';
import 'package:caisse_de_poche/models/paiement_dette.dart';
import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/models/transaction.dart' as model;
import 'package:caisse_de_poche/services/hive_migrations.dart';
import 'package:caisse_de_poche/services/hive_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final Directory _dir;
  _FakePathProviderPlatform(this._dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir.path;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'caisse_de_poche_hive_versionnement_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await Hive.close();
    HiveService.reinitialiserPourTest();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Fichiers encore verrouillés par le système : pas grave,
        // le répertoire système temporaire nettoie à sa façon.
      }
    }
  });

  /// Premier démarrage sur une installation vierge : crée la version
  /// stockée et ouvre toutes les boxes (adaptateurs enregistrés).
  Future<void> premierDemarrage() async {
    await HiveService.initialiser();
  }

  /// Remplit CHAQUE box métier de données représentatives, avec des
  /// identifiants fixes et des liaisons réelles entre elles.
  Future<void> grainerDonnees() async {
    await HiveService.produitsBox.put(
      'p-1',
      Produit(
        id: 'p-1',
        nom: 'Coca',
        prixAchat: 75,
        prixVente: 150,
        stockActuel: 100,
        devise: 'XOF',
        uniteBase: 'bouteille',
        dateCreation: DateTime(2026, 1, 5),
      ),
    );
    await HiveService.transactionsBox.put(
      't-1',
      model.Transaction(
        id: 't-1',
        date: DateTime(2026, 1, 10, 9, 30),
        itemsVendus: [
          ItemVendu(
            produitId: 'p-1',
            nomProduit: 'Coca',
            quantite: 2,
            prixUnitaireVente: 150,
            prixUnitaireAchat: 75,
          ),
        ],
        montantTotal: 300,
        margeBrute: 150,
        devise: 'XOF',
        modePaiement: ModePaiement.especes,
      ),
    );
    await HiveService.dettesBox.put(
      'd-1',
      Dette(
        id: 'd-1',
        nomClient: 'Awa',
        telephone: '+225 07 00 00 00 00',
        montantDu: 500,
        dateDette: DateTime(2026, 1, 10),
        devise: 'XOF',
        transactionId: 't-1',
      ),
    );
    await HiveService.devisesBox.put(
      'dv-XOF',
      Devise(
        id: 'dv-XOF',
        symbole: 'CFA',
        nom: 'Franc CFA',
        codeIso: 'XOF',
        codePays: 'CI',
        decimales: 0,
      ),
    );
    await HiveService.paiementsDetteBox.put(
      'pd-1',
      PaiementDette(
        id: 'pd-1',
        detteId: 'd-1',
        montant: 200,
        date: DateTime(2026, 1, 11),
        devise: 'XOF',
      ),
    );
    await HiveService.depensesBox.put(
      'e-1',
      Depense(
        id: 'e-1',
        libelle: 'Transport marchandises',
        montant: 1000,
        date: DateTime(2026, 1, 11),
        categorie: CategorieDepense.transport,
        devise: 'XOF',
      ),
    );
    await HiveService.conditionnementsBox.put(
      'c-1',
      Conditionnement(
        id: 'c-1',
        produitId: 'p-1',
        nom: 'Casier',
        quantiteEnUniteBase: 20,
        prixVente: 1500,
        devise: 'XOF',
        parDefaut: false,
      ),
    );
    await HiveService.conflitsSynchronisationBox.put(
      'cf-1',
      ConflitSynchronisation(
        id: 'cf-1',
        entiteType: 'Produit',
        entiteId: 'p-1',
        dateConflit: DateTime(2026, 1, 11, 14, 0),
        resolutionRetenue: 'conserverLocal',
      ),
    );
    await HiveService.parametresBox.put(ParametresKeys.paysCode, 'CI');
  }

  /// Ferme TOUT, rouvre chaque box fraîchement (lecture réelle des
  /// fichiers sur disque) et retourne un instantané textuel du contenu :
  /// clés, identifiants et champs sensibles (prix en unités mineures,
  /// liaisons produit/dette/conditionnement, version stockée, journal).
  Future<Map<String, Object?>> etatCompletSurDisque() async {
    await Hive.close();
    final parametres = await Hive.openBox(HiveBoxes.parametres);
    final produits = await Hive.openBox<Produit>(HiveBoxes.produits);
    final transactions = await Hive.openBox<model.Transaction>(
      HiveBoxes.transactions,
    );
    final dettes = await Hive.openBox<Dette>(HiveBoxes.dettes);
    final devises = await Hive.openBox<Devise>(HiveBoxes.devises);
    final paiements = await Hive.openBox<PaiementDette>(
      HiveBoxes.paiementsDette,
    );
    final depenses = await Hive.openBox<Depense>(HiveBoxes.depenses);
    final conflits = await Hive.openBox<ConflitSynchronisation>(
      HiveBoxes.conflitsSynchronisation,
    );
    final conditionnements = await Hive.openBox<Conditionnement>(
      HiveBoxes.conditionnements,
    );

    final journal = parametres.get(ParametresKeys.migrationHiveEnCours);
    return {
      'schemaVersion': parametres.get(ParametresKeys.schemaVersion) as int?,
      'paysCode': parametres.get(ParametresKeys.paysCode) as String?,
      'journalEtat': journal is Map
          ? journal[ChampsJournalMigration.etat] as String?
          : null,
      'journalDossier': journal is Map
          ? journal[ChampsJournalMigration.dossier] as String?
          : null,
      'produits': {
        for (final p in produits.values)
          p.id:
              '${p.nom}/${p.stockActuel}/${p.prixAchatMineur}/${p.uniteBase}/${p.synchronise}',
      },
      'transactions': {
        for (final t in transactions.values)
          t.id:
              '${t.montantTotal}/${t.montantTotalMineur}/${t.modePaiement.name}/${t.itemsVendus.length}/${t.itemsVendus.first.produitId}/${t.itemsVendus.first.prixUnitaireVenteMineur}',
      },
      'dettes': {
        for (final d in dettes.values)
          d.id:
              '${d.nomClient}/${d.montantDu}/${d.montantDuMineur}/${d.statut.name}/${d.transactionId}',
      },
      'devises': {
        for (final dv in devises.values) dv.id: '${dv.codeIso}/${dv.decimales}',
      },
      'paiementsDette': {
        for (final x in paiements.values)
          x.id: '${x.detteId}/${x.montant}/${x.montantMineur}',
      },
      'depenses': {
        for (final x in depenses.values)
          x.id: '${x.libelle}/${x.montant}/${x.categorie.name}',
      },
      'conditionnements': {
        for (final x in conditionnements.values)
          x.id:
              '${x.produitId}/${x.nom}/${x.quantiteEnUniteBase}/${x.prixVente}',
      },
      'conflits': {
        for (final x in conflits.values)
          x.id: '${x.entiteType}/${x.entiteId}/${x.resolutionRetenue}',
      },
    };
  }

  /// Simule un redémarrage : fermeture complète, reset du marqueur de
  /// test, réinitialisation réelle via HiveService.
  Future<void> redemarrage({
    List<HiveMigration>? migrations,
    int? versionCible,
  }) async {
    await Hive.close();
    HiveService.reinitialiserPourTest();
    await HiveService.initialiser(
      migrations: migrations,
      versionCible: versionCible,
    );
  }

  /// Comme [redemarrage] mais pour un démarrage censé échouer : retourne
  /// l'erreur au lieu de la cacher.
  Future<Object> redemarrageQuiEchoue({
    List<HiveMigration>? migrations,
    int? versionCible,
  }) async {
    await Hive.close();
    HiveService.reinitialiserPourTest();
    try {
      await HiveService.initialiser(
        migrations: migrations,
        versionCible: versionCible,
      );
    } on Object catch (e) {
      return e;
    }
    fail('Le démarrage aurait dû être refusé.');
  }

  String repertoireSauvegardes() =>
      '${tempDir.path}/$dossierSauvegardesMigration';

  /// Écrit manuellement le journal d'une migration « interrompue sur le
  /// point de démarrer », comme le ferait un arrêt brutal de
  /// l'application, plus la copie brute correspondante (boxes FERMÉES
  /// pour copier des fichiers stables — c'est ce que fait
  /// SauvegardeBruteHive.creer en production). Écrit la même structure de
  /// manifeste que le code de production (tailles + empreintes SHA-256).
  Future<String> preparerMigrationInterrompue(String nomDossier) async {
    await HiveService.parametresBox
        .put(ParametresKeys.migrationHiveEnCours, <String, dynamic>{
          ChampsJournalMigration.etat: EtatJournalMigration.sauvegardeCreee,
          ChampsJournalMigration.de: 1,
          ChampsJournalMigration.vers: 2,
          ChampsJournalMigration.dossier: nomDossier,
          ChampsJournalMigration.debut: DateTime(2026, 1, 12, 8, 0),
          ChampsJournalMigration.etapes: <String>[],
        });
    await Hive.close();
    final dossier = Directory('${repertoireSauvegardes()}/$nomDossier');
    await dossier.create(recursive: true);
    final fichiers = <Map<String, dynamic>>[];
    await for (final entite in Directory(tempDir.path).list()) {
      if (entite is File && entite.path.endsWith('.hive')) {
        final nom = entite.uri.pathSegments.last;
        final contenu = await entite.readAsBytes();
        await File('${dossier.path}/$nom').writeAsBytes(contenu, flush: true);
        fichiers.add({
          'nom': nom,
          'taille': contenu.length,
          'sha256': sha256.convert(contenu).toString(),
        });
      }
    }
    await File('${dossier.path}/$nomFichierManifeste').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'versionSource': 1,
        'versionCible': 2,
        'date': DateTime(2026, 1, 12, 8, 0).toIso8601String(),
        'fichiers': fichiers,
      }),
      flush: true,
    );
    return dossier.path;
  }

  test("1. première installation : la version est écrite, toutes les boxes "
      'existent sur disque, rien n\'est supprimé', () async {
    await premierDemarrage();

    final etat = await etatCompletSurDisque();
    expect(etat['schemaVersion'], HiveService.schemaVersion);
    expect(etat['journalEtat'], isNull);
    expect(etat['produits'], isEmpty);
    for (final nom in [
      HiveBoxes.parametres,
      HiveBoxes.produits,
      HiveBoxes.transactions,
      HiveBoxes.dettes,
      HiveBoxes.devises,
      HiveBoxes.paiementsDette,
      HiveBoxes.depenses,
      HiveBoxes.conditionnements,
      HiveBoxes.conflitsSynchronisation,
    ]) {
      expect(
        File('${tempDir.path}/$nom.hive').existsSync(),
        isTrue,
        reason: 'Fichier $nom.hive attendu sur disque.',
      );
    }
    expect(
      Directory(repertoireSauvegardes()).existsSync(),
      isFalse,
      reason: 'Aucune migration déclenchée : pas de sauvegarde attendue.',
    );
  });

  test("2. version identique : données intactes, aucun effacement, aucune "
      'sauvegarde créée', () async {
    await premierDemarrage();
    await grainerDonnees();
    final avant = await etatCompletSurDisque();
    expect(avant['schemaVersion'], HiveService.schemaVersion);

    await redemarrage(); // même version, aucun régime de migration

    final apres = await etatCompletSurDisque();
    expect(apres['schemaVersion'], HiveService.schemaVersion);
    expect(apres['journalEtat'], isNull);
    for (final boite in [
      'produits',
      'transactions',
      'dettes',
      'devises',
      'paiementsDette',
      'depenses',
      'conditionnements',
      'conflits',
    ]) {
      expect(apres[boite], avant[boite], reason: 'Box $boite');
    }
    expect(Directory(repertoireSauvegardes()).existsSync(), isFalse);
  });

  test('3. anciennes données sans schema_version : version adoptée, aucune '
      'suppression de données', () async {
    await premierDemarrage();
    await grainerDonnees();
    // Simuler une base créée avant l'introduction du versionnement.
    await HiveService.parametresBox.delete(ParametresKeys.schemaVersion);
    final journalAvant = await etatCompletSurDisque();
    expect(journalAvant['schemaVersion'], isNull);

    await redemarrage();

    final apres = await etatCompletSurDisque();
    expect(apres['schemaVersion'], HiveService.schemaVersion);
    expect(apres['journalEtat'], isNull);
    for (final boite in [
      'produits',
      'transactions',
      'dettes',
      'devises',
      'paiementsDette',
      'depenses',
      'conditionnements',
      'conflits',
    ]) {
      expect(apres[boite], journalAvant[boite], reason: 'Box $boite');
    }
    expect(Directory(repertoireSauvegardes()).existsSync(), isFalse);
  });

  test(
    '4. version stockée supérieure au code : démarrage refusé explicitement, '
    'données strictement intactes',
    () async {
      await premierDemarrage();
      await grainerDonnees();
      // Simuler des données créées par une version future (rétrogradation).
      await HiveService.parametresBox.put(ParametresKeys.schemaVersion, 3);
      final avant = await etatCompletSurDisque();

      final e = await redemarrageQuiEchoue(); // code actuel = 1 < 3
      expect(e, isA<SchemaHivePlusRecentException>());
      final message = e.toString();
      expect(message, contains('PLUS RÉCENT'));
      expect(message, contains('Aucune donnée'));
      // Rien n'a bougé (pas de sauvegarde, pas de migration tentée).
      expect(Directory(repertoireSauvegardes()).existsSync(), isFalse);

      final apres = await etatCompletSurDisque();
      expect(apres, equals(avant));
    },
  );

  test('5. migration simulée 1→2 : sauvegarde brute créée AVANT la migration '
      '(manifeste + état pré-migration restaurable), journal nettoyé après '
      'succès', () async {
    await premierDemarrage();
    await grainerDonnees();
    final nomDossier = RegExp(r'^v1_vers_v2_\d+$');

    var etapeFaite = false;
    await redemarrage(
      migrations: [
        HiveMigration(
          versionDe: 1,
          versionVers: 2,
          nom: 'test_reecrit_produits',
          executer: () async {
            etapeFaite = true;
            final produits = HiveService.produitsBox;
            final coca = produits.get('p-1')!;
            coca.nom = 'Coca migre';
            await produits.put(coca.id, coca);
          },
        ),
      ],
      versionCible: 2,
    );
    expect(etapeFaite, isTrue);

    // La sauvegarde brute existe, avec le manifeste attendu.
    final sauvegardes = Directory(repertoireSauvegardes());
    expect(sauvegardes.existsSync(), isTrue);
    final dossiers = sauvegardes.listSync().whereType<Directory>().toList();
    expect(dossiers, hasLength(1));
    // Nom du dossier (segment non vide venant après migrations_hive) :
    // attendu v1_vers_v2_<horodatage>, généré par _executerMigration.
    final segmentsSauvegarde = dossiers.single.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    expect(nomDossier.hasMatch(segmentsSauvegarde.last), isTrue);
    final manifeste =
        jsonDecode(
              File(
                '${dossiers.single.path}/$nomFichierManifeste',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(manifeste['versionSource'], 1);
    expect(manifeste['versionCible'], 2);
    expect(DateTime.parse(manifeste['date'] as String), isA<DateTime>());
    final fichierSauvegardes = (manifeste['fichiers'] as List)
        .map((f) => f as Map<String, dynamic>)
        .toList();
    final nomsSauvegardes = fichierSauvegardes.map((f) => f['nom']).toSet();
    for (final nom in [
      '${HiveBoxes.parametres}.hive',
      '${HiveBoxes.produits}.hive',
      '${HiveBoxes.transactions}.hive',
      '${HiveBoxes.dettes}.hive',
      '${HiveBoxes.devises}.hive',
      '${HiveBoxes.paiementsDette}.hive',
      '${HiveBoxes.depenses}.hive',
      '${HiveBoxes.conditionnements}.hive',
      '${HiveBoxes.conflitsSynchronisation}.hive',
    ]) {
      expect(nomsSauvegardes, contains(nom));
    }
    for (final f in fichierSauvegardes) {
      expect(f['taille'], greaterThan(0));
      expect(
        File('${dossiers.single.path}/${f['nom']}').lengthSync(),
        f['taille'],
        reason: 'Le fichier copié ${f['nom']} doit exister et correspondre.',
      );
    }
    // La sauvegarde n'est pas supprimée après la migration réussie.
    expect(dossiers.single.existsSync(), isTrue);

    // Version officielle réécrite, journal nettoyé, étape appliquée.
    final etat = await etatCompletSurDisque();
    expect(etat['schemaVersion'], 2);
    expect(etat['journalEtat'], isNull);
    final produitsApres = etat['produits'] as Map<String, String>;
    expect(produitsApres['p-1'], contains('Coca migre'));

    // Preuve à la racine : le fichier produits_box de la SAUVEGARDE porte
    // l'état pré-migration (« Coca »), donc la sauvegarde a bien été
    // créée AVANT l'exécution de la migration. On ouvre le box depuis le
    // dossier-de-sauvegarde (Hive.openBox(path:) attend un répertoire).
    await Hive.close();
    final produitsBackup = await Hive.openBox<Produit>(
      HiveBoxes.produits,
      path: dossiers.single.path,
    );
    expect(produitsBackup.get('p-1')!.nom, 'Coca');
    await Hive.close();
  });

  test(
    '6. migration interrompue en cours d\'exécution (étape qui échoue) : '
    'restauration de la sauvegarde, données exactes d\'avant, signal explicite',
    () async {
      await premierDemarrage();
      await grainerDonnees();
      final avant = await etatCompletSurDisque();

      Object e;
      e = await redemarrageQuiEchoue(
        migrations: [
          HiveMigration(
            versionDe: 1,
            versionVers: 2,
            nom: 'test_echoue_apres_ecriture',
            executer: () async {
              // Écrit du brick puis échoue : le rollback par restauration
              // doit retirer ce brick SUR DISQUE.
              final produits = HiveService.produitsBox;
              await produits.put(
                'p-fantome',
                Produit(
                  id: 'p-fantome',
                  nom: 'Fantôme',
                  prixAchat: 1,
                  prixVente: 2,
                  stockActuel: 1,
                  devise: 'XOF',
                ),
              );
              throw Exception('Erreur simulée pendant la migration');
            },
          ),
        ],
        versionCible: 2,
      );
      expect(e, isA<MigrationHiveEchoueeException>());
      final echouee = e as MigrationHiveEchoueeException;
      expect(echouee.restaurationReussie, isTrue);
      expect(echouee.dossierSauvegarde, isNotNull);
      // La sauvegarde reste conservée après l'échec.
      expect(
        Directory(
          '${repertoireSauvegardes()}/${echouee.dossierSauvegarde}',
        ).existsSync(),
        isTrue,
      );

      final apres = await etatCompletSurDisque();
      expect(apres['schemaVersion'], 1); // version conservée
      expect(apres['journalEtat'], isNull); // journal nettoyé
      expect((apres['produits'] as Map).keys, isNot(contains('p-fantome')));
      expect(apres, equals(avant)); // strictement l'état d'avant
    },
  );

  test(
    '7. migration interrompue détectée au démarrage : restauration de la '
    'sauvegarde AVANT l\'ouverture des boxes métier, données rétablies',
    () async {
      await premierDemarrage();
      await grainerDonnees();
      final dossier = await preparerMigrationInterrompue('v1_vers_v2_crash');

      // Arrêt brutal « après la sauvegarde, pendant les étapes » : ajouter
      // un enregistrement fantôme comme l'aurait fait une étape.
      final produits = await Hive.openBox<Produit>(HiveBoxes.produits);
      await produits.put(
        'p-fantome',
        Produit(
          id: 'p-fantome',
          nom: 'Fantôme',
          prixAchat: 1,
          prixVente: 2,
          stockActuel: 1,
          devise: 'XOF',
        ),
      );
      await Hive.close();

      final e = await redemarrageQuiEchoue();
      expect(e, isA<MigrationHiveInterrompueException>());
      final interrompue = e as MigrationHiveInterrompueException;
      expect(interrompue.restaurationEffectuee, isTrue);
      expect(interrompue.dossierSauvegarde, 'v1_vers_v2_crash');
      // La sauvegarde n'est PAS supprimée par la restauration.
      expect(Directory(dossier).existsSync(), isTrue);

      final etat = await etatCompletSurDisque();
      expect(etat['schemaVersion'], 1);
      expect(etat['journalEtat'], isNull); // journal périmé nettoyé
      expect((etat['produits'] as Map).keys, isNot(contains('p-fantome')));
      expect((etat['produits'] as Map).keys, contains('p-1'));
      expect((etat['dettes'] as Map).keys, contains('d-1'));
    },
  );

  test('8. échec de restauration : démarrage bloqué explicitement, ni le '
      'journal nor une autre sauvegarde n\'est supprimé', () async {
    await premierDemarrage();
    await grainerDonnees();
    // Sauvegarde RÉELLE existante (comme si une migration 1→2 avait
    // démarré) pour vérifier qu'un échec de restauration d'un AUTRE
    // journal n'endommage aucun dossier de sauvegarde.
    const nomSauvegardeReelle = 'v1_vers_v2_reelle';
    final dossierReel = await preparerMigrationInterrompue(nomSauvegardeReelle);
    // Journal qui pointe vers une sauvegarde ABSENTE (arrêt brutal
    // avant la création de la copie, ou dossier perdu) : la
    // restauration échouera avant de toucher à quoi que ce soit.
    await Hive.openBox(HiveBoxes.parametres);
    await Hive.box(
      HiveBoxes.parametres,
    ).put(ParametresKeys.migrationHiveEnCours, <String, dynamic>{
      ChampsJournalMigration.etat: EtatJournalMigration.sauvegardeCreee,
      ChampsJournalMigration.de: 1,
      ChampsJournalMigration.vers: 2,
      ChampsJournalMigration.dossier: 'v1_vers_v2_absente',
      ChampsJournalMigration.debut: DateTime(2026, 1, 12, 9, 0),
      ChampsJournalMigration.etapes: <String>[],
    });
    await Hive.close();

    final e = await redemarrageQuiEchoue();
    expect(e, isA<MigrationHiveEchoueeException>());
    final echouee = e as MigrationHiveEchoueeException;
    expect(echouee.restaurationReussie, isFalse);
    expect(echouee.cause!.toString(), contains('introuvable'));

    final etat = await etatCompletSurDisque();
    expect(
      etat['journalEtat'],
      EtatJournalMigration.sauvegardeCreee,
      reason: 'Le journal est conservé pour diagnostic et reprise.',
    );
    expect(etat['journalDossier'], 'v1_vers_v2_absente');
    expect(etat['schemaVersion'], HiveService.schemaVersion);
    // Données métier intactes.
    expect((etat['produits'] as Map).keys, contains('p-1'));
    expect((etat['dettes'] as Map).keys, contains('d-1'));
    // ...et la sauvegarde réelle n'a pas bougé.
    expect(Directory(dossierReel).existsSync(), isTrue);
    expect(
      File('$dossierReel/${HiveBoxes.produits}.hive').existsSync(),
      isTrue,
    );
  });

  test("9. récupération idempotente : restaurer puis redémarrer trois fois "
      'conserve exactement les mêmes données', () async {
    await premierDemarrage();
    await grainerDonnees();
    await preparerMigrationInterrompue('v1_vers_v2_manuel');
    final avant = await etatCompletSurDisque();
    // La récupération consomme le journal (légitiment) : on l'exclut de
    // la comparaison globale, il est vérifié séparément.
    avant['journalEtat'] = null;
    avant['journalDossier'] = null;

    // Démarrage 1 : récupération + signal.
    final e = await redemarrageQuiEchoue();
    expect(e, isA<MigrationHiveInterrompueException>());
    final apresRecuperation = await etatCompletSurDisque();
    expect(apresRecuperation['journalEtat'], isNull); // journal consommé
    expect(apresRecuperation, equals(avant));

    // Démarrages 2 et 3 : plus de journal, tout se passe normalement,
    // et aucune donnée ne bouge (pas d'effacement, pas de duplication).
    await redemarrage();
    final apresRedemarrage2 = await etatCompletSurDisque();
    expect(apresRedemarrage2, equals(avant));
    await redemarrage();
    final apresRedemarrage3 = await etatCompletSurDisque();
    expect(apresRedemarrage3, equals(avant));

    // Une seule et même sauvegarde reste sur disque.
    final dossiers = Directory(
      repertoireSauvegardes(),
    ).listSync().whereType<Directory>().toList();
    expect(dossiers, hasLength(1));
    expect(dossiers.single.path, contains('v1_vers_v2_manuel'));
  });

  test('10. conservation des données et des identifiants de TOUTES les boxes '
      'au cours d\'une migration 1→2 complète', () async {
    await premierDemarrage();
    await grainerDonnees();
    final avant = await etatCompletSurDisque();

    await redemarrage(
      migrations: [
        HiveMigration(
          versionDe: 1,
          versionVers: 2,
          nom: 'test_marque_produits_synchronise',
          executer: () async {
            // Transformation triviale et traçable : marque chaque
            // produit synchronisé — l'inverse serait une perte.
            final produits = HiveService.produitsBox;
            for (final p in produits.values) {
              p.synchronise = true;
              await produits.put(p.id, p);
            }
          },
        ),
      ],
      versionCible: 2,
    );

    final apres = await etatCompletSurDisque();
    expect(apres['schemaVersion'], 2);
    expect(apres['journalEtat'], isNull);
    // Toutes les autres boxes : identiques au caractère près.
    for (final boite in [
      'transactions',
      'dettes',
      'devises',
      'paiementsDette',
      'depenses',
      'conditionnements',
      'conflits',
    ]) {
      expect(apres[boite], avant[boite], reason: 'Box $boite');
    }
    // Mêmes identifiants, valeurs métier conservées ; la seule différence
    // est synchronise=false→true, produite explicitement par l'étape.
    final produitsAvant = avant['produits'] as Map<String, String>;
    final produitsApres = apres['produits'] as Map<String, String>;
    expect(produitsApres.keys, produitsAvant.keys);
    for (final id in produitsAvant.keys) {
      expect(
        produitsApres[id],
        produitsAvant[id]!.replaceFirst('/false', '/true'),
        reason: 'Produit $id',
      );
    }
    // Les liaisons réelles entre boxes restent valides.
    expect((apres['dettes'] as Map)['d-1'], contains('t-1'));
    expect((apres['conditionnements'] as Map)['c-1'], contains('p-1'));
    expect((apres['paiementsDette'] as Map)['pd-1'], contains('d-1'));
  });

  /// Suite commune aux tests de validation de sauvegarde (11 à 14) :
  /// journal + sauvegarde brute valide préparée, puis on abîme le
  /// dossier de sauvegarde d'une façon précise ; le démarrage doit
  /// REFUSER la restauration sans toucher aux données vivantes.
  Future<({Object erreur, String dossier})> demarrageAvecSauvegardeAbimee(
    String nomDossier,
    void Function(String dossier) abimer,
    String motifAttendu, {
    required String nomFichierAccuse,
    bool manifesteSupprime = false,
  }) async {
    await premierDemarrage();
    await grainerDonnees();
    final dossier = await preparerMigrationInterrompue(nomDossier);
    abimer(dossier);

    final e = await redemarrageQuiEchoue();
    expect(e, isA<MigrationHiveEchoueeException>());
    final echouee = e as MigrationHiveEchoueeException;
    expect(echouee.restaurationReussie, isFalse);
    expect(echouee.cause!.toString(), contains(motifAttendu));
    if (nomFichierAccuse.isNotEmpty) {
      expect(echouee.cause!.toString(), contains(nomFichierAccuse));
    }

    // Données vivantes intactes : la validation a refusé la
    // restauration AVANT de fermer Hive et de modifier des fichiers.
    final etat = await etatCompletSurDisque();
    expect(etat['schemaVersion'], HiveService.schemaVersion);
    expect(etat['journalEtat'], EtatJournalMigration.sauvegardeCreee);
    expect(etat['journalDossier'], nomDossier);
    expect((etat['produits'] as Map).keys, contains('p-1'));
    expect((etat['transactions'] as Map).keys, contains('t-1'));
    expect((etat['dettes'] as Map).keys, contains('d-1'));
    expect((etat['paiementsDette'] as Map).keys, contains('pd-1'));
    expect((etat['depenses'] as Map).keys, contains('e-1'));
    expect((etat['conditionnements'] as Map).keys, contains('c-1'));
    expect((etat['conflits'] as Map).keys, contains('cf-1'));
    expect((etat['devises'] as Map).keys, contains('dv-XOF'));

    // La sauvegarde (incomplète/corrompue) reste sur disque : jamais
    // supprimée, elle sert au diagnostic. (Le manifeste n'est espéré
    // que s'il n'a pas été supprimé par le scénario lui-même.)
    expect(Directory(dossier).existsSync(), isTrue);
    if (!manifesteSupprime) {
      expect(File('$dossier/$nomFichierManifeste').existsSync(), isTrue);
    }
    return (erreur: e, dossier: dossier);
  }

  test('11. manifeste absent : restauration refusée explicitement, données '
      'vivantes intactes', () async {
    await demarrageAvecSauvegardeAbimee(
      'v1_vers_v2_sans_manifeste',
      (dossier) => File('$dossier/$nomFichierManifeste').deleteSync(),
      'Manifeste ABSENT',
      nomFichierAccuse: '',
      manifesteSupprime: true,
    );
  });

  test('12. fichier annoncé manquant dans la sauvegarde : restauration '
      'refusée, données vivantes intactes', () async {
    await demarrageAvecSauvegardeAbimee(
      'v1_vers_v2_fichier_manquant',
      (dossier) => File('$dossier/${HiveBoxes.transactions}.hive').deleteSync(),
      'ABSENT du dossier',
      nomFichierAccuse: HiveBoxes.transactions,
    );
  });

  test('13. fichier tronqué dans la sauvegarde : restauration refusée, '
      'données vivantes intactes', () async {
    await demarrageAvecSauvegardeAbimee(
      'v1_vers_v2_fichier_tronque',
      (dossier) => File(
        '$dossier/${HiveBoxes.depenses}.hive',
      ).writeAsBytes(const [1, 2, 3], flush: true),
      'tronqué ou modifié',
      nomFichierAccuse: HiveBoxes.depenses,
    );
  });

  test('14. fichier corrompu à taille constante (empreinte SHA-256) : '
      'restauration refusée, données vivantes intactes', () async {
    await demarrageAvecSauvegardeAbimee(
      'v1_vers_v2_fichier_corrompu',
      (dossier) {
        // Altération d'un octet SANS changer la taille : la vérification
        // de taille ne suffit pas, l'empreinte SHA-256 doit attraper
        // cette corruption silencieuse.
        final f = File('$dossier/${HiveBoxes.produits}.hive');
        final octets = f.readAsBytesSync();
        octets[octets.length - 1] = octets.last ^ 0xFF;
        f.writeAsBytesSync(octets, flush: true);
      },
      'CORROMPU',
      nomFichierAccuse: HiveBoxes.produits,
    );
  });

  test("15. interruption de restauration (fichiers vivants abîmés puis "
      'relance) : restauration complète validée, données rétablies', () async {
    await premierDemarrage();
    await grainerDonnees();
    final dossier = await preparerMigrationInterrompue(
      'v1_vers_v2_resto_crash',
    );
    final tailleProduitSauvegardee = File(
      '$dossier/${HiveBoxes.produits}.hive',
    ).lengthSync();

    // Crash « pendant la copie » : le fichier produits vivant est
    // à moitié écrit (débris) et le fichier transactions vivant n'a
    // pas encore été recopié (supprimé entre deux copies).
    await File(
      '${tempDir.path}/${HiveBoxes.produits}.hive',
    ).writeAsBytes(List<int>.filled(11, 0xFF), flush: true);
    await File('${tempDir.path}/${HiveBoxes.transactions}.hive').delete();

    final e = await redemarrageQuiEchoue();
    expect(e, isA<MigrationHiveInterrompueException>());
    final interrompue = e as MigrationHiveInterrompueException;
    expect(interrompue.restaurationEffectuee, isTrue);
    expect(interrompue.dossierSauvegarde, 'v1_vers_v2_resto_crash');

    // Données rétablies exactement, post-vérification d'intégrité
    // passée (sinon l'exception aurait reported restauration
    // échouée), fichier produits restauré à la taille sauvegardée.
    final etat = await etatCompletSurDisque();
    expect(etat['schemaVersion'], HiveService.schemaVersion);
    expect(etat['journalEtat'], isNull);
    expect((etat['produits'] as Map).keys, contains('p-1'));
    expect((etat['transactions'] as Map).keys, contains('t-1'));
    expect((etat['dettes'] as Map).keys, contains('d-1'));
    expect(
      File('${tempDir.path}/${HiveBoxes.produits}.hive').lengthSync(),
      tailleProduitSauvegardee,
    );
    // La sauvegarde reste conservée après restauration réussie.
    expect(Directory(dossier).existsSync(), isTrue);
  });

  test(
    'B. bump de version sans migration enregistrée : démarrage refusé '
    'explicitement, aucune donnée effacée (ancien comportement destructif)',
    () async {
      await premierDemarrage();
      await grainerDonnees();
      final avant = await etatCompletSurDisque();

      final e = await redemarrageQuiEchoue(versionCible: 2); // registre vide
      expect(e, isA<MigrationHiveManquanteException>());
      expect(e.toString(), contains('aucune migration'));
      expect(e.toString(), contains('Aucune donnée'));

      final apres = await etatCompletSurDisque();
      expect(apres['schemaVersion'], HiveService.schemaVersion);
      expect(apres, equals(avant));
    },
  );

  test('A. aucun appel destructif à Hive.deleteBoxFromDisk dans le '
      "mécanisme de versionnement", () {
    final service = File('lib/services/hive_service.dart').readAsStringSync();
    final migrations = File(
      'lib/services/hive_migrations.dart',
    ).readAsStringSync();
    expect(
      service,
      isNot(contains('deleteBoxFromDisk')),
      reason: 'HiveService ne doit plus contenir une seule suppression de box.',
    );
    expect(
      migrations,
      isNot(contains('deleteBoxFromDisk')),
      reason: 'Le mécanisme de migration ne doit jamais contenir ce mot.',
    );
    // Le filet de sécurité structurel est en place.
    expect(migrationsHive, isEmpty);
    expect(HiveService.schemaVersion, 1);
  });
}
