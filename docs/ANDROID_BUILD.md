# Android Build and Validation

## Automated debug APK build

The repository includes `.github/workflows/android-debug.yml`. It builds a debug APK when code is pushed to `main`, or when **Actions → Android Debug APK → Run workflow** is started manually.

The workflow uses the project-compatible Godot 4.3 stable editor and matching Android export templates, OpenJDK 17, Android Platform 34, Build Tools 34.0.0, NDK 23.2.8568313 and CMake 3.10.2.4988404. These SDK versions follow the Godot 4.3 Android export documentation.

The output is uploaded as the `project-unknown-android-debug` artifact and retained for 7 days. Download it from the completed workflow run's **Artifacts** section. This is a debug build for internal device testing, not a production release. Each workflow run creates a fresh temporary debug key, so uninstall an earlier test build before installing an APK from a later run.

The Android preset uses package ID `com.inksys.projectunknown`, targets ARM64 only, and enables the INTERNET permission for HTTPS and multiplayer networking. The package ID is a project default and must be confirmed before any public release.

## Required toolchain for local export

- Godot 4.3 stable and matching Android export templates.
- OpenJDK 17.
- Android SDK Platform-Tools 34.0.0 or later.
- Android SDK Build-Tools 34.0.0.
- Android SDK Platform 34.
- Android SDK Command-line Tools (latest).
- CMake 3.10.2.4988404.
- NDK 23.2.8568313.
- A physical Android device for touch, thermal and performance validation.

## Import and parse

1. Import the project folder containing `project.godot` in Godot.
2. Wait for asset import to finish.
3. Run the project and verify registration/login, profile load, account-to-lobby transition, return-to-account and logout.
4. Run a headless dedicated server with `godot --headless --path . -- --server`.
5. Apply the game-ticket migration and deploy both Edge Functions in a test Supabase project; configure the game-server shared secret on the function and dedicated server.
6. Run two clients against the same reachable host and verify ticket redemption, verified identity binding, roster changes and disconnect cleanup.

## Android device validation

1. Install the debug APK on a physical Android device.
2. Verify startup, orientation, touch input, network connectivity, account flow and lobby behavior.
3. Inspect memory use, frame pacing and thermal behavior during a sustained session.
4. Confirm the APK can be upgraded only with a package signed by the same debug key; debug signing is not a release-signing process.

## Release gate

Do not publish until GDScript parsing, scene/runtime tests, live ticket authentication, encrypted transport or proof-of-possession, server-authoritative match logic, privacy/moderation controls, Android device QA and release signing have all been verified. A successful export alone does not satisfy this gate.

Never put Supabase secret/service-role keys or release keystore credentials in the repository or APK. The debug workflow does not need Supabase credentials and must not deploy backend resources.
