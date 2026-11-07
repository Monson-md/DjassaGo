// Mission C4 : restauration sécurisée d'une sauvegarde
// (BackupService.restaurer). Couvre :
// - validation complète EN MÉMOIRE avant la moindre écriture (version de
//   format, enregistrements corrompus, identifiants, références) ;
// - modes remplacer (élagage) et fusion (aucune suppression) ;
// - rollback en mémoire sur échec injecté ;
// - point de restauration durable + rotation (3 fichiers conservés).
// Correction C4 : une collection ABSENTE du fichier (ex: sauvegarde v1)
// ne déclenche JAMAIS l'élagage de sa box ; une collection PRÉSENTE mais
// vide reste un élagage normal (vérifié en relisant depuis le disque).

import 'dart:convert';
import 'dart:io';

import 'package:caisse_de_poche/models/categorie_depense.dart';
import 'package:caisse_de_poche/models/conditionnement.dart';
import 'package:caisse_de_poche/models/depense.dart';
import 'package:caisse_de_poche/models/dette.dart';
import 'package:caisse_de_poche/models/paiement_dette.dart';
import 'package:caisse_de_poche/models/produit.dart';
import 'package:caisse_de_poche/models/transaction.dart' as model;
import 'package:caisse_de_poche/services/backup_service.dart';
import 'package:caisse_de_poche/services/conditionnement_service.dart';
import 'package:caisse_de_poche/services/hive_service.dart';
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

Directory _dossierPointsRestauration(Directory documents) =>
    Directory('${documents.path}/restaurations_auto');

Map<String, dynamic> _produitJson(
  String id, {
  String nom = 'Produit',
  double prixAchat = 500,
  double prixVente = 700,
  int stockActuel = 10,
}) => {
  'id': id,
  'nom': nom,
  'prixAchat': prixAchat,
  'prixVente': prixVente,
  'stockActuel': stockActuel,
  'devise': 'XOF',
  'dateCreation': '2026-01-01T08:00:00.000',
  'dateModification': null,
  'synchronise': false,
  'prixAchatMineur': prixAchat.toInt(),
  'prixVenteMineur': prixVente.toInt(),
  'deviceId': '',
  'lastModified': null,
  'uniteBase': 'unité',
};

Map<String, dynamic> _transactionJson(String id, {double total = 2000}) => {
  'id': id,
  'date': '2026-01-03T10:00:00.000',
  'itemsVendus': [],
  'montantTotal': total,
  'margeBrute': 500,
  'devise': 'XOF',
  'synchronise': false,
  'montantTotalMineur': total.toInt(),
  'margeBruteMineur': 500,
  'modePaiement': 'especes',
  'annulee': false,
  'dateAnnulation': null,
  'motifAnnulation': null,
  'deviceId': '',
  'lastModified': null,
};

Map<String, dynamic> _detteJson(String id, {double montantDu = 3000}) => {
  'id': id,
  'nomClient': 'Kouassi',
  'telephone': '',
  'montantDu': montantDu,
  'dateDette': '2026-01-02T09:00:00.000',
  'statut': 'enCours',
  'devise': 'XOF',
  'montantInitial': montantDu,
  'note': null,
  'synchronise': false,
  'montantDuMineur': montantDu.toInt(),
  'montantInitialMineur': montantDu.toInt(),
  'transactionId': null,
  'deviceId': '',
  'lastModified': null,
};

Map<String, dynamic> _paiementJson(
  String id,
  String detteId, {
  double montant = 1000,
}) => {
  'id': id,
  'detteId': detteId,
  'montant': montant,
  'date': '2026-01-05T10:00:00.000',
  'devise': 'XOF',
  'montantMineur': montant.toInt(),
  'deviceId': '',
  'lastModified': null,
};

Map<String, dynamic> _conditionnementJson(
  String id,
  String produitId, {
  String nom = 'Unité',
  int quantite = 1,
  double prixVente = 700,
}) => {
  'id': id,
  'produitId': produitId,
  'nom': nom,
  'quantiteEnUniteBase': quantite,
  'prixVente': prixVente,
  'parDefaut': true,
  'devise': 'XOF',
  'prixVenteMineur': prixVente.toInt(),
  'deviceId': '',
  'lastModified': null,
};

/// Construit une sauvegarde complète ; les collections facultatives
/// (paiementsDette, depenses, conditionnements) sont absentes tant que
/// l'appelant ne les passe pas — comme dans une vraie sauvegarde v1.
Map<String, dynamic> _sauvegardeJson({
  required int version,
  List<Map<String, dynamic>>? produits,
  List<Map<String, dynamic>>? transactions,
  List<Map<String, dynamic>>? dettes,
  List<Map<String, dynamic>>? paiementsDette,
  List<Map<String, dynamic>>? depenses,
  List<Map<String, dynamic>>? conditionnements,
}) => {
  'formatVersion': version,
  'exporteLe': '2026-01-04T10:00:00.000',
  'produits': produits ?? <Map<String, dynamic>>[],
  'transactions': transactions ?? <Map<String, dynamic>>[],
  'dettes': dettes ?? <Map<String, dynamic>>[],
  'paiementsDette': ?paiementsDette,
  'depenses': ?depenses,
  'conditionnements': ?conditionnements,
};

Future<File> _ecrireSauvegarde(
  Directory dossier,
  Map<String, dynamic> contenu, {
  String nom = 'sauvegarde.json',
}) async {
  final fichier = File('${dossier.path}/$nom');
  await fichier.writeAsString(jsonEncode(contenu));
  return fichier;
}

/// Pré-remplit une donnée locale déterministe (pas de uuid pris du hasard :
/// les clés attendues après import doivent être connues).
Future<void> _produitLocal(String id, {String nom = 'Local'}) async {
  await HiveService.produitsBox.put(
    id,
    Produit(
      id: id,
      nom: nom,
      prixAchat: 100,
      prixVente: 150,
      stockActuel: 5,
      devise: 'XOF',
    ),
  );
}

Future<void> _transactionLocal(String id) async {
  await HiveService.transactionsBox.put(
    id,
    model.Transaction(
      id: id,
      date: DateTime(2026, 1, 3),
      itemsVendus: [],
      montantTotal: 150,
      margeBrute: 50,
      devise: 'XOF',
    ),
  );
}

Future<void> _depenseLocale(String id) async {
  await HiveService.depensesBox.put(
    id,
    Depense(
      id: id,
      libelle: 'Transport',
      montant: 500,
      date: DateTime(2026, 1, 6),
      categorie: CategorieDepense.transport,
      devise: 'XOF',
    ),
  );
}

Future<void> _detteLocale(String id) async {
  await HiveService.dettesBox.put(
    id,
    Dette(
      id: id,
      nomClient: 'Kouassi',
      telephone: '',
      montantDu: 3000,
      devise: 'XOF',
      dateDette: DateTime(2026, 1, 2),
    ),
  );
}

Future<void> _paiementLocal(String id, String detteId) async {
  await HiveService.paiementsDetteBox.put(
    id,
    PaiementDette(
      id: id,
      detteId: detteId,
      montant: 1000,
      date: DateTime(2026, 1, 7),
      devise: 'XOF',
    ),
  );
}

Future<void> _conditionnementLocal(String id, String produitId) async {
  await HiveService.conditionnementsBox.put(
    id,
    Conditionnement(
      id: id,
      produitId: produitId,
      nom: 'Unité',
      quantiteEnUniteBase: 1,
      prixVente: 150,
      parDefaut: true,
      devise: 'XOF',
    ),
  );
}

/// Ferme toutes les boxes puis les rouvre depuis le disque : les valeurs
/// relues ne sont plus celles tenues en mémoire — si une donnée n'a pas
/// été écrite (ou a été effacée) sur disque, le test le voit.
Future<void> rouvrirBoxesDepuisDisque() async {
  await Hive.close();
  HiveService.reinitialiserPourTest();
  await HiveService.init();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'caisse_de_poche_restauration_c4_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir);
    await Hive.close();
    HiveService.reinitialiserPourTest();
    await HiveService.init();
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

  test('une version plus récente que le format courant est refusée : '
      'données locales inchangées', () async {
    await _produitLocal('prod-local');
    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(
        version: BackupService.formatVersion + 1,
        produits: [_produitJson('p-futur')],
      ),
      nom: 'v3.json',
    );
    final backup = BackupService();

    await expectLater(
      backup.restaurer(fichier, remplacer: true),
      throwsA(isA<VersionSauvegardeNonSupporteeException>()),
    );

    expect(HiveService.produitsBox.keys, ['prod-local']);
    expect(HiveService.produitsBox.get('p-futur'), isNull);
    // Refus de pure validation : même le point de restauration n'a pas
    // été écrit, aucune donnée n'a bougé. Aucune écriture : même le
    // dossier des points de restauration n'existe pas encore.
    expect(_dossierPointsRestauration(tempDir).existsSync(), isFalse);
  });

  test(
    'formatVersion absent, chaîne, 0 ou négative : refusé sans écriture',
    () async {
      await _produitLocal('prod-local');
      final backup = BackupService();

      final casInvalides = <String, Map<String, dynamic>>{
        // formatVersion absent : format méconnaissable.
        'absente': {
          'exporteLe': '2026-01-04T10:00:00.000',
          'produits': [_produitJson('p-1')],
          'transactions': [],
          'dettes': [],
        },
        // Une valeur non entière (chaîne, décimal) n'est pas un format.
        'chaine': {
          'formatVersion': '2',
          'produits': [_produitJson('p-1')],
          'transactions': [],
          'dettes': [],
        },
        'zero': {
          'formatVersion': 0,
          'produits': [_produitJson('p-1')],
          'transactions': [],
          'dettes': [],
        },
        'negatif': {
          'formatVersion': -1,
          'produits': [_produitJson('p-1')],
          'transactions': [],
          'dettes': [],
        },
      };

      for (final cas in casInvalides.entries) {
        final fichier = await _ecrireSauvegarde(
          tempDir,
          cas.value,
          nom: '${cas.key}.json',
        );
        final rejet = backup.restaurer(fichier, remplacer: true);
        if (cas.key == 'absente' || cas.key == 'chaine') {
          await expectLater(rejet, throwsA(isA<FormatException>()));
        } else {
          await expectLater(
            rejet,
            throwsA(isA<VersionSauvegardeNonSupporteeException>()),
          );
        }
      }

      expect(HiveService.produitsBox.keys, ['prod-local']);
      // Refusés en pure validation : aucun point de restauration écrit.
      expect(_dossierPointsRestauration(tempDir).existsSync(), isFalse);
    },
  );

  test(
    'une sauvegarde v1 sans paiementsDette ni depenses est acceptée',
    () async {
      final fichier = await _ecrireSauvegarde(
        tempDir,
        _sauvegardeJson(
          version: 1,
          produits: [_produitJson('p-ancien', nom: 'Farine')],
        ),
        nom: 'v1.json',
      );
      final backup = BackupService();

      await backup.restaurer(fichier, remplacer: true);

      final produit = HiveService.produitsBox.get('p-ancien');
      expect(produit, isNotNull);
      expect(produit!.nom, 'Farine');
      expect(HiveService.paiementsDetteBox.length, 0);
      expect(HiveService.depensesBox.length, 0);
      // Le produit v1 reçoit bien son conditionnement de quantité 1.
      final conditionnements = ConditionnementService().listerPour('p-ancien');
      expect(conditionnements, hasLength(1));
      expect(conditionnements.first.quantiteEnUniteBase, 1);
    },
  );

  test('une transaction corrompue est refusée en mode remplacer : '
      'boxes intactes', () async {
    await _produitLocal('prod-local');
    final transactionCorrompue = _transactionJson('t-1')
      ..['montantTotal'] = 'deux-mille';
    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(version: 2, transactions: [transactionCorrompue]),
      nom: 'transaction_corrompue.json',
    );
    final backup = BackupService();

    await expectLater(
      backup.restaurer(fichier, remplacer: true),
      throwsA(isA<SauvegardeInvalideException>()),
    );

    // Le refus a eu lieu avant l'écriture : rien n'a été vidé ni modifié.
    expect(HiveService.produitsBox.keys, ['prod-local']);
    expect(HiveService.transactionsBox.length, 0);
    expect(HiveService.dettesBox.length, 0);
  });

  test('un conditionnement corrompu est refusé avant toute écriture', () async {
    final conditionnementCorrompu = _conditionnementJson('c-1', 'p-importe')
      ..['quantiteEnUniteBase'] = null;
    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(
        version: 2,
        produits: [_produitJson('p-importe')],
        conditionnements: [conditionnementCorrompu],
      ),
      nom: 'conditionnement_corrompu.json',
    );
    final backup = BackupService();

    await expectLater(
      backup.restaurer(fichier, remplacer: true),
      throwsA(isA<SauvegardeInvalideException>()),
    );

    expect(HiveService.produitsBox.length, 0);
    expect(HiveService.conditionnementsBox.length, 0);
  });

  test(
    'identifiants vides ou dupliqués dans une même collection : refusés',
    () async {
      final backup = BackupService();

      final duplique = await _ecrireSauvegarde(
        tempDir,
        _sauvegardeJson(
          version: 2,
          produits: [
            _produitJson('p-double', nom: 'Premier'),
            _produitJson('p-double', nom: 'Deuxième'),
          ],
        ),
        nom: 'duplique.json',
      );
      await expectLater(
        backup.restaurer(duplique, remplacer: true),
        throwsA(isA<SauvegardeInvalideException>()),
      );

      final vide = await _ecrireSauvegarde(
        tempDir,
        _sauvegardeJson(version: 2, produits: [_produitJson('')]),
        nom: 'vide.json',
      );
      await expectLater(
        backup.restaurer(vide, remplacer: true),
        throwsA(isA<SauvegardeInvalideException>()),
      );

      // Hive écraserait silencieusement un même id : ici rien n'est écrit.
      expect(HiveService.produitsBox.length, 0);
    },
  );

  test('référence orpheline : refusée en mode remplacer, acceptée en mode '
      'fusion si la référence existe localement', () async {
    final backup = BackupService();
    // Une dette locale existe, mais PAS celle référencée par le paiement.
    await HiveService.dettesBox.put(
      'dette-locale',
      Dette(
        id: 'dette-locale',
        nomClient: 'Kouassi',
        telephone: '',
        montantDu: 3000,
        devise: 'XOF',
        dateDette: DateTime(2026, 1, 2),
      ),
    );
    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(
        version: 2,
        paiementsDette: [_paiementJson('pm-1', 'dette-absente')],
      ),
      nom: 'orpheline.json',
    );

    // Remplacer : la dette locale va disparaître — la référence deviendrait
    // orpheline, refus.
    await expectLater(
      backup.restaurer(fichier, remplacer: true),
      throwsA(isA<SauvegardeInvalideException>()),
    );
    expect(HiveService.paiementsDetteBox.length, 0);

    // Fusion : le local subsiste — mais la référence doit exister
    // localement, sinon refus aussi.
    await expectLater(
      backup.restaurer(fichier, remplacer: false),
      throwsA(isA<SauvegardeInvalideException>()),
    );
    expect(HiveService.paiementsDetteBox.length, 0);

    // Fusion vers une dette qui existe localement : accepté.
    final fichierValide = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(
        version: 2,
        paiementsDette: [_paiementJson('pm-1', 'dette-locale')],
      ),
      nom: 'fusion_valide.json',
    );
    await backup.restaurer(fichierValide, remplacer: false);
    expect(HiveService.paiementsDetteBox.get('pm-1'), isNotNull);
    expect(HiveService.dettesBox.keys, ['dette-locale']);
  });

  test('mode remplacer réussi : anciennes données absentes du fichier '
      'supprimées, conditionnement par défaut créé pour un produit sans '
      'conditionnement', () async {
    await _produitLocal('prod-local');
    // Une transaction locale, absente du fichier : doit être élaguée.
    await _transactionLocal('txn-old');
    final backup = BackupService();

    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(
        version: 2,
        produits: [_produitJson('p-importe', nom: 'Savon', prixVente: 800)],
      ),
      nom: 'remplacer.json',
    );

    await backup.restaurer(fichier, remplacer: true);

    // L'ancien produit n'est plus (absent du fichier).
    expect(HiveService.produitsBox.keys, ['p-importe']);
    // La transaction locale absente du fichier a été élaguée.
    expect(HiveService.transactionsBox.length, 0);
    final savon = HiveService.produitsBox.get('p-importe');
    expect(savon, isNotNull);
    expect(savon!.nom, 'Savon');

    // Le produit importé sans conditionnement reçoit son conditionnement
    // par défaut : quantité 1, au prix de vente importé.
    final conditionnements = ConditionnementService().listerPour('p-importe');
    expect(conditionnements, hasLength(1));
    expect(conditionnements.first.quantiteEnUniteBase, 1);
    expect(conditionnements.first.prixVente, 800);
    expect(conditionnements.first.parDefaut, isTrue);
  });

  test('rollback après échec injecté après l\'écriture des produits : '
      'données d\'origine restaurées (donneesRestaurees: true)', () async {
    await _produitLocal('prod-local');
    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(version: 2, produits: [_produitJson('p-importe')]),
      nom: 'rollback_produits.json',
    );
    final backup = BackupService();

    RestaurationSauvegardeEchoueeException? echec;
    try {
      await backup.restaurer(
        fichier,
        remplacer: true,
        echecApresEtape: 'ecriture_produits',
      );
      fail('La restauration devait échouer (échec injecté).');
    } on RestaurationSauvegardeEchoueeException catch (e) {
      echec = e;
    }

    expect(echec, isNotNull);
    expect(echec.donneesRestaurees, isTrue);
    expect(echec.cheminPointRestauration, isNotNull);
    expect(File(echec.cheminPointRestauration!).existsSync(), isTrue);

    // Le cliché (pris avant la moindre écriture) a été réécrit : le
    // produit importé est parti, le produit local est revenu.
    expect(HiveService.produitsBox.keys, ['prod-local']);
  });

  test('rollback après échec injecté après l\'élagage : enregistrements '
      'supprimés restaurés', () async {
    await _produitLocal('prod-local');
    await _produitLocal('prod-encore', nom: 'Encore');
    // Transaction locale absente du fichier : élaguée puis restaurée.
    await _transactionLocal('txn-local');
    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(
        version: 2,
        produits: [_produitJson('p-importe')],
        transactions: [_transactionJson('t-importe')],
      ),
      nom: 'rollback_elagage.json',
    );
    final backup = BackupService();

    RestaurationSauvegardeEchoueeException? echec;
    try {
      await backup.restaurer(
        fichier,
        remplacer: true,
        echecApresEtape: 'elagage',
      );
      fail('La restauration devait échouer (échec injecté).');
    } on RestaurationSauvegardeEchoueeException catch (e) {
      echec = e;
    }

    expect(echec, isNotNull);
    expect(echec.donneesRestaurees, isTrue);

    // L'élagage a bien supprimé les enregistrements locaux absents du
    // fichier ; le rollback les a tous remis, et les importés sont partis.
    expect(HiveService.produitsBox.keys.toSet(), {'prod-local', 'prod-encore'});
    expect(HiveService.produitsBox.get('p-importe'), isNull);
    expect(HiveService.transactionsBox.get('t-importe'), isNull);
    expect(HiveService.transactionsBox.get('txn-local'), isNotNull);
  });

  test('mode fusion réussi : le local absent du fichier est conservé, '
      'un enregistrement de même id est écrasé', () async {
    await _produitLocal('prod-local');
    await _produitLocal('prod-commun', nom: 'VersionLocale');
    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(
        version: 2,
        produits: [
          _produitJson('prod-commun', nom: 'VersionImportee', prixVente: 999),
          _produitJson('prod-fichier', nom: 'Nouveau'),
        ],
      ),
      nom: 'fusion.json',
    );
    final backup = BackupService();

    await backup.restaurer(fichier, remplacer: false);

    // putAll = upsert : le local absent du fichier subsiste,
    // le même id est écrasé par la version importée.
    expect(HiveService.produitsBox.keys.toSet(), {
      'prod-local',
      'prod-commun',
      'prod-fichier',
    });
    expect(HiveService.produitsBox.get('prod-local')!.nom, 'Local');
    expect(HiveService.produitsBox.get('prod-commun')!.nom, 'VersionImportee');
    expect(HiveService.produitsBox.get('prod-fichier')!.nom, 'Nouveau');
  });

  test('mode fusion : rollback après échec injecté, données locales '
      'd\'origine restaurées', () async {
    await _produitLocal('prod-local');
    await _produitLocal('prod-commun', nom: 'VersionLocale');
    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(
        version: 2,
        produits: [
          _produitJson('prod-commun', nom: 'VersionImportee'),
          _produitJson('prod-fichier'),
        ],
        dettes: [_detteJson('dette-importee')],
      ),
      nom: 'fusion_rollback.json',
    );
    final backup = BackupService();

    RestaurationSauvegardeEchoueeException? echec;
    try {
      await backup.restaurer(
        fichier,
        remplacer: false,
        echecApresEtape: 'ecriture_dettes',
      );
      fail('La restauration devait échouer (échec injecté).');
    } on RestaurationSauvegardeEchoueeException catch (e) {
      echec = e;
    }

    expect(echec, isNotNull);
    expect(echec.donneesRestaurees, isTrue);

    // Le cliché a été réécrit : produits d'origine, dette importée
    // retirée, aucun conditionnement créé (la migration n'a pas eu lieu).
    expect(HiveService.produitsBox.keys.toSet(), {'prod-local', 'prod-commun'});
    expect(HiveService.produitsBox.get('prod-commun')!.nom, 'VersionLocale');
    expect(HiveService.dettesBox.length, 0);
    expect(HiveService.conditionnementsBox.length, 0);
  });

  test('un point de restauration est créé avant l\'import, sans toucher à '
      'derniere_sauvegarde_le, et conservé après échec', () async {
    await _produitLocal('prod-local');
    await HiveService.parametresBox.put(
      'derniere_sauvegarde_le',
      '2026-01-01T00:00:00',
    );
    final backup = BackupService();

    final fichier = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(version: 2, produits: [_produitJson('p-importe')]),
      nom: 'point_restauration.json',
    );

    await backup.restaurer(fichier, remplacer: false);

    // Le point contient l'état d'avant import, au format export.
    final points = _dossierPointsRestauration(
      tempDir,
    ).listSync().whereType<File>().toList();
    expect(points, hasLength(1));
    final contenu =
        jsonDecode(await points.single.readAsString()) as Map<String, dynamic>;
    expect(contenu['formatVersion'], BackupService.formatVersion);
    expect(
      (contenu['produits'] as List).map((p) => p['id']),
      contains('prod-local'),
    );
    // dernierSauvegardeLe n'est PAS modifié par un import.
    expect(
      backup.derniereSauvegardeLe(),
      DateTime.parse('2026-01-01T00:00:00'),
    );

    // Un échec en cours d'import laisse le point disponible.
    final fichier2 = await _ecrireSauvegarde(
      tempDir,
      _sauvegardeJson(version: 2, produits: [_produitJson('p-autre')]),
      nom: 'point_restauration_echec.json',
    );
    RestaurationSauvegardeEchoueeException? echec;
    try {
      await backup.restaurer(
        fichier2,
        remplacer: true,
        echecApresEtape: 'ecriture_produits',
      );
      fail('La restauration devait échouer (échec injecté).');
    } on RestaurationSauvegardeEchoueeException catch (e) {
      echec = e;
    }
    expect(echec.donneesRestaurees, isTrue);
    expect(File(echec.cheminPointRestauration!).existsSync(), isTrue);

    final pointsApres = _dossierPointsRestauration(
      tempDir,
    ).listSync().whereType<File>().toList();
    expect(pointsApres, hasLength(2));
    for (final point in pointsApres) {
      expect(point.existsSync(), isTrue);
    }
  });

  test(
    'rotation : seuls les 3 derniers points de restauration subsistent',
    () async {
      await _produitLocal('prod-local');
      final backup = BackupService();
      final fichier = await _ecrireSauvegarde(
        tempDir,
        _sauvegardeJson(version: 2, produits: [_produitJson('p-importe')]),
        nom: 'rotation.json',
      );

      final cheminsCrees = <String>[];
      for (var i = 0; i < 5; i++) {
        cheminsCrees.add(await backup.restaurer(fichier, remplacer: false));
      }

      final points = _dossierPointsRestauration(
        tempDir,
      ).listSync().whereType<File>().toList();
      expect(points, hasLength(3));
      // Les deux plus anciens sont partis, les trois derniers sont là.
      // (Chemins normalisés : Windows mélange '/' et '\' selon l'API.)
      String normaliser(String chemin) => chemin.replaceAll('\\', '/');
      final restants = points.map((f) => normaliser(f.path)).toSet();
      expect(restants, cheminsCrees.map(normaliser).toSet().skip(2));
      // Et le tout dernier point de restauration est toujours conservé.
      final dernier = File(cheminsCrees.last);
      expect(dernier.existsSync(), isTrue);
    },
  );

  test('mode remplacer avec une sauvegarde v1 (sans depenses, '
      'paiementsDette ni conditionnements) : les données locales de ces '
      'boxes sont conservées, y compris sur disque', () async {
    await _produitLocal('prod-local');
    await _depenseLocale('dep-local');
    await _detteLocale('dette-locale');
    await _paiementLocal('pm-local', 'dette-locale');
    await _conditionnementLocal('cond-local', 'prod-local');
    final backup = BackupService();
    final fichier = await _ecrireSauvegarde(
      tempDir,
      // Sauvegarde v1 : les trois collections facultatives n'existent pas
      // dans le fichier — il ne parle pas d'elles.
      _sauvegardeJson(
        version: 1,
        produits: [_produitJson('p-importe', nom: 'Importe')],
      ),
      nom: 'v1_conservation.json',
    );

    await backup.restaurer(fichier, remplacer: true);

    // Relecture DEPUIS LE DISQUE : fermeture puis réouverture des boxes.
    await rouvrirBoxesDepuisDisque();

    // Les dépenses, paiements et conditionnements locaux ont SURVÉCU à
    // l'import en mode remplacer : collection ABSENTE du fichier = la box
    // n'est JAMAIS élaguée, le fichier n'a rien affirmé à son sujet.
    expect(HiveService.produitsBox.keys, ['p-importe']);
    final depense = HiveService.depensesBox.get('dep-local');
    expect(depense, isNotNull);
    expect(depense!.libelle, 'Transport');
    expect(depense.montant, 500);
    final paiement = HiveService.paiementsDetteBox.get('pm-local');
    expect(paiement, isNotNull);
    expect(paiement!.detteId, 'dette-locale');
    final conditionnement = HiveService.conditionnementsBox.get('cond-local');
    expect(conditionnement, isNotNull);
    expect(conditionnement!.produitId, 'prod-local');
    expect(conditionnement.quantiteEnUniteBase, 1);

    // Le produit importé reçoit quand même son conditionnement par défaut.
    final parDefaut = ConditionnementService().listerPour('p-importe');
    expect(parDefaut, hasLength(1));
    expect(parDefaut.first.parDefaut, isTrue);
  });

  test('mode remplacer avec des dépenses [] PRÉSENTES : élagage normal des '
      'dépenses, paiementsDette ABSENTS du fichier conservés — y compris '
      'sur disque', () async {
    await _produitLocal('prod-local');
    await _depenseLocale('dep-local');
    await _detteLocale('dette-locale');
    await _paiementLocal('pm-local', 'dette-locale');
    await _conditionnementLocal('cond-local', 'prod-local');
    final backup = BackupService();
    final fichier = await _ecrireSauvegarde(
      tempDir,
      // v2 : `depenses: []` et `conditionnements: []` PRÉSENTS (le fichier
      // affirme qu'il n'y en a aucun) ; `paiementsDette` ABSENT (le
      // fichier ne parle pas des paiements).
      _sauvegardeJson(
        version: 2,
        produits: [_produitJson('p-importe', nom: 'Importe')],
        depenses: [],
        conditionnements: [],
      ),
      nom: 'depenses_vides.json',
    );

    await backup.restaurer(fichier, remplacer: true);

    // Relecture DEPUIS LE DISQUE : fermeture puis réouverture des boxes.
    await rouvrirBoxesDepuisDisque();

    // Liste PRÉSENTE mais vide = élagage normal : les dépenses locales
    // sont supprimées (le fichier affirme qu'il n'y en a aucune).
    expect(HiveService.depensesBox.length, 0);
    expect(HiveService.depensesBox.get('dep-local'), isNull);
    // La collection conditionnements PRÉSENTE mais vide : cond-local est
    // élagué aussi.
    expect(HiveService.conditionnementsBox.get('cond-local'), isNull);
    // Collection paiementsDette ABSENTE du fichier : les paiements locaux
    // survivent à l'import.
    final paiement = HiveService.paiementsDetteBox.get('pm-local');
    expect(paiement, isNotNull);
    expect(paiement!.detteId, 'dette-locale');
  });
}
