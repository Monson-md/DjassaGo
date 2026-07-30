import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/caisse_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/depense_provider.dart';
import '../../utils/devises_disponibles.dart';
import '../../utils/formatage.dart';
import '../../utils/money.dart';
import '../../utils/periodes.dart';
import 'depense_form_sheet.dart';

/// Tableau de bord : chiffre d'affaires, marge brute, dépenses et
/// résultat net, sur le jour, la semaine ou le mois (Phase 7 de
/// docs/PHASES.md). Le résultat net (marge brute - dépenses) est le
/// premier indicateur qui dit si le commerce est réellement rentable :
/// la marge brute seule ne déduit aucune charge.
class RapportScreen extends StatefulWidget {
  const RapportScreen({super.key});

  @override
  State<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends State<RapportScreen> {
  Periode _periode = Periode.jour;

  void _ouvrirAjoutDepense() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DepenseFormSheet(),
    );
  }

  Future<void> _supprimerDepense(String id) async {
    await context.read<DepenseProvider>().supprimer(id);
  }

  String _libelleMonnaie(int mineur, InfoDevise devise) => formaterMontantMineur(
        mineur,
        decimales: devise.decimales,
        symbole: devise.symbole,
      );

  @override
  Widget build(BuildContext context) {
    final caisse = context.watch<CaisseProvider>();
    final depenseProvider = context.watch<DepenseProvider>();
    final devise = context.watch<CurrencyProvider>().devise;

    final ca = caisse.totalMineurSur(_periode);
    final marge = caisse.margeBruteMineurSur(_periode);
    final totalDepenses = depenseProvider.totalMineurSur(_periode);
    final resultatNet = marge - totalDepenses;
    final depensesPeriode = depenseProvider.listerSur(_periode);

    return Scaffold(
      appBar: AppBar(title: const Text('Rapport')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<Periode>(
            segments: const [
              ButtonSegment(value: Periode.jour, label: Text('Jour')),
              ButtonSegment(value: Periode.semaine, label: Text('Semaine')),
              ButtonSegment(value: Periode.mois, label: Text('Mois')),
            ],
            selected: {_periode},
            onSelectionChanged: (selection) =>
                setState(() => _periode = selection.first),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _CarteStat(
                titre: "Chiffre d'affaires",
                valeur: _libelleMonnaie(ca, devise),
                couleur: Colors.teal,
                icone: Icons.point_of_sale,
              ),
              _CarteStat(
                titre: 'Marge brute',
                valeur: _libelleMonnaie(marge, devise),
                couleur: Colors.indigo,
                icone: Icons.trending_up,
              ),
              _CarteStat(
                titre: 'Dépenses',
                valeur: _libelleMonnaie(totalDepenses, devise),
                couleur: Colors.orange,
                icone: Icons.money_off,
              ),
              _CarteStat(
                titre: 'Résultat net',
                valeur: _libelleMonnaie(resultatNet, devise),
                couleur: resultatNet >= 0 ? Colors.green : Colors.red,
                icone: resultatNet >= 0
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dépenses de la période',
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: _ouvrirAjoutDepense,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          if (depensesPeriode.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucune dépense sur cette période.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...depensesPeriode.map((d) => Card(
                  child: ListTile(
                    title: Text(d.libelle),
                    subtitle: Text(
                      '${libelleCategorie(d.categorie)} · ${formaterDate(d.date)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _libelleMonnaie(d.montantMineur, devise),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _supprimerDepense(d.id),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _CarteStat extends StatelessWidget {
  final String titre;
  final String valeur;
  final Color couleur;
  final IconData icone;

  const _CarteStat({
    required this.titre,
    required this.valeur,
    required this.couleur,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: couleur),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titre,
                  style: TextStyle(fontSize: 12, color: couleur),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
