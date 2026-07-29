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
- **Phase 2** — incomplète. L'export de sauvegarde fonctionne via `share_plus`. L'import est désactivé : `file_picker` ne compile pas avec la migration Built-in Kotlin de Flutter.
- **Phases 3 à 10** — à faire.
- **Design** — non commencé. Les polices `.ttf` sont sur le disque mais non suivies par Git, et la section `fonts:` a été retirée de `pubspec.yaml`.

---

## Règles permanentes

1. **Ne jamais recréer le projet.** Pas de `flutter create`, pas de suppression de dossier. Travail incrémental uniquement.
2. **Ne jamais changer un `typeId` Hive existant ni renuméroter un `@HiveField`.** On ne peut qu'ajouter de nouveaux champs, avec de nouveaux index, nullables ou avec valeur par défaut.
3. **Aucune publicité sur l'écran Caisse**, sous aucune forme. La rapidité de vente est le cœur du produit.
4. **Aucun montant affiché sans passer par le formateur central.** Jamais de « 1 500,00 FCFA ».
5. **Une phase à la fois.** À la fin de chaque phase : `flutter analyze` à zéro erreur, `flutter test` au vert, commit, push — puis **arrêt**. Le propriétaire installe l'APK et teste sur son téléphone avant qu'on enchaîne.
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