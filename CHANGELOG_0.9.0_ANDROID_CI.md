# 0.9.0 preparation — Android CI

## Added
- Android debug export preset with ARM64 target and INTERNET permission.
- GitHub Actions workflow that installs Godot 4.3 and its matching Android export templates/toolchain, creates a temporary debug signing key, smoke-tests the main scene, validates the exported APK and uploads it as a 7-day artifact.
- Android build and artifact download documentation.
- Regression tests for the export preset and CI workflow.

## Safety and release scope
- Debug APK only; no production release signing is configured. Each CI run uses a fresh temporary debug keystore, so older test installs must be uninstalled before installing a newer artifact.
- No Supabase credentials are required by the build workflow.
- No Supabase schema/function deployment or public game-server deployment is performed.
- Package ID `com.inksys.projectunknown` is a development default and must be confirmed before a public release.

## Verification status
- Python contract tests: 77/77 passed.
- Edge Function tests: 5/5 passed.
- Strict TypeScript checks: both Edge Function files passed independently.
- Godot 4.7.2 headless import and scene startup: exit code 0.
- YAML syntax: parsed successfully.
- Android APK export: pending a real GitHub Actions run; local environment lacks Android SDK/build-tools and Godot 4.3 export templates.
