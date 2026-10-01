# MvolaSave (Android)

Version mobile Flutter de MvolaSave, entièrement hors ligne. Elle reprend
exactement la logique de la version web (`../script.js`) : mêmes grilles,
même algorithme d'optimisation, mêmes validations.

- `lib/tariffs.dart` : grilles tarifaires
- `lib/optimizer.dart` : algorithme, lecture et formatage des montants
- `lib/fee_tables.dart` : calcul des tables en arrière-plan au lancement
- `lib/home_page.dart` : interface

## Construire l'APK

```sh
flutter test
flutter build apk --release --split-per-abi \
  --target-platform android-arm,android-arm64 \
  --obfuscate --split-debug-info=build/symbols
```

Les APK sont dans `build/app/outputs/flutter-apk/` :
`app-arm64-v8a-release.apk` convient à la quasi-totalité des téléphones
récents, `app-armeabi-v7a-release.apk` aux plus anciens.

Le workflow GitHub Actions « APK Android » les construit automatiquement à
chaque modification du dossier `mobile/`.
