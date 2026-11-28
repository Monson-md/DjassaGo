import 'package:flutter/widgets.dart';

import '../providers/pin_provider.dart';

/// Observateur de bouton retour et de cycle de vie placé **au-dessus** de
/// MaterialApp.
///
/// `WidgetsBinding` consulte les observateurs dans leur ordre
/// d'enregistrement. Comme ce widget est monté avant `MaterialApp` (donc
/// avant l'observateur interne de `WidgetsApp`), son [didPopRoute] est
/// appelé en premier et peut avaler le retour système tant que le voile de
/// verrouillage est affiché. Le placer dans `_EcranDemarrage` serait trop
/// tard : `WidgetsApp` aurait déjà dépilé la route.
class GardienRetour extends StatefulWidget {
  const GardienRetour({super.key, required this.pin, required this.child});

  final PinProvider pin;
  final Widget child;

  @override
  State<GardienRetour> createState() => _GardienRetourState();
}

class _GardienRetourState extends State<GardienRetour>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async => widget.pin.verrouille;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      widget.pin.verrouiller();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
