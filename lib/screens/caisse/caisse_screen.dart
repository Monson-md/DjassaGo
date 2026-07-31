import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/conditionnement.dart';
import '../../models/produit.dart';
import '../../providers/caisse_provider.dart';
import '../../providers/conditionnement_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/produit_provider.dart';
import '../../services/ad_service.dart';
import '../../utils/devises_disponibles.dart';
import '../../utils/money.dart';
import 'choix_conditionnement_sheet.dart';
import 'journal_ventes_screen.dart';
import 'panier_bottom_sheet.dart';

/// Écran de Caisse : cœur de l'application.
/// Conçu pour la rapidité — un commerçant doit pouvoir encaisser une
/// vente en quelques secondes, sans écran de chargement ni friction.
class CaisseScreen extends StatefulWidget {
  const CaisseScreen({super.key});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends State<CaisseScreen> {
  final _rechercheController = TextEditingController();
  String _recherche = '';

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  void _ouvrirPanier() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PanierBottomSheet(),
    ).then((venteFinalisee) {
      if (venteFinalisee == true) {
        // Point de rupture naturel après une vente : opportunité pour un
        // interstitiel, sans jamais interrompre la saisie de la vente.
        AdService.instance.afficherInterstitielSiOpportun();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<CurrencyProvider>().devise;
    final produits = context.watch<ProduitProvider>().produits;
    final caisse = context.watch<CaisseProvider>();

    final produitsFiltres = _recherche.isEmpty
        ? produits
        : produits
            .where((p) =>
                p.nom.toLowerCase().contains(_recherche.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caisse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Journal des ventes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JournalVentesScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatsDuJour(devise: devise),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _rechercheController,
              onChanged: (v) => setState(() => _recherche = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _recherche.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _rechercheController.clear();
                          setState(() => _recherche = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: produitsFiltres.isEmpty
                ? const _AucunProduit()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.35,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: produitsFiltres.length,
                    itemBuilder: (context, index) {
                      final produit = produitsFiltres[index];
                      return _CarteProduit(produit: produit, devise: devise);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: caisse.nombreArticlesPanier == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _ouvrirPanier,
              icon: Badge(
                label: Text('${caisse.nombreArticlesPanier}'),
                child: const Icon(Icons.shopping_cart),
              ),
              label: Text(formaterMontantMineur(
                versUnitesMineures(caisse.totalPanier, devise.decimales),
                decimales: devise.decimales,
                symbole: devise.symbole,
              )),
            ),
    );
  }
}

class _StatsDuJour extends StatelessWidget {
  final InfoDevise devise;
  const _StatsDuJour({required this.devise});

  @override
  Widget build(BuildContext context) {
    final caisse = context.watch<CaisseProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CarteStat(
                  titre: 'CA du jour',
                  valeur: formaterMontantMineur(
                    caisse.totalDuJourMineur(),
                    decimales: devise.decimales,
                    symbole: devise.symbole,
                  ),
                  couleur: Colors.teal,
                  icone: Icons.point_of_sale,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CarteStat(
                  titre: 'Marge brute',
                  valeur: formaterMontantMineur(
                    caisse.margeBruteDuJourMineur(),
                    decimales: devise.decimales,
                    symbole: devise.symbole,
                  ),
                  couleur: Colors.indigo,
                  icone: Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Distinct du CA : une vente à crédit compte dans le CA du jour
          // mais pas ici tant qu'elle n'est pas payée (voir
          // CaisseService.encaissementsDuJourMineur).
          _CarteStat(
            titre: 'Encaissements du jour',
            valeur: formaterMontantMineur(
              caisse.encaissementsDuJourMineur(),
              decimales: devise.decimales,
              symbole: devise.symbole,
            ),
            couleur: Colors.blue,
            icone: Icons.savings,
          ),
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteProduit extends StatelessWidget {
  final Produit produit;
  final InfoDevise devise;

  const _CarteProduit({required this.produit, required this.devise});

  Future<void> _choisirFormat(
      BuildContext context, List<Conditionnement> conditionnements) async {
    final choisi = await showModalBottomSheet<Conditionnement>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChoixConditionnementSheet(
        produit: produit,
        conditionnements: conditionnements,
      ),
    );
    if (choisi != null && context.mounted) {
      context.read<CaisseProvider>().ajouterAuPanier(produit, choisi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enRupture = produit.enRupture;
    final conditionnements =
        context.watch<ConditionnementProvider>().listerPour(produit);
    final conditionnementParDefaut = conditionnements
        .firstWhere((c) => c.parDefaut, orElse: () => conditionnements.first);
    final plusieursFormats = conditionnements.length > 1;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Une touche ajoute directement le format par défaut — comportement
        // inchangé pour un produit à conditionnement unique. Un appui long
        // ouvre le choix des autres formats pour un produit qui en a
        // plusieurs (ex: Bouteille ou Casier de Coca).
        onTap: enRupture
            ? null
            : () => context
                .read<CaisseProvider>()
                .ajouterAuPanier(produit, conditionnementParDefaut),
        onLongPress: enRupture || !plusieursFormats
            ? null
            : () => _choisirFormat(context, conditionnements),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      produit.nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (plusieursFormats)
                    Icon(Icons.layers,
                        size: 14, color: Colors.grey.shade500),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formaterMontantMineur(
                      conditionnementParDefaut.prixVenteMineur,
                      decimales: devise.decimales,
                      symbole: devise.symbole,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (enRupture)
                    const Chip(
                      label: Text('Rupture', style: TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    Text(
                      'Stock: ${produit.stockActuel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: produit.stockFaible
                            ? Colors.orange
                            : Colors.grey,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AucunProduit extends StatelessWidget {
  const _AucunProduit();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Aucun produit. Ajoutez-en depuis l\'onglet Stock.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
