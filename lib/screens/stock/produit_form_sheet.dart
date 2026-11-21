import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/produit.dart';
import '../../providers/conditionnement_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/produit_provider.dart';
import '../../services/conditionnement_service.dart';
import '../../services/normalisation_conditionnements.dart';
import '../../utils/devises_disponibles.dart';
import '../../utils/money.dart';

const _suggestionsUniteBase = ['bouteille', 'sachet', 'pièce', 'kg', 'litre'];

/// Une ligne éditable de conditionnement de vente dans le formulaire
/// (Bouteille, Casier...). Ses champs sont bruts (texte) pendant la saisie ;
/// [ConditionnementBrouillon] est l'objet validé qui en découle à
/// l'enregistrement.
class _LigneConditionnement {
  /// Identifiant stable du conditionnement existant (null pour une ligne
  /// ajoutée dans ce formulaire) : transmis à
  /// [ConditionnementService.remplacerPour] pour ne pas recréer un format
  /// simplement édité.
  final String? id;
  final TextEditingController nom;
  final TextEditingController quantite;
  final TextEditingController prixVente;

  _LigneConditionnement({
    this.id,
    String nom = '',
    String quantite = '1',
    String prixVente = '',
  }) : nom = TextEditingController(text: nom),
       quantite = TextEditingController(text: quantite),
       prixVente = TextEditingController(text: prixVente);

  void dispose() {
    nom.dispose();
    quantite.dispose();
    prixVente.dispose();
  }
}

/// Formulaire d'ajout ou de modification d'un produit — nom, unité de base,
/// prix d'achat (saisi tel qu'acheté réellement, ex: « un carton de 20 à
/// 1500 », converti en coût par unité), formats de vente (conditionnements)
/// et stock en unités de base.
class ProduitFormSheet extends StatefulWidget {
  final Produit? produit;
  const ProduitFormSheet({super.key, this.produit});

  @override
  State<ProduitFormSheet> createState() => _ProduitFormSheetState();
}

class _ProduitFormSheetState extends State<ProduitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _uniteBaseController;
  late final TextEditingController _achatQuantiteController;
  late final TextEditingController _achatPrixController;
  late final TextEditingController _stockController;
  final _stockAjoutQuantiteController = TextEditingController();

  final List<_LigneConditionnement> _lignes = [];
  int _indexParDefaut = 0;
  int _indexFormatStock = 0;
  bool _enCours = false;
  String? _erreurFormats;

  bool get _modeEdition => widget.produit != null;

  void _live() => setState(() {});

  @override
  void initState() {
    super.initState();
    final p = widget.produit;
    _nomController = TextEditingController(text: p?.nom ?? '');
    _uniteBaseController = TextEditingController(text: p?.uniteBase ?? 'unité')
      ..addListener(_live);
    // Le prix d'achat existant est un coût par unité de base : présenté ici
    // comme « 1 unité au prix de X », le commerçant peut regrouper à
    // nouveau (ex: passer à « 1 carton de 20 au prix de 20X ») s'il achète
    // désormais par conditionnement.
    _achatQuantiteController = TextEditingController(text: '1')
      ..addListener(_live);
    _achatPrixController = TextEditingController(
      text: p != null ? p.prixAchat.toString() : '',
    )..addListener(_live);
    _stockController = TextEditingController(
      text: p != null ? p.stockActuel.toString() : '0',
    );

    if (p != null) {
      final conditionnements = context
          .read<ConditionnementProvider>()
          .listerPour(p);
      for (final c in conditionnements) {
        _lignes.add(
          _LigneConditionnement(
            id: c.id,
            nom: c.nom,
            quantite: c.quantiteEnUniteBase.toString(),
            prixVente: c.prixVente.toString(),
          )..nom.addListener(_live),
        );
        _lignes.last.quantite.addListener(_live);
        _lignes.last.prixVente.addListener(_live);
      }
      _indexParDefaut = conditionnements.indexWhere((c) => c.parDefaut);
      if (_indexParDefaut < 0) _indexParDefaut = 0;
    } else {
      _lignes.add(_ligneVide(nom: 'Unité'));
    }
  }

  _LigneConditionnement _ligneVide({String nom = ''}) {
    final ligne = _LigneConditionnement(nom: nom);
    ligne.nom.addListener(_live);
    ligne.quantite.addListener(_live);
    ligne.prixVente.addListener(_live);
    return ligne;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _uniteBaseController.dispose();
    _achatQuantiteController.dispose();
    _achatPrixController.dispose();
    _stockController.dispose();
    _stockAjoutQuantiteController.dispose();
    for (final ligne in _lignes) {
      ligne.dispose();
    }
    super.dispose();
  }

  double get _prixAchatUnitaire {
    final quantite = int.tryParse(_achatQuantiteController.text) ?? 0;
    final prixTotal =
        double.tryParse(_achatPrixController.text.replaceAll(',', '.')) ?? 0;
    if (quantite <= 0) return 0;
    return prixTotal / quantite;
  }

  void _ajouterLigne() {
    setState(() => _lignes.add(_ligneVide()));
  }

  void _supprimerLigne(int index) {
    if (_lignes.length <= 1) return;
    setState(() {
      _lignes.removeAt(index).dispose();
      if (_indexParDefaut == index) {
        _indexParDefaut = 0;
      } else if (_indexParDefaut > index) {
        _indexParDefaut -= 1;
      }
      if (_indexFormatStock >= _lignes.length) _indexFormatStock = 0;
    });
  }

  void _appliquerRaccourciStock() {
    final n = int.tryParse(_stockAjoutQuantiteController.text);
    if (n == null || n <= 0 || _indexFormatStock >= _lignes.length) return;
    final quantiteFormat =
        int.tryParse(_lignes[_indexFormatStock].quantite.text) ?? 0;
    final stockActuel = int.tryParse(_stockController.text) ?? 0;
    setState(() {
      _stockController.text = (stockActuel + n * quantiteFormat).toString();
      _stockAjoutQuantiteController.clear();
    });
  }

  String? _validerTexte(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;

  String? _validerEntierPositif(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requis';
    final n = int.tryParse(v);
    if (n == null || n <= 0) return 'Entier > 0 requis';
    return null;
  }

  String? _validerMontant(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requis';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Valeur invalide';
    return null;
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    // Premier filtre d'unicité (la vraie protection reste celle de
    // ConditionnementService.remplacerPour) : AVANT toute écriture et avant
    // de passer _enCours à true. Un doublon de nom normalisé — casse et
    // espaces ignorés — bloque l'enregistrement.
    final nomsSaisis = [for (final ligne in _lignes) ligne.nom.text];
    final quantitesSaisies = [
      for (final ligne in _lignes) int.tryParse(ligne.quantite.text) ?? 0,
    ];
    final erreurFormats = validerNomsEtQuantitesConditionnements(
      noms: nomsSaisis,
      quantitesEnUniteBase: quantitesSaisies,
    );
    if (erreurFormats != null) {
      setState(() => _erreurFormats = erreurFormats);
      return;
    }

    setState(() {
      _erreurFormats = null;
      _enCours = true;
    });
    final produitProvider = context.read<ProduitProvider>();
    final conditionnementProvider = context.read<ConditionnementProvider>();
    final devise = context.read<CurrencyProvider>().codeIsoDevise;
    final decimales = decimalesPourCodeIso(devise);

    final nom = _nomController.text.trim();
    final uniteBase = _uniteBaseController.text.trim();
    final prixAchatUnitaire = _prixAchatUnitaire;
    final stock = int.parse(_stockController.text);

    final brouillons = <ConditionnementBrouillon>[
      for (var i = 0; i < _lignes.length; i++)
        ConditionnementBrouillon(
          id: _lignes[i].id,
          nom: _lignes[i].nom.text.trim(),
          quantiteEnUniteBase: int.parse(_lignes[i].quantite.text),
          prixVente: double.parse(
            _lignes[i].prixVente.text.replaceAll(',', '.'),
          ),
          parDefaut: i == _indexParDefaut,
        ),
    ];

    // I2 : Produit.prixVente/prixVenteMineur portent le prix d'UNE unité de
    // base. Priorité au format de quantité 1 ; sinon division du prix du
    // format par défaut par sa quantité (voir
    // normalisation_conditionnements.dart). Le prix affiché en caisse reste
    // celui du conditionnement choisi, inchangé.
    final prixVenteUniteBase = calculerPrixUniteBase(
      quantitesEnUniteBase: [for (final b in brouillons) b.quantiteEnUniteBase],
      prixVente: [for (final b in brouillons) b.prixVente],
      indexParDefaut: _indexParDefaut,
      decimales: decimales,
    );

    Produit produit;
    if (_modeEdition) {
      produit = widget.produit!;
      produit.nom = nom;
      produit.uniteBase = uniteBase;
      produit.definirPrix(
        prixAchat: prixAchatUnitaire,
        prixVente: prixVenteUniteBase,
      );
      produit.stockActuel = stock;
      await produitProvider.modifier(produit);
    } else {
      produit = await produitProvider.ajouter(
        nom: nom,
        prixAchat: prixAchatUnitaire,
        prixVente: prixVenteUniteBase,
        stockActuel: stock,
        devise: devise,
        uniteBase: uniteBase,
      );
    }

    await conditionnementProvider.remplacerPour(
      produitId: produit.id,
      brouillons: brouillons,
      devise: devise,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Prix de l'unité de base recalculé en direct depuis les champs du
  /// formulaire, pour l'affichage « Soit X par unité de base » à côté du
  /// format par défaut. `null` tant que les saisies ne sont pas exploitables.
  double? _prixUniteBaseAffiche(InfoDevise devise) {
    final quantites = <int>[];
    final prix = <double>[];
    for (final ligne in _lignes) {
      final quantite = int.tryParse(ligne.quantite.text);
      final prixVente = double.tryParse(
        ligne.prixVente.text.replaceAll(',', '.'),
      );
      if (quantite == null || quantite <= 0 || prixVente == null) return null;
      quantites.add(quantite);
      prix.add(prixVente);
    }
    if (quantites.isEmpty) return null;
    final index = (_indexParDefaut >= 0 && _indexParDefaut < quantites.length)
        ? _indexParDefaut
        : 0;
    return calculerPrixUniteBase(
      quantitesEnUniteBase: quantites,
      prixVente: prix,
      indexParDefaut: index,
      decimales: devise.decimales,
    );
  }

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<CurrencyProvider>().devise;
    final uniteBaseAffichee = _uniteBaseController.text.trim().isEmpty
        ? 'unité'
        : _uniteBaseController.text.trim();
    final quantiteAchat = int.tryParse(_achatQuantiteController.text) ?? 1;
    final uniteAchatAffichee = quantiteAchat > 1
        ? '${uniteBaseAffichee}s'
        : uniteBaseAffichee;
    final prixUniteBase = _prixUniteBaseAffiche(devise);
    final textePrixUniteBase = prixUniteBase == null
        ? null
        : 'Soit ${formaterMontantMineur(versUnitesMineures(prixUniteBase, devise.decimales), decimales: devise.decimales, symbole: devise.symbole)} par $uniteBaseAffichee';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _modeEdition ? 'Modifier le produit' : 'Nouveau produit',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('produit_nom'),
                  controller: _nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du produit',
                  ),
                  validator: _validerTexte,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('produit_unite_base'),
                  controller: _uniteBaseController,
                  decoration: const InputDecoration(
                    labelText: 'Unité de base',
                    hintText: 'bouteille, sachet, pièce, kg...',
                  ),
                  validator: _validerTexte,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _suggestionsUniteBase
                      .map(
                        (s) => ActionChip(
                          label: Text(s),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _uniteBaseController.text = s),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  "Prix d'achat",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  "Saisissez le prix tel que vous l'achetez réellement.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Text("J'achète", style: TextStyle(fontSize: 15)),
                    SizedBox(
                      width: 70,
                      child: TextFormField(
                        key: const Key('produit_achat_quantite'),
                        controller: _achatQuantiteController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          errorMaxLines: 2,
                        ),
                        validator: _validerEntierPositif,
                      ),
                    ),
                    Text(
                      uniteAchatAffichee,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const Text('à', style: TextStyle(fontSize: 15)),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        key: const Key('produit_achat_prix'),
                        controller: _achatPrixController,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          errorMaxLines: 2,
                        ),
                        validator: _validerMontant,
                      ),
                    ),
                    Text(devise.symbole, style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Soit ${formaterMontantMineur(versUnitesMineures(_prixAchatUnitaire, devise.decimales), decimales: devise.decimales, symbole: devise.symbole)} par $uniteBaseAffichee',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Formats de vente',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    TextButton.icon(
                      onPressed: _ajouterLigne,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
                for (var i = 0; i < _lignes.length; i++)
                  _LigneConditionnementWidget(
                    index: i,
                    ligne: _lignes[i],
                    uniteBase: uniteBaseAffichee,
                    prixAchatUnitaire: _prixAchatUnitaire,
                    devise: devise,
                    estParDefaut: _indexParDefaut == i,
                    textePrixUniteBase: _indexParDefaut == i
                        ? textePrixUniteBase
                        : null,
                    suppressible: _lignes.length > 1,
                    onChoisirParDefaut: () =>
                        setState(() => _indexParDefaut = i),
                    onSupprimer: () => _supprimerLigne(i),
                  ),
                if (_erreurFormats != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _erreurFormats!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Stock', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Toujours exprimé en unités de base ($uniteBaseAffichee).',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('produit_stock'),
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stock actuel ($uniteBaseAffichee)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis';
                    if (int.tryParse(v) == null) return 'Nombre entier requis';
                    return null;
                  },
                ),
                if (_lignes.length > 1 ||
                    (int.tryParse(_lignes.first.quantite.text) ?? 1) > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("J'ai"),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _stockAjoutQuantiteController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _indexFormatStock < _lignes.length
                              ? _indexFormatStock
                              : 0,
                          items: [
                            for (var i = 0; i < _lignes.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  _lignes[i].nom.text.isEmpty
                                      ? '(sans nom)'
                                      : _lignes[i].nom.text,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _indexFormatStock = v ?? 0),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Ajouter au stock',
                        onPressed: _appliquerRaccourciStock,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _enCours ? null : _enregistrer,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _enCours
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une ligne de format de vente : nom, quantité en unité de base, prix de
/// vente, marge calculée en direct et sélection du format par défaut.
class _LigneConditionnementWidget extends StatelessWidget {
  const _LigneConditionnementWidget({
    required this.index,
    required this.ligne,
    required this.uniteBase,
    required this.prixAchatUnitaire,
    required this.devise,
    required this.estParDefaut,
    required this.suppressible,
    required this.onChoisirParDefaut,
    required this.onSupprimer,
    this.textePrixUniteBase,
  });

  final int index;
  final _LigneConditionnement ligne;
  final String uniteBase;
  final double prixAchatUnitaire;
  final InfoDevise devise;
  final bool estParDefaut;
  final bool suppressible;
  final String? textePrixUniteBase;
  final VoidCallback onChoisirParDefaut;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    final quantite = int.tryParse(ligne.quantite.text) ?? 0;
    final prixVente =
        double.tryParse(ligne.prixVente.text.replaceAll(',', '.')) ?? 0;
    final marge = prixVente - (quantite * prixAchatUnitaire);
    final margeMineur = versUnitesMineures(marge, devise.decimales);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: Key('conditionnement_${index}_nom'),
                  controller: ligne.nom,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: Key('conditionnement_${index}_quantite'),
                  controller: ligne.quantite,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'En $uniteBase',
                    isDense: true,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n <= 0) ? '> 0' : null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: Key('conditionnement_${index}_prix'),
                  controller: ligne.prixVente,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Prix',
                    isDense: true,
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    return (n == null || n < 0) ? 'Invalide' : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onChoisirParDefaut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        estParDefaut
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: estParDefaut
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      const Text('Par défaut', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Marge : ${formaterMontantMineur(margeMineur, decimales: devise.decimales, symbole: devise.symbole)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: marge < 0 ? Colors.red : Colors.green.shade700,
                ),
              ),
              if (suppressible)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onSupprimer,
                ),
            ],
          ),
          if (textePrixUniteBase != null) ...[
            const SizedBox(height: 2),
            Text(
              textePrixUniteBase!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
