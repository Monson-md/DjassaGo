import 'package:hive_flutter/hive_flutter.dart';

import '../config/hive_boxes.dart';
import '../models/devise.dart';
import '../models/dette.dart';
import '../models/item_vendu.dart';
import '../models/produit.dart';
import '../models/transaction.dart' as model;

/// Centralise l'initialisation de Hive : enregistrement des adapters
/// et ouverture des boxes typées. Doit être appelé une seule fois,
/// avant runApp(), dans main.dart.
class HiveService {
  HiveService._();

  static bool _initialise = false;

  static Future<void> init() async {
    if (_initialise) return;

    await Hive.initFlutter();

    _registerAdapterSiAbsent(0, DeviseAdapter());
    _registerAdapterSiAbsent(1, ProduitAdapter());
    _registerAdapterSiAbsent(2, ItemVenduAdapter());
    _registerAdapterSiAbsent(3, model.TransactionAdapter());
    _registerAdapterSiAbsent(4, StatutDetteAdapter());
    _registerAdapterSiAbsent(5, DetteAdapter());

    await Future.wait([
      Hive.openBox<Produit>(HiveBoxes.produits),
      Hive.openBox<model.Transaction>(HiveBoxes.transactions),
      Hive.openBox<Dette>(HiveBoxes.dettes),
      Hive.openBox<Devise>(HiveBoxes.devises),
      Hive.openBox(HiveBoxes.parametres),
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

  static Box get parametresBox => Hive.box(HiveBoxes.parametres);
}
