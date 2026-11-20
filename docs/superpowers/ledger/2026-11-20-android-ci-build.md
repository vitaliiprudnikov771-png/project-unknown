# Android CI Build Ledger

Base: `PROJECT_UNKNOWN_0.8.2_GODOT_RUNTIME_FIX.zip`.

Ruling: Build a debug APK only — release signing is not appropriate before package identity and release ownership are finalized; cost if wrong is that this artifact cannot be distributed as a production release.
Ruling: Target ARM64 only for the first APK — reduces download size and matches the user's modern Android target; cost if wrong is that older 32-bit-only devices will not run it.
Ruling: Keep source out of `vitaliiprudnikov771-png/my-project` — it is public and contains a separate school project; cost if wrong is a missed convenient upload, while the alternative risks exposing source and mixing unrelated work.

TDD: Android build contract tests first failed because the export preset/workflow were absent; implementation added the expected preset/workflow and focused tests passed.
TDD: Temporary debug signing test first failed because no ephemeral key step existed; added a per-run key under RUNNER_TEMP and exported its standard debug variables; focused tests passed.
TDD: Main-scene smoke test first failed because the workflow did not launch the scene; added a headless startup step; focused tests passed.

Verification: Python suite 76/76; Edge Function tests 5/5; strict TypeScript check passed independently for both Edge Functions; workflow YAML parsed and trigger/permissions/action versions verified; Godot 4.7.2 local headless import and main-scene startup exit 0; compileall passed; source/config secret scan clean.
Limitation: Local APK export was attempted but could not run because the environment has no Android SDK/build-tools, Java 17 or Godot 4.3 templates. The only installed editor is Godot 4.7.2. A real Godot 4.3 APK build still requires a GitHub Actions run after the source is pushed and the workflow is manually dispatched or triggered by a pull request.
Final review: self-review (no subagent tool). Workflow uses read-only repository permissions, no secrets, a temporary debug key, APK validation and bounded artifact retention. No production release signing or backend deployment.
Status: implementation and local verification complete; cloud APK build pending GitHub Actions execution against the development branch.
