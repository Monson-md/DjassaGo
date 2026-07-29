CONTEXTE

Tu reprends un projet Flutter déjà existant : Caisse de Poche (dossier DjassaGo). C'est une application offline-first de caisse, stock et dettes pour petits commerçants. Stack : Flutter, Hive (local, 100 % hors-ligne), Provider, Firebase (prévu, pas encore branché), AdMob.

L'architecture, les modèles Hive, les services et les premiers écrans existent déjà.

RÈGLES ABSOLUES — À RESPECTER SUR TOUTE LA SESSION
Ne recrée jamais le projet. Pas de flutter create, pas de suppression de dossier, pas de réécriture complète d'un fichier existant sans me le dire. Tu travailles en incrémental sur le code existant.
Avant de commencer, vérifie que Git est initialisé. Sinon : git init, .gitignore Flutter standard, puis un commit chore: état initial avant durcissement v1. Ne fais rien d'autre tant que ce commit n'est pas passé.
Ne change JAMAIS un typeId Hive existant, ni la numérotation d'un @HiveField existant. Tu ne peux qu'ajouter de nouveaux champs avec de nouveaux index, nullables ou avec valeur par défaut. Toute modification destructive du schéma doit m'être signalée avant exécution.
Après chaque phase : flutter analyze doit renvoyer 0 erreur, et flutter test doit passer. Puis un commit avec un message clair (fix:, feat:, refactor:).
Aucune nouvelle dépendance sans me dire laquelle et pourquoi.
Ne touche pas à la fluidité de l'écran Caisse. La rapidité de saisie est le cœur du produit : aucune pub, aucun dialogue bloquant, aucune latence ajoutée sur ce parcours.
Travaille phase par phase. À la fin de chaque phase, arrête-toi, montre-moi le résultat de flutter analyze et attends mon feu vert.
PHASE 0 — Remise en état de compilation
Corrige les imports dupliqués dans lib/services/dette_service.dart (dette.dart et hive_service.dart sont importés deux fois).
Vérifie ios/Runner/Info.plist : la clé CFBundleVersion semble corrompue (caractère parasite dans $(FLUTTER_BUILD_NUMBER)).
Vérifie que lib/providers/currency_provider.dart est complet.
Vérifie que tous les adapters Hive sont bien générés (build_runner) et bien enregistrés dans HiveService.
Objectif de sortie : flutter analyze → 0 erreur, flutter build apk --debug → OK.
PHASE 1 — Intégrité comptable (LA PLUS CRITIQUE)

Problème 1 — le bénéfice est recalculé à partir du prix d'achat actuel. Si le commerçant change le prix d'achat d'un produit, toute sa comptabilité passée est faussée.

Ajoute à ItemVendu de nouveaux @HiveField : prixAchatUnitaire et prixVenteUnitaire, figés au moment de la vente.
La marge d'une transaction se calcule uniquement à partir de ces valeurs figées, jamais depuis l'objet Produit courant.
Prévois le cas des ItemVendu déjà enregistrés sans ces champs (valeur par défaut + non comptés dans les stats historiques).

Problème 2 — l'argent est stocké en double.

Ajoute un champ decimales (int) au modèle Devise : 0 pour le XOF/FCFA, 2 pour EUR/USD, etc. Renseigne-le dans devises_disponibles.dart.
Crée lib/utils/money.dart : stockage en unités mineures (int), une seule fonction de formatage utilisant intl et le nombre de décimales de la devise.
Migre les montants existants (prixAchat, prixVente, montantTotal, montantDu…) vers ce format, via de nouveaux champs Hive (ne supprime pas les anciens tout de suite).
Aucun affichage ne doit jamais montrer « 1500,00 FCFA ».

Si tu juges le passage complet en int trop risqué en une passe, dis-le-moi avant de commencer et propose un découpage — mais ne te contente pas d'arrondir à l'affichage.

PHASE 2 — Sauvegarde et restauration locale

Aujourd'hui, si le téléphone est perdu, toutes les données du commerçant disparaissent. C'est inacceptable pour une app qui remplace un carnet.

Fonction d'export : toutes les boxes Hive → un seul fichier JSON contenant schemaVersion, date d'export, version de l'app.
Partage du fichier via share_plus (WhatsApp, Drive, e-mail).
Fonction d'import : validation du schéma, aperçu avant restauration (« 42 produits, 318 ventes, 12 dettes »), choix entre remplacer et fusionner.
Rappel discret dans l'app si aucune sauvegarde depuis 7 jours.
PHASE 3 — Vente à crédit reliée au carnet de dettes

Actuellement Caisse et Dettes sont deux silos, alors que vendre à crédit est un geste quotidien.

Dans le panier : deux actions de validation, « Encaisser » et « Mettre en dette ».
En cas de dette : sélection d'un client existant ou création rapide, puis génération automatique de la Dette liée.
Ajoute transactionId à Dette et modePaiement à Transaction (especes, credit, mobileMoney) — nouveaux @HiveField.
Nouveau modèle PaiementDette (nouveau typeId libre) pour l'historique des paiements partiels.

Règle comptable à implémenter explicitement et à documenter en commentaire : le chiffre d'affaires et la marge sont reconnus au moment de la vente. Un paiement de dette est une entrée de caisse, pas un nouveau chiffre d'affaires. Il ne doit jamais être compté deux fois. Prévois donc deux indicateurs distincts sur le tableau de bord : CA du jour et encaissements du jour.

PHASE 4 — Annulation et correction de vente
Possibilité d'annuler une transaction : remise en stock automatique des articles.
Ne supprime jamais physiquement une transaction : ajoute un champ annulee (bool) + dateAnnulation + motif.
Les transactions annulées sont exclues des statistiques mais restent consultables dans un journal.
PHASE 5 — Verrouillage par code PIN

Le téléphone passe entre les mains des vendeurs et des clients.

Code PIN 4 à 6 chiffres au lancement et au retour d'arrière-plan.
Stocke un hash, jamais le PIN en clair (crypto + flutter_secure_storage).
Biométrie optionnelle si disponible.
Prévois un chemin de récupération (question secrète ou fichier de sauvegarde).
PHASE 6 — Numéros de téléphone et relance
Normalise tous les numéros en E.164 à partir de l'indicatif du pays choisi à l'onboarding : suppression du 0 initial, suppression des espaces et tirets, pas de + dans l'URL wa.me.
Aperçu du message de relance avant envoi, avec possibilité de le modifier.
Repli automatique sur le SMS si WhatsApp n'est pas installé.
Écris des tests unitaires avec des formats réels (07 XX XX XX XX, +225 07 XX XX XX XX, 0022507XXXXXXX).
PHASE 7 — Marge brute, dépenses et résultat net

Ce que l'app appelle « bénéfice net » est en réalité une marge brute : aucune charge n'est déduite. Le commerçant peut se croire rentable alors qu'il ne l'est pas.

Renomme « bénéfice net » en « marge brute » partout (UI incluse).
Nouveau modèle Depense (nouveau typeId libre) : id, libelle, montant, date, categorie (loyer, transport, électricité, réapprovisionnement, autre).
Écran simple de saisie des dépenses.
Tableau de bord : CA · Marge brute · Dépenses · Résultat net, sur le jour, la semaine et le mois.
PHASE 8 — Build web et publicité
google_mobile_ads n'a pas d'implémentation web : le build web casse actuellement.
Isole AdMob derrière une interface (AdServiceInterface) avec import conditionnel et une implémentation no-op pour le web.
Ajoute un flag de configuration pubsActivees, désactivé par défaut.
Objectif de sortie : flutter build web --release → OK.
PHASE 9 — Synchronisation (préparer, ne pas activer)

Le SyncService actuel ne fait que pousser vers Firestore : il n'y a aucune restauration possible. Ce n'est donc pas une sauvegarde.

Refactorise en synchronisation bidirectionnelle : deviceId, lastModified sur chaque entité, résolution last-write-wins avec journal des conflits.
L'app doit fonctionner parfaitement sans Firebase configuré (dégradation silencieuse, aucun crash, aucun blocage au démarrage).
Ne l'active pas : laisse-la derrière un flag tant que je n'ai pas branché mon projet Firebase.
PHASE 10 — Tests

Tests unitaires minimum :

CaisseService : total, marge à partir des prix figés, cas du panier vide, quantités multiples.
Money : arrondis, devise à 0 décimale, devise à 2 décimales.
DetteService : normalisation E.164, génération du message, paiement partiel.
Export → import : aller-retour sans perte de données.
Test de widget sur le parcours panier → encaissement.
LIVRABLE FINAL

Crée à la racine un fichier CHECKLIST.md listant tout ce que je dois faire manuellement, avec les liens et les étapes exactes : projet Firebase, flutterfire configure, keystore de signature, éventuels identifiants AdMob, Play Console.

Termine par un récapitulatif de ce qui a changé, de ce qui reste ouvert, et des risques que tu as identifiés mais pas traités.
