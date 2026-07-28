import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Intégration AdMob légère et non-bloquante.
///
/// Principes :
/// - Aucune publicité n'interrompt jamais le flux de vente (écran de Caisse).
/// - Les bannières sont discrètes et cantonnées à des écrans secondaires
///   (accueil, stock, dettes).
/// - Les interstitiels ne s'affichent qu'à des points de rupture naturels
///   (ex: après fermeture d'un reçu de vente) et sont limités dans le temps
///   pour ne jamais gêner un commerçant en pleine journée de vente.
///
/// Utilise des identifiants de TEST Google par défaut : à remplacer par les
/// vrais identifiants AdMob avant publication.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  static const Duration _delaiMinimumEntreInterstitiels = Duration(minutes: 15);

  bool _initialise = false;
  InterstitialAd? _interstitiel;
  DateTime? _dernierAffichageInterstitiel;

  static String get idBanniere {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return 'ca-app-pub-3940256099942544/6300978111';
  }

  static String get idInterstitiel {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  bool get _plateformeSupportee =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialise le SDK AdMob. Échoue silencieusement si la plateforme
  /// n'est pas supportée ou si AdMob n'est pas configuré nativement,
  /// pour ne jamais bloquer le démarrage de l'application.
  Future<void> initialiser() async {
    if (_initialise || !_plateformeSupportee) return;
    try {
      await MobileAds.instance.initialize();
      _initialise = true;
      _precharger();
    } catch (_) {
      _initialise = false;
    }
  }

  /// Crée une bannière prête à être chargée par l'appelant (widget).
  /// Ne charge pas automatiquement : c'est au widget de contrôler le
  /// cycle de vie via son propre [BannerAdListener].
  BannerAd? creerBanniere({
    AdSize taille = AdSize.banner,
    BannerAdListener? listener,
  }) {
    if (!_initialise) return null;
    return BannerAd(
      adUnitId: idBanniere,
      size: taille,
      request: const AdRequest(),
      listener: listener ?? const BannerAdListener(),
    );
  }

  void _precharger() {
    if (!_initialise) return;
    InterstitialAd.load(
      adUnitId: idInterstitiel,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitiel = ad,
        onAdFailedToLoad: (_) => _interstitiel = null,
      ),
    );
  }

  /// Affiche un interstitiel uniquement si un délai raisonnable s'est
  /// écoulé depuis le dernier affichage, afin de ne jamais harceler le
  /// commerçant. À appeler uniquement depuis des écrans secondaires,
  /// jamais pendant la saisie d'une vente.
  Future<void> afficherInterstitielSiOpportun() async {
    if (!_initialise || _interstitiel == null) return;

    final maintenant = DateTime.now();
    if (_dernierAffichageInterstitiel != null &&
        maintenant.difference(_dernierAffichageInterstitiel!) <
            _delaiMinimumEntreInterstitiels) {
      return;
    }

    final ad = _interstitiel!;
    _interstitiel = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _precharger();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _precharger();
      },
    );
    _dernierAffichageInterstitiel = maintenant;
    await ad.show();
  }
}
