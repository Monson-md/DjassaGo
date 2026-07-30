import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/hive_boxes.dart';
import '../models/devise.dart';
import '../models/dette.dart';
import '../models/item_vendu.dart';
import '../models/mode_paiement.dart';
import '../models/paiement_dette.dart';
import '../models/produit.dart';
import '../models/transaction.dart' as model;

/// Centralise l'initialisation de Hive : enregistrement des adapters
/// et ouverture des boxes typées. Doit être appelé une seule fois,
/// avant runApp(), dans main.dart.
class HiveService {
  HiveService._();

  static bool _initialise = false;

  /// Incrémenter cette valeur à chaque changement incompatible du schéma
  /// Hive (ex: un champ qui change de type). Voir ParametresKeys.schemaVersion.
  static const int schemaVersion = 1;

  static Future<void> init() async {
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

    // La box de paramètres est ouverte en premier et seule : elle stocke
    // des types primitifs (bool/String/int), jamais d'objets Hive
    // personnalisés, donc son ouverture ne peut pas échouer à cause d'un
    // schéma incompatible sur Produit/Transaction/Dette/Devise.
    final parametresBox = await Hive.openBox(HiveBoxes.parametres);
    final versionStockee =
        parametresBox.get(ParametresKeys.schemaVersion) as int?;
    if (versionStockee != null && versionStockee != schemaVersion) {
      // Schéma incompatible avec une version antérieure de l'app (ex:
      // un champ passé de double à int) : plutôt que de risquer une
      // exception de cast à la première lecture, on repart propre.
      // Acceptable ici : l'app n'a pas encore d'utilisateurs réels.
      debugPrint(
          'HiveService: schéma incompatible ($versionStockee -> $schemaVersion), '
          'réinitialisation des boxes de données locales.');
      await Hive.deleteBoxFromDisk(HiveBoxes.produits);
      await Hive.deleteBoxFromDisk(HiveBoxes.transactions);
      await Hive.deleteBoxFromDisk(HiveBoxes.dettes);
      await Hive.deleteBoxFromDisk(HiveBoxes.devises);
    }
    await parametresBox.put(ParametresKeys.schemaVersion, schemaVersion);

    await Future.wait([
      Hive.openBox<Produit>(HiveBoxes.produits),
      Hive.openBox<model.Transaction>(HiveBoxes.transactions),
      Hive.openBox<Dette>(HiveBoxes.dettes),
      Hive.openBox<Devise>(HiveBoxes.devises),
      Hive.openBox<PaiementDette>(HiveBoxes.paiementsDette),
    ]);

    _initialise = true;
  }

  static void _registerAdapterSiAbsent<T>(int typeId, TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  static Box<Produit> get produitsBox => Hive.box<Produit>(HiveBoxes.produits);

  static Box<model.Transaction> get transactionsBox =>
      Hive.box<model.Transaction>(HiveBoxes.transactions);

  static Box<Dette> get dettesBox => Hive.box<Dette>(HiveBoxes.dettes);

  static Box<Devise> get devisesBox => Hive.box<Devise>(HiveBoxes.devises);

  static Box<PaiementDette> get paiementsDetteBox =>
      Hive.box<PaiementDette>(HiveBoxes.paiementsDette);

  static Box get parametresBox => Hive.box(HiveBoxes.parametres);
}
