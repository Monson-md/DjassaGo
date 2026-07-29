CONTEXTE

Une maquette HTML cliquable de l'application a été validée. Elle définit l'identité visuelle et les parcours cibles.

Fichier de référence : design/maquette.html (à la racine du projet).

Commence par le lire en entier — le HTML, le CSS et le JavaScript. Le CSS contient le système de couleurs et de typographie ; le JS contient les parcours d'interaction. Ne commence à écrire du code Flutter qu'après l'avoir lu.

Ce que la maquette est : la référence pour les couleurs, la typographie, la hiérarchie, l'espacement, le vocabulaire de l'interface et les parcours.

Ce qu'elle n'est pas : une source de données. Les produits, dettes et chiffres qu'elle contient sont fictifs. Le modèle Hive du projet reste la seule source de vérité. Ne recopie jamais ses données ni sa logique JavaScript.

ÉTAPE A — Système de design (à faire maintenant)
1. lib/config/theme.dart

Crée un ThemeData complet, avec des constantes nommées. Palette exacte, à ne pas réinterpréter :

Rôle	Hex	Usage
encre	
#17150F	En-têtes, barre de navigation, texte principal
papier	
#FCFAF5	Fond des écrans
carte	
#FFFFFF	Surfaces, tuiles, lignes de liste
ligne	
#E4DFD3	Bordures, séparateurs
ocre	
#E0A02B	Onglet actif, alerte stock bas
ocreFonce	
#B57C13	Ocre sur fond clair (contraste du texte)
vert	
#1C6B57	Encaisser, marge positive, état sain
vertClair	
#E7F1ED	Fond des éléments verts
brique	
#AF3524	Retard, rupture, dépenses
briqueClair	
#FBEBE8	Fond des éléments briques
sourdine	
#8A8474	Texte secondaire, légendes

Rayon standard : 14 pour les cartes, 12 pour les lignes de liste, 11 pour les boutons.

2. Typographie

Deux familles, comme dans la maquette :

Bricolage Grotesque — titres d'écran, montants, grands chiffres. Graisses 700 et 800.
Inter — tout le reste. Graisses 400 à 700.

Important, l'app est hors-ligne : n'utilise pas google_fonts en téléchargement à l'exécution. Télécharge les .ttf, place-les dans assets/fonts/, déclare-les dans pubspec.yaml. Une police qui ne charge pas parce qu'il n'y a pas de réseau est un bug bloquant sur ce produit.

Tous les montants doivent utiliser fontFeatures: [FontFeature.tabularFigures()]. Sinon les chiffres dansent quand le total change.

3. Composants réutilisables dans lib/widgets/

Extrais de la maquette : la tuile produit, la ligne de panier, la carte de dette, la ligne de stock, la carte statistique, le bandeau de total, le bouton principal et le bouton fantôme, la pastille d'état, le toast de confirmation.

4. La bande rayée

En haut de chaque écran, sous l'en-tête : une bande de 5 px de haut, rayures verticales répétées ocre / vert / brique / encre. C'est la signature visuelle de l'app. Elle apparaît partout, elle ne bouge jamais, elle n'est jamais décorée davantage.

5. DESIGN.md

Documente à la racine : palette, échelle typographique, espacements, règles d'usage. Toute nouvelle interface devra s'y référer.

ÉTAPE B — Application aux écrans

Restyle chaque écran au moment où sa phase fonctionnelle du prompt 1 est terminée, pas avant. Inutile de peindre un écran qui va changer.

Caisse — grille 3 colonnes, pastille de quantité sur la tuile, panier en bas toujours visible, total en très grand, marge en petit vert juste à côté. Deux actions : Encaisser (plein vert) et Mettre en dette (contour). Les produits en rupture restent visibles mais refusent l'ajout avec un message clair.
Dettes — bandeau sombre en haut avec le total dû et le montant en retard. Les dettes en retard basculent en brique, fond compris. Bouton Relancer sur chaque ligne.
Stock — trié du plus bas au plus haut. Barre verticale colorée à gauche selon l'état. Prix d'achat, prix de vente et marge unitaire sur chaque ligne.
Bilan — le résultat net en premier, en grand, sur fond encre. Puis chiffre d'affaires, marge brute, dépenses, encaissé. La note qui explique la différence entre encaissé et chiffre d'affaires reste dans l'écran : c'est de la pédagogie, pas du remplissage.
Réglages — l'alerte de sauvegarde en premier tant qu'elle n'est pas faite.
RÈGLES NON NÉGOCIABLES
Aucune publicité sur l'écran Caisse, jamais, sous aucune forme.
Aucun montant affiché sans passer par le formateur central de la Phase 1.
Cibles tactiles de 48 dp minimum. L'app s'utilise debout, à une main, parfois avec les doigts mouillés.
Contraste élevé partout. Cet écran est lu en plein soleil. Pas de gris clair sur blanc.
Le vocabulaire de la maquette est figé. Le bouton dit Encaisser, la confirmation dit Vente enregistrée. Un mot par action, le même du début à la fin.
Pas d'animation qui ralentit la saisie. Une vente doit pouvoir s'enchaîner sans attendre.
LÀ OÙ TU DOIS FAIRE MIEUX QUE LA MAQUETTE

Une page HTML ne peut pas tout montrer. Ajoute ce qui manque, en restant dans la même langue visuelle :

Retour haptique léger à chaque ajout au panier, plus marqué à la validation d'une vente.
Pavé numérique personnalisé pour saisir une quantité ou un montant libre : gros chiffres, pas le clavier système.
Ergonomie à une main : toutes les actions fréquentes dans le tiers inférieur de l'écran.
États vides, de chargement et d'erreur pour chaque écran. Un écran vide est une invitation à agir, pas une page blanche. Une erreur dit ce qui s'est passé et quoi faire, sans s'excuser.
Indicateur hors-ligne honnête : l'app fonctionne sans réseau, ce n'est donc pas une erreur. Ne montre jamais d'alerte rouge parce qu'il n'y a pas de connexion.
Confirmation destructive avant d'annuler une vente ou de restaurer une sauvegarde.
Accessibilité : libellés Semantics sur les boutons icônes, support du grossissement du texte système sans casser la grille.
Mode sombre dérivé de la même palette, si tu peux le faire proprement. Sinon, dis-le et ne le fais pas à moitié.
MÉTHODE
Lis design/maquette.html en entier.
Dis-moi ce que tu en as compris et ce qui te semble ambigu, avant d'écrire du code.
Fais l'étape A, puis arrête-toi et montre-moi theme.dart et DESIGN.md.
Attends mon feu vert avant l'étape B, écran par écran.

flutter analyze doit rester à 0 erreur, et un commit propre après chaque écran.