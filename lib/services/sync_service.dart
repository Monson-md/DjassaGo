import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config/hive_boxes.dart';
import '../models/dette.dart';
import '../models/produit.dart';
import 'hive_service.dart';

/// Service de synchronisation en arrière-plan.
///
/// Écoute la connectivité réseau et, dès qu'une connexion est rétablie,
/// pousse vers Firestore toutes les données locales (produits, ventes,
/// dettes) qui n'ont pas encore été synchronisées.
///
/// Le service reste totalement silencieux et non-bloquant si Firebase
/// n'a pas été configuré pour ce projet (aucun firebase_options.dart) :
/// l'application continue de fonctionner 100% hors-ligne.
class SyncService {
  StreamSubscription<List<ConnectivityResult>>? _abonnementConnectivite;
  bool _synchronisationEnCours = false;

  bool get _firebaseDisponible => Firebase.apps.isNotEmpty;

  Future<void> demarrer() async {
    _abonnementConnectivite ??=
        Connectivity().onConnectivityChanged.listen((resultats) {
      final estConnecte =
          resultats.any((r) => r != ConnectivityResult.none);
      if (estConnecte) {
        synchroniserMaintenant();
      }
    });

    final resultatInitial = await Connectivity().checkConnectivity();
    if (resultatInitial.any((r) => r != ConnectivityResult.none)) {
      unawaited(synchroniserMaintenant());
    }
  }

  void arreter() {
    _abonnementConnectivite?.cancel();
    _abonnementConnectivite = null;
  }

  /// Déclenche une synchronisation immédiate. Ne fait rien si Firebase
  /// n'est pas configuré ou si une synchronisation est déjà en cours.
  Future<void> synchroniserMaintenant() async {
    if (!_firebaseDisponible || _synchronisationEnCours) return;

    _synchronisationEnCours = true;
    try {
      final commerceId = await _idCommerce();
      await Future.wait([
        _synchroniserProduits(commerceId),
        _synchroniserDettes(commerceId),
        _synchroniserTransactions(commerceId),
      ]);
    } catch (_) {
      // Échec silencieux : on retentera à la prochaine reconnexion.
    } finally {
      _synchronisationEnCours = false;
    }
  }

  Future<String> _idCommerce() async {
    final box = HiveService.parametresBox;
    var id = box.get('commerce_id') as String?;
    if (id == null) {
      id = DateTime.now().microsecondsSinceEpoch.toString();
      await box.put('commerce_id', id);
    }
    return id;
  }

  CollectionReference<Map<String, dynamic>> _collection(
      String commerceId, String nom) {
    return FirebaseFirestore.instance
        .collection('commercants')
        .doc(commerceId)
        .collection(nom);
  }

  Future<void> _synchroniserProduits(String commerceId) async {
    final box = HiveService.produitsBox;
    final aEnvoyer =
        box.values.where((p) => !p.synchronise).toList(growable: false);
    if (aEnvoyer.isEmpty) return;

    final collection = _collection(commerceId, HiveBoxes.produits);
    for (final Produit produit in aEnvoyer) {
      await collection.doc(produit.id).set(produit.toMap());
      produit.synchronise = true;
      await produit.save();
    }
  }

  Future<void> _synchroniserDettes(String commerceId) async {
    final box = HiveService.dettesBox;
    final aEnvoyer =
        box.values.where((d) => !d.synchronise).toList(growable: false);
    if (aEnvoyer.isEmpty) return;

    final collection = _collection(commerceId, HiveBoxes.dettes);
    for (final Dette dette in aEnvoyer) {
      await collection.doc(dette.id).set(dette.toMap());
      dette.synchronise = true;
      await dette.save();
    }
  }

  Future<void> _synchroniserTransactions(String commerceId) async {
    final box = HiveService.transactionsBox;
    final aEnvoyer =
        box.values.where((t) => !t.synchronise).toList(growable: false);
    if (aEnvoyer.isEmpty) return;

    final collection = _collection(commerceId, HiveBoxes.transactions);
    for (final transaction in aEnvoyer) {
      await collection.doc(transaction.id).set(transaction.toMap());
      transaction.synchronise = true;
      await transaction.save();
    }
  }
}
