# Caisse de Poche

Application Flutter **hors-ligne d'abord** de caisse, stock et carnet de dettes, destinée aux petits commerçants. Elle remplace le carnet papier. Android en priorité, web ensuite.

Stockage local : **Hive**. Aucune dépendance réseau pour fonctionner.

---

## Où trouver le plan

- **`docs/PHASES.md`** — le plan de travail complet, Phase 0 à Phase 10. C'est la référence.
- **`docs/PLAN-DESIGN.md`** — l'identité visuelle, à appliquer une fois les phases fonctionnelles terminées.
- **`design/maquette.html`** — maquette validée. Référence pour les couleurs, la typographie et les parcours. Ce n'est pas une source de données.
- **`CHECKLIST.md`** — ce que le propriétaire doit faire manuellement (Firebase, keystore, Play Console).

Lis ces fichiers avant de commencer quoi que ce soit.

---

## État actuel

- **Phase 0** — terminée. Le projet compile.
- **Phase 1** — terminée. Prix d'achat figés dans `ItemVendu`, montants en unités mineures, décimales par devise.
- **Crash au démarrage** — résolu. La cause était `firebase_core` et `google_mobile_ads`, qui s'initialisent côté natif avant Dart et faisaient tomber le processus faute de configuration. **Les deux ont été retirés**, ainsi que `cloud_firestore` et `connectivity_plus`. `SyncService` et `AdService` sont des implémentations neutres qui ne font rien. Les trois APK démarrent correctement sur un appareil réel.
- **Phase 2** — terminée. Export et import de sauvegarde fonctionnent (via `file_selector`, `file_picker` ayant été abandonné), testés en debug et en release sur appareil réel.
- **Phase 3** — terminée. Panier : deux actions, « Encaisser » et « Mettre en dette » (sélection d'un client existant ou saisie rapide). `Transaction.modePaiement` (especes/credit/mobileMoney) et `Dette.transactionId` relient les deux. Nouveau modèle `PaiementDette` (typeId 7) pour l'historique des paiements partiels. Tableau de bord de l'écran Caisse : CA du jour, bénéfice net et encaissements du jour affichés séparément — un paiement de dette n'est jamais recompté comme une vente. Testée sur téléphone : vente au comptant, vente à crédit et distinction CA/encaissements fonctionnent. Corrections après retour terrain : `DetteProvider` n'était pas rechargé après une vente à crédit (la dette n'apparaissait dans le carnet qu'après un rechargement manuel) ; le téléphone du client est désormais optionnel partout (panier « Mettre en dette » et formulaire du carnet de dettes), les boutons WhatsApp/SMS se désactivant proprement si aucun numéro n'est renseigné.
- **Phase 4** — terminée. Annulation et correction de vente : `Transaction.annulee` / `dateAnnulation` / `motifAnnulation` (nouveaux champs additifs, `@HiveField` 10-12), méthode `marquerAnnulee()`. `CaisseService.annulerTransaction()` remet le stock en rayon, marque la transaction annulée sans jamais la supprimer, et l'exclut des statistiques du jour (`transactionsDuJour()` filtre désormais `!annulee`) — mais elle reste consultable dans un nouveau « Journal des ventes » (icône historique dans l'AppBar de l'écran Caisse), y compris les ventes annulées, avec le nom du client affiché pour les ventes à crédit. Pour une vente à crédit : l'annulation supprime la dette liée si aucun paiement n'a encore été reçu, mais est bloquée si un paiement partiel existe déjà (pour ne jamais faire disparaître un encaissement réel). Testée sur téléphone.
- **Phase 5** — terminée (code). Verrouillage par code PIN (4-6 chiffres) au lancement et au retour d'arrière-plan (`WidgetsBindingObserver` dans `main.dart`, `AppLifecycleState.paused` → reverrouille). Nouveau `PinService` (hash SHA-256 salé, jamais le PIN en clair) stocké via `flutter_secure_storage` (nouveau plugin natif, validé explicitement par le propriétaire — pas de biométrie pour l'instant, cf. décision du 2026-07-30). Question secrète pour réinitialiser le PIN en cas d'oubli. Activation/désactivation/changement depuis l'onglet Paramètres — désactivé par défaut, aucune friction ajoutée pour qui ne l'active pas. **Pas encore testée sur téléphone.**
- **Phase 6** — terminée (code). Numéros normalisés en E.164 (`lib/utils/telephone.dart`) à partir de l'indicatif du pays choisi à l'onboarding (`CurrencyProvider.indicatifPays`, stocké dès l'onboarding via `country_picker` et avec un repli par pays pour les installations antérieures) : zéro initial, espaces, tirets et préfixe `00` retirés, un indicatif déjà présent (le nôtre ou celui d'un autre pays) n'est jamais réécrit. Normalisation appliquée à l'ajout d'une dette et défensivement au moment de l'envoi (numéros importés/anciens). Message de relance désormais modifiable avant envoi (WhatsApp et SMS) dans `DetteDetailSheet`. Repli automatique sur SMS si l'ouverture de WhatsApp échoue. `flutter analyze` (0 erreur) et `flutter test` (14 tests, tous au vert) passent. **Pas encore testée sur téléphone.**
- **Phase 7** — terminée (code). « Bénéfice net » renommé partout en **marge brute** (`ItemVendu.margeBrute`, `Transaction.margeBrute`/`margeBruteMineur` — renommage sûr, les index `@HiveField` 4 et 8 sont inchangés) pour ne plus laisser croire qu'il s'agit d'un résultat après charges. Nouveau carnet de **dépenses** : modèle `Depense` (typeId 9) et enum `CategorieDepense` (typeId 8 : loyer, transport, électricité, réapprovisionnement, autre), `DepenseService`/`DepenseProvider`, inclus dans l'export/import de sauvegarde (avec repli de compatibilité pour les anciennes sauvegardes sans dépenses). Nouvel onglet **Rapport** (5ᵉ onglet de la navigation) : sélecteur Jour / Semaine / Mois (`lib/utils/periodes.dart`) et tableau de bord CA, marge brute, dépenses, résultat net (marge brute − dépenses, en rouge si négatif), avec liste des dépenses de la période et suppression. Les méthodes de calcul par période (`CaisseService.totalMineurSur`/`margeBruteMineurSur`) sont entièrement nouvelles, ajoutées à côté des méthodes existantes du jour utilisées par l'écran Caisse — aucune des méthodes ni des tests déjà en place n'a été touchée. `flutter analyze` (0 erreur) et `flutter test` (21 tests, tous au vert) passent. **Pas encore testée sur téléphone.**
- **Phases 8 à 10** — à faire.
- **Design** — non commencé. Les polices `.ttf` sont sur le disque mais non suivies par Git, et la section `fonts:` a été retirée de `pubspec.yaml`.

---

## Règles permanentes

1. **Ne jamais recréer le projet.** Pas de `flutter create`, pas de suppression de dossier. Travail incrémental uniquement.
2. **Ne jamais changer un `typeId` Hive existant ni renuméroter un `@HiveField`.** On ne peut qu'ajouter de nouveaux champs, avec de nouveaux index, nullables ou avec valeur par défaut.
3. **Aucune publicité sur l'écran Caisse**, sous aucune forme. La rapidité de vente est le cœur du produit.
4. **Aucun montant affiché sans passer par le formateur central.** Jamais de « 1 500,00 FCFA ».
5. **Phases enchaînées.** À la fin de chaque phase : `flutter analyze` à zéro erreur, `flutter test` au vert, mise à jour de l'État actuel, commit, push — puis **enchaîner directement sur la phase suivante sans s'arrêter**. À la toute fin (dernière phase traitée dans la session), donner la liste complète et précise de ce que le propriétaire doit vérifier sur son téléphone pour chaque phase livrée.
6. **Aucun nouveau plugin natif sans validation explicite.** Flutter 3.44 casse plusieurs plugins qui n'ont pas suivi la migration Built-in Kotlin. En cas de doute, préférer du Dart pur ou un paquet maintenu par l'équipe Flutter.
7. **Avant chaque push : `git status`.** Tout ce que `pubspec.yaml` référence doit être suivi par Git. La CI ne voit que ce qui est commité — une déclaration d'asset sans le fichier casse le build.
8. **Firebase reste dehors** jusqu'à la Phase 9, et uniquement après que le propriétaire ait lancé `flutterfire configure`. Le fichier `google-services.json` présent est inerte et ne doit pas être commité.
9. **Compilation locale interdite.** `flutter analyze` et `flutter test` sont autorisés en local, ils sont légers. `flutter build apk`, `flutter build appbundle` et toute tâche Gradle sont interdits — la machine n'a que 4 Go de RAM et Gradle ne termine jamais (il tourne pendant une heure puis rien, ce n'est pas récupérable). Les APK sont produits uniquement par GitHub Actions. Procédure : `flutter analyze` → `flutter test` → commit → push — et c'est GitHub qui construit. Impossible de vérifier soi-même qu'un plugin natif compile ; on pousse et on attend le retour du propriétaire après consultation du build sur GitHub.

---

## Environnement

- Le propriétaire **ne peut pas compiler en local** : sa chaîne Android est cassée. Tous les APK sont produits par **GitHub Actions** (`.github/workflows/build_apk.yml`), qui génère trois artefacts : `minimal`, `debug`, `release`.
- Il n'a **ni `adb` ni logcat**. Tout diagnostic doit être visible sur l'écran du téléphone.
- `lib/main_minimal.dart` est un point d'entrée de diagnostic qui n'affiche qu'un écran uni. Il permet de distinguer un problème natif d'un problème Dart. Le conserver.

---

## Marché

Afrique de l'Ouest, francophone. Devise principale : le franc CFA, **sans décimale**. Les relances de dettes passent par WhatsApp. Toute l'interface est en français.