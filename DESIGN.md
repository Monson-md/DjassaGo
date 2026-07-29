# Système de design — Caisse de Poche

Référence : `design/maquette.html` (maquette HTML cliquable). Ce fichier documente ce qu'on en a tiré. La maquette définit l'identité visuelle et les parcours ; elle ne contient aucune donnée réelle (produits, dettes, montants fictifs) et aucune logique métier — le modèle Hive du projet reste la seule source de vérité.

Toute nouvelle interface doit utiliser les constantes de `lib/config/theme.dart` et les composants de `lib/widgets/`, jamais des couleurs, rayons ou tailles de texte en dur.

## Palette

| Rôle | Hex | Usage |
|---|---|---|
| `encre` | `#17150F` | En-têtes, barre de navigation, texte principal |
| `papier` | `#FCFAF5` | Fond des écrans |
| `carte` | `#FFFFFF` | Surfaces, tuiles, lignes de liste |
| `ligne` | `#E4DFD3` | Bordures, séparateurs |
| `ocre` | `#E0A02B` | Onglet actif, alerte stock bas |
| `ocreFonce` | `#B57C13` | Ocre sur fond clair (contraste du texte) |
| `vert` | `#1C6B57` | Encaisser, marge positive, état sain |
| `vertClair` | `#E7F1ED` | Fond des éléments verts |
| `brique` | `#AF3524` | Retard, rupture, dépenses |
| `briqueClair` | `#FBEBE8` | Fond des éléments briques |
| `sourdine` | `#8A8474` | Texte secondaire, légendes |

Deux couleurs du CSS de la maquette sont volontairement exclues : `--nuit` (`#131A1F`) n'est que le fond de la page de démo autour du mockup de téléphone (pas une couleur de l'app), et `--ink-2` (`#3A362C`) est déclarée dans la maquette mais n'est utilisée nulle part.

## Typographie

Deux familles, embarquées en local dans `assets/fonts/` (polices variables, jamais de téléchargement à l'exécution — l'app est 100 % hors-ligne) :

- **Bricolage Grotesque** (700, 800) — titres d'écran, tous les montants, grands chiffres.
- **Inter** (400 à 700) — tout le reste.

Tous les montants utilisent `FontFeature.tabularFigures()` (chiffres tabulaires) pour ne jamais "danser" quand un total change. Ne jamais afficher un montant via un `Text` brut ou `NumberFormat` générique : toujours passer par `lib/utils/money.dart` (`formaterMontantMineur`) puis appliquer un style de `CaisseTypographie`.

Styles nommés dans `CaisseTypographie` : `titreEcran`, `etiquette`, `montantEnorme` (40), `montantGrand` (32), `montant` (19), `montantPetit` (15), `corps`, `corpsGras`, `corpsSecondaire`, `bouton`. Pour une taille non prévue, utiliser `CaisseTypographie.stylerMontant(taille: ...)` plutôt qu'un `TextStyle` ad hoc.

## Rayons

La maquette n'applique pas une règle stricte "carte = 14 / liste = 12" : `.card` et `.dette` (une ligne de liste, mais généreusement paddée) utilisent 14, tandis que `.tile` (tuile produit) et `.stock-l` (ligne de stock, denses) utilisent 12. La vraie distinction est entre surfaces généreusement paddées et éléments denses de grille/liste, pas entre "carte" et "liste" au sens strict.

- `CaisseRadius.carte` = 14 — cartes stat, lignes de dette, surfaces génériques.
- `CaisseRadius.liste` = 12 — tuiles produit, lignes de stock.
- `CaisseRadius.bouton` = 11 — tous les boutons.

## Espacements

`CaisseEspacement` : `xs` 4, `s` 8, `m` 12, `l` 16, `xl` 20 — valeurs récurrentes de la maquette.

## La bande rayée

Widget `BandeRayee` (`lib/widgets/bande_rayee.dart`). Bande de 5px sous l'en-tête de chaque écran, rayures verticales répétées dans l'ordre exact **ocre → vert → brique → encre**. C'est la signature visuelle figée de l'app : ne jamais l'agrandir, la recolorer, l'animer ou y ajouter du contenu.

## Composants (`lib/widgets/`)

| Widget | Rôle |
|---|---|
| `TuileProduit` | Tuile de la grille Caisse (3 colonnes). Purement présentative — le refus d'ajout d'un produit en rupture est géré par l'écran, pas par la tuile. |
| `LignePanier` | Ligne d'article dans le panier. |
| `CarteDette` | Ligne du carnet de dettes ; bascule en brique (fond + bordure + texte) si en retard. |
| `LigneStock` | Ligne de l'écran Stock ; barre colorée à gauche selon `EtatStock` (sain/bas/rupture). |
| `CarteStat` | Carte statistique générique (Bilan, Stock, tableau de bord Caisse), variante neutre/positive/négative. |
| `BandeauTotal` | Bandeau "Total" + montant énorme + marge en petit vert, pour le bas du panier. |
| `BoutonPrincipal` / `BoutonFantome` | Actions principale (vert plein) et secondaire (contour encre) — 48dp de hauteur minimum, imposé par le thème. |
| `PastilleEtat` | 4 variantes visuelles trouvées dans la maquette : `avertissementPlein` (ocre plein, ex. "Bas"), `alertePleine` (brique plein, ex. "Rupture"), `succesDoux` (vert doux, ex. "Actif"), `alerteDouce` (brique doux, ex. "À faire"). |
| `afficherToastCaisse(...)` | Confirmation non bloquante (fond encre, 3.4s). **Remplace tout `AlertDialog` de confirmation sur le parcours de vente** — un dialogue bloquant casse la règle "une vente doit s'enchaîner sans attendre". |

## Règles non négociables

- Aucune publicité sur l'écran Caisse, jamais.
- Aucun montant affiché sans passer par `money.dart` + un style `CaisseTypographie`.
- Cibles tactiles de 48dp minimum (déjà appliqué par le thème sur les boutons).
- Contraste élevé partout (lu en plein soleil) : jamais de gris clair sur blanc.
- Vocabulaire figé : "Encaisser", "Mettre en dette", "Vente enregistrée" — un mot par action, jamais reformulé d'un écran à l'autre.
- Pas d'animation qui ralentit la saisie sur l'écran Caisse.

## Écarts connus entre la maquette et l'app actuelle (à corriger à l'Étape B)

- La confirmation de vente de la maquette est un toast non bloquant ; l'app affiche actuellement un `AlertDialog` bloquant dans `panier_bottom_sheet.dart`. À remplacer par `afficherToastCaisse`.
- Réglages : la maquette montre un bouton "Sauvegarder maintenant" pleine largeur juste sous l'alerte de sauvegarde, plus visible que les `ListTile` Exporter/Importer actuels.
