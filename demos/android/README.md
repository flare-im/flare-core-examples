# Flare Core Android Demo

Install Python 3.12+, Android Studio, JDK 17, Android SDK 35, CMake 3.22.1, and NDK 28.2.13676358.

```sh
python3 scripts/bootstrap.py
./gradlew :app:assembleDebug
```

Open this directory in Android Studio or install the debug APK on an emulator. Enter the Core HTTP base URL, WebSocket URL, tenant, user ID and access token in the app. HTTP/WS and SDK-managed development login are for a local development gateway only. A host-machine service normally uses `10.0.2.2` from the Android emulator.
