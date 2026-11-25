# Flare Core Flutter Demo

Install Python 3.12+, Flutter with Dart 3.11+, and the Android or iOS toolchain reported by `flutter doctor`.

```sh
python3 scripts/bootstrap.py
flutter pub get
flutter run
```

Choose an Android emulator or iOS simulator. Enter the Core HTTP base URL, WebSocket URL, tenant, user ID, and access token. Use trusted TLS on iOS or in release builds. Android debug builds also support a local development gateway.

Build an Android APK with `flutter build apk --debug` or an iOS simulator app with `flutter build ios --simulator --no-codesign`.
