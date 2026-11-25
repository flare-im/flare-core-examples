# Standalone Core demo exports

The six exports are maintained here alongside the existing integration apps. Desktop exports reuse `apps/` platform shells and `shared/vue-reference/`. Mobile exports have Core-specific app targets. The private integration apps continue to use commercial adapters through their existing build entry points.

1. Build the public Engine WASM, Android JNI, and iOS device and simulator artifacts. Use the Engine revision in `dependencies.lock.json`.
2. Run `python3 scripts/package-demo-sdk.py --out /path/to/release --tag demo-sdk-v0.1.0` from the repository root. Upload the three SDK archives to that tag in `flare-core-sdk` and record the generated `dependencies.lock.json` here.
3. Run `python3 scripts/export-demo.py web /path/to/new/flare-core-web-demo`. The same command accepts `android`, `electron`, `flutter`, `ios`, and `tauri`.
4. Bootstrap and build each export from a separate directory with the commands in its README. Commit the dependency lockfiles produced by the validated builds back under `demos/<platform>/`, then regenerate the standalone checkout.
5. Publish the validated trees to the matching demo repositories on `dev`. Each checkout includes a standalone build workflow with only public dependencies.

`scripts/bootstrap.py` in each export resolves pinned source commits from the public Flare repositories and verifies the SHA-256 of every native archive. It restores those dependencies inside the application's ignored `.flare/` directory. The native artifacts are built once and reused by the relevant demos.
