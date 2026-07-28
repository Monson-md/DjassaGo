import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// Bannière publicitaire discrète pour les écrans secondaires.
/// Ne s'affiche que si l'annonce a pu être chargée ; occupe un espace
/// fixe et minimal pour ne jamais perturber l'usage de l'application.
class BannierePub extends StatefulWidget {
  const BannierePub({super.key});

  @override
  State<BannierePub> createState() => _BanniereePubState();
}

class _BanniereePubState extends State<BannierePub> {
  BannerAd? _banniere;

  @override
  void initState() {
    super.initState();
    final ad = AdService.instance.creerBanniere(
      listener: BannerAdListener(
        onAdLoaded: (chargee) {
          if (mounted) setState(() => _banniere = chargee as BannerAd);
        },
        onAdFailedToLoad: (echouee, _) => echouee.dispose(),
      ),
    );
    ad?.load();
  }

  @override
  void dispose() {
    _banniere?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banniere = _banniere;
    if (banniere == null) return const SizedBox.shrink();
    return SizedBox(
      width: banniere.size.width.toDouble(),
      height: banniere.size.height.toDouble(),
      child: AdWidget(ad: banniere),
    );
  }
}
