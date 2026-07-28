import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dette.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dette_provider.dart';
import '../../utils/formatage.dart';
import 'dette_detail_sheet.dart';
import 'dette_form_sheet.dart';

/// Carnet de dettes : suivi des créances clients et relance en un clic
/// via WhatsApp ou SMS.
class DettesScreen extends StatelessWidget {
  const DettesScreen({super.key});

  void _ouvrirFormulaireAjout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DetteFormSheet(),
    );
  }

  void _ouvrirDetail(BuildContext context, Dette dette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DetteDetailSheet(dette: dette),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dettes = context.watch<DetteProvider>().dettesEnCours;
    final total = context.watch<DetteProvider>().totalEnCours;
    final devise = context.watch<CurrencyProvider>().symboleDevise;

    return Scaffold(
      appBar: AppBar(title: const Text('Carnet de dettes')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total dû par les clients',
                    style: TextStyle(color: Colors.red)),
                const SizedBox(height: 4),
                Text(
                  formaterMontant(total, symbole: devise),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
              ],
            ),
          ),
          Expanded(
            child: dettes.isEmpty
                ? Center(
                    child: Text(
                      'Aucune dette en cours',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: dettes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dette = dettes[index];
                      return ListTile(
                        onTap: () => _ouvrirDetail(context, dette),
                        leading: CircleAvatar(
                          backgroundColor: dette.statut ==
                                  StatutDette.partiellementPayee
                              ? Colors.orange.shade100
                              : Colors.red.shade50,
                          child: Text(
                            dette.nomClient.isNotEmpty
                                ? dette.nomClient[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(dette.nomClient),
                        subtitle: Text(
                          '${dette.telephone} · ${formaterDate(dette.dateDette)}',
                        ),
                        trailing: Text(
                          formaterMontant(dette.montantDu, symbole: devise),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _ouvrirFormulaireAjout(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
