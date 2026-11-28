import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pin_provider.dart';
import '../screens/verrouillage/pin_lock_screen.dart';

/// Voile de verrouillage affiché **au-dessus** du Navigator de MaterialApp.
///
/// Utilisé dans `MaterialApp.builder`, il recouvre toutes les routes, les
/// feuilles modales et les dialogues déjà ouverts. Le contenu sous-jacent
/// est exclu du focus clavier et de la sémantique tant que le voile est
/// actif ; un [ModalBarrier] bloque les interactions tactiles.
class VerrouillageOverlay extends StatelessWidget {
  const VerrouillageOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<PinProvider>(
      builder: (context, pin, _) {
        final verrouille = pin.pret && pin.verrouille;
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: verrouille,
              child: ExcludeSemantics(excluding: verrouille, child: child),
            ),
            if (verrouille) const _Voile(),
          ],
        );
      },
    );
  }
}

class _Voile extends StatelessWidget {
  const _Voile();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        // Navigator imbriqué : un widget placé dans MaterialApp.builder n'a
        // pas d'Overlay ancêtre (celui du Navigator racine est un frère, pas
        // un parent). Sans cet Overlay, un appui long dans le champ PIN
        // planterait au moment d'afficher le menu de collage / les poignées
        // de sélection.
        //
        // `HeroControllerScope.none` : le Navigator racine de MaterialApp
        // installe un HeroController partagé ; un second Navigator ne peut
        // pas le réutiliser, et le voile n'a de toute façon aucune animation
        // Hero à jouer.
        HeroControllerScope.none(
          child: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const PinLockScreen(),
            ),
          ),
        ),
      ],
    );
  }
}
