import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Signature visuelle de l'app : une bande de 5px de rayures verticales
/// ocre / vert / brique / encre, répétée à l'identique. Apparaît sous
/// l'en-tête de chaque écran. Ne jamais l'agrandir, la colorer autrement
/// ou l'animer (voir DESIGN.md) : c'est la seule constante visuelle
/// volontairement figée de l'app.
class BandeRayee extends StatelessWidget {
  const BandeRayee({super.key});

  static const _couleurs = [
    CaisseColors.ocre,
    CaisseColors.vert,
    CaisseColors.brique,
    CaisseColors.encre,
  ];

  static const _nombreBandes = 20;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: Row(
        children: List.generate(
          _nombreBandes,
          (i) => Expanded(child: ColoredBox(color: _couleurs[i % 4])),
        ),
      ),
    );
  }
}
