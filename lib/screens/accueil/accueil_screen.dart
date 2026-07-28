import 'package:flutter/material.dart';

import '../caisse/caisse_screen.dart';
import '../dettes/dettes_screen.dart';
import '../parametres/parametres_screen.dart';
import '../stock/stock_screen.dart';

/// Coquille de navigation principale de l'application, avec la Caisse
/// comme onglet par défaut : c'est l'écran le plus utilisé au quotidien.
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  int _ongletActif = 0;

  static const _ecrans = [
    CaisseScreen(),
    DettesScreen(),
    StockScreen(),
    ParametresScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _ongletActif, children: _ecrans),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _ongletActif,
        onDestinationSelected: (i) => setState(() => _ongletActif = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Caisse',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Dettes',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
