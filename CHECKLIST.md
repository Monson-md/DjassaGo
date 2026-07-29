# Checklist manuelle — Caisse de Poche

Ce fichier liste ce qui doit être fait manuellement (hors code) pour faire avancer le projet. Complété au fur et à mesure des phases.

## Firebase et Google Mobile Ads — retirés temporairement

Retirés du projet le 2026-07-28 pour diagnostiquer un crash silencieux au démarrage (l'app se fermait instantanément sur un appareil réel, y compris en debug, sans qu'aucun code Dart n'ait le temps de s'exécuter). Les deux SDK s'initialisent automatiquement au niveau natif Android avant même que Flutter ne démarre :

- `firebase_core` enregistre un `ContentProvider` dans le manifeste fusionné ; sans `google-services.json` traité par le plugin Gradle `google-services` (jamais appliqué dans ce projet) ni `firebase_options.dart` (jamais généré), son initialisation native peut échouer de façon fatale.
- `google_mobile_ads` peut faire échouer le démarrage si sa meta-data `com.google.android.gms.ads.APPLICATION_ID` est absente, mal formée, ou si le SDK est initialisé trop tôt.

Retiré de `pubspec.yaml` : `firebase_core`, `cloud_firestore`, `google_mobile_ads`, ainsi que `connectivity_plus` (qui ne servait qu'à déclencher la synchronisation Firestore).

Retiré du code natif : la meta-data AdMob dans `android/app/src/main/AndroidManifest.xml`, la clé `GADApplicationIdentifier` dans `ios/Runner/Info.plist`.

`lib/services/sync_service.dart` et `lib/services/ad_service.dart` sont maintenant des implémentations neutres (aucun import externe, ne font jamais rien), qui gardent leur interface publique pour qu'une vraie implémentation puisse être réintroduite sans toucher au reste du code.

**Pour réintroduire Firebase (Phase 9), quand tu es prêt :**
1. Créer un projet sur https://console.firebase.google.com
2. `dart pub global activate flutterfire_cli` (déjà fait dans cette session)
3. `flutterfire configure` — nécessite une connexion interactive à ton compte Google/Firebase, à faire toi-même dans un terminal (ex: via `!flutterfire configure` dans Claude Code). Cela génère `lib/firebase_options.dart`.
4. Remettre `firebase_core`/`cloud_firestore` dans `pubspec.yaml`, réécrire `SyncService` pour utiliser `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` (jamais sans options).
5. Tester d'abord avec un APK **debug**, jamais directement en release.

**Pour réintroduire Google Mobile Ads (Phase 8), quand tu es prêt :**
1. Créer un compte AdMob, créer une app, récupérer le véritable App ID (format `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`).
2. Remettre `google_mobile_ads` dans `pubspec.yaml`.
3. Remettre la meta-data dans `AndroidManifest.xml` et `GADApplicationIdentifier` dans `Info.plist` avec le vrai App ID (pas celui de test).
4. Ne jamais appeler `MobileAds.instance.initialize()` avant la première frame rendue (voir la structure différée déjà en place dans `lib/main.dart`).
5. Tester d'abord avec un APK debug.

## file_picker — retiré, remplacé par file_selector (à confirmer sur GitHub Actions)

`file_picker` a été retiré le 2026-07-29 : `flutter build apk --debug` échouait avec `cannot find symbol class FilePickerPlugin`. Cause réelle, confirmée par la documentation officielle Flutter (docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin) : Flutter 3.44 (notre version, sortie 2026-05-18) exige Android Gradle Plugin 9+, qui intègre désormais un support Kotlin natif ("built-in Kotlin"). Les versions de `file_picker` alors installées appliquent encore l'ancien plugin `kotlin-android` manuellement, ce qui crée une extension Kotlin en double et fait échouer le build. C'est un problème connu et documenté (voir miguelpruivo/flutter_file_picker#1973, #1942), pas spécifique à ce projet — la correction dépend des mainteneurs du plugin.

**2026-07-29, plus tard la même session : `file_selector` ajouté et branché** dans `lib/screens/parametres/parametres_screen.dart::_importer()` (sélection de fichier JSON, aperçu via `BackupService.analyserFichier`, choix remplacer/fusionner, puis `BackupService.restaurer`). `flutter analyze` (0 erreur) et `flutter test` (vert) passent en local.

**Non vérifié par un build APK local** : la machine de développement n'a que 4 Go de RAM et les tâches Gradle (`flutter build apk`, etc.) ne se terminent jamais dessus — voir la nouvelle règle 9 de `CLAUDE.md` (compilation locale interdite). La seule vérification possible est le build GitHub Actions après ce push. **Si le build casse sur `file_selector`** (même symptôme que `file_picker` : erreur Kotlin/Gradle liée au plugin), revenir en arrière avec `git revert`, redésactiver l'import dans `_importer()` comme avant, et documenter l'échec ici avec le message d'erreur exact.

Pour information, un essai de build local (avant le redémarrage de la machine) a échoué avec `Failed connecting to the daemon in 4 retries` (daemon Kotlin/Gradle) — un warning notait aussi que `share_plus` applique encore l'ancien plugin Kotlin (KGP), pas `file_selector`. Cet échec n'est donc pas attribuable à `file_selector` ; il n'a pas valeur de test.

## Encore à faire (mis à jour au fil des phases)

- [ ] Keystore de signature Android pour un vrai build de release (actuellement signé avec les clés debug — `flutter run --release` fonctionne mais n'est pas publiable tel quel).
- [ ] Projet Firebase + `flutterfire configure` (voir ci-dessus, volontairement différé).
- [ ] Identifiants AdMob réels (voir ci-dessus, volontairement différé).
- [ ] Compte Play Console pour la publication.
- [ ] Confirmer sur GitHub Actions que le build passe avec `file_selector` (voir ci-dessus) ; sinon revenir en arrière et redésactiver l'import.
- [ ] Décider si le CI reste sur Flutter 3.44.x ou revient temporairement sur la ligne stable précédente (3.41.9) le temps que l'écosystème de plugins rattrape la migration "built-in Kotlin" — voir la discussion dans l'historique de conversation, en attente de décision.
