import 'package:flutter/widgets.dart';

/// Emplacement publicitaire neutre.
///
/// Google Mobile Ads a été retiré du projet (voir CHECKLIST.md et
/// lib/services/ad_service.dart) : ce widget n'affiche donc jamais rien
/// pour l'instant. Il garde son nom et sa position dans les écrans pour
/// qu'une vraie bannière puisse être réintroduite au même endroit plus
/// tard, sans toucher aux écrans qui l'utilisent.
class BannierePub extends StatelessWidget {
  const BannierePub({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
