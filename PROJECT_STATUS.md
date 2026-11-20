# PROJECT UNKNOWN — Current Status

**Current milestone:** 0.9.0 preparation — Android debug export preset and GitHub Actions workflow added on top of 0.8.2; no cloud APK run has been performed yet. 0.8.2 remains the latest verified gameplay/runtime source milestone.

**0.8.2 base:** Godot GDScript return-type compatibility patch on top of the 0.8.1 Supabase key compatibility update and authenticated multiplayer handshake and server movement-input hardening, built on the 0.6 session, 3D lobby and ENet movement foundation. This remains an early development build, not a complete game.

## Implemented in the project files
- Godot 4.3+ Android-first starter and Supabase email/password account flow.
- Supabase `player_profiles` schema integration with RLS assumptions documented.
- Runtime `Session` Autoload: transfers the verified account/profile between scenes without writing tokens to disk; account view is restored on return; logout clears session.
- Original procedural 3D block-style lobby, third-person controller and touch movement/jump controls.
- ENet `Network` Autoload: client connect/disconnect, dedicated-server mode, server-owned player physics and rate-limited movement replication.
- Supabase game-ticket backend source: random 256-bit one-time tickets, SHA-256 hashes at rest, 60-second expiry and conditional single-use redemption.
- Client HTTPS ticket request using the Supabase session, followed by Godot `SceneMultiplayer` auth payload; stale/cancelled request responses are isolated by request generation and object identity; the Supabase access token is not sent over ENet.
- Dedicated-server source redeems tickets through an Edge Function using a server-only secret, binds peers to verified Auth identities and spawns only authenticated peers.
- Unverified peers are excluded from roster creation and gameplay state; internal user IDs are not sent in the public roster.
- Edge Functions prefer current `SUPABASE_PUBLISHABLE_KEYS` and `SUPABASE_SECRET_KEYS` environment maps, with legacy fallback.

## Not implemented or not verified
- The SQL migration has not been applied and the Edge Functions have not been deployed to the connected Supabase project.
- Godot 4.7.2 stable on Linux x86_64 successfully imported the project in headless editor mode and launched the main auth scene without parser/runtime errors. Godot 4.3 itself was not run in this environment; ENet auth lifecycle and two-client integration remain untested.
- ENet traffic is still unencrypted. Ticket interception before redemption remains a risk; do not host publicly.
- Encrypted transport/proof-of-possession, rate limiting, matchmaking, reconnect/resume and production hosting/monitoring.
- Authoritative match rules and validation of mode-specific actions.
- Friends, parties, invites, moderated chat, blocking and reporting.
- Inventory, cosmetics, shop, trusted economy/rewards and persistence APIs.
- Playable Bed Wars-like, Egg Wars-like, Sky Wars-like and Sky Block-like modes.
- Final maps, character assets, animations, audio, localization, performance tuning and accessibility.
- Android export/signing, device QA and release packaging.

## Verification evidence (current work session)
- Python contract suite: **52 tests passed** using `python -m unittest discover -s tests -p 'test_*.py' -v`.
- Edge Function handler tests: **5 passed** across the current-key and legacy-key suites using Node 22's experimental TypeScript stripping and mocked Supabase HTTP boundaries.
- Both Edge Function source files passed strict TypeScript checks using `tests/deno-runtime.d.ts` as a minimal Deno global declaration.
- `python -m compileall -q tests` completed successfully.
- Godot 4.7.2 is installed in the Linux x86_64 build environment. Deno, Supabase CLI, psql, Android export templates, Android SDK and an Android device are unavailable. Node 22 with experimental TypeScript stripping ran the Edge Function handler tests. These checks do not prove live Supabase behavior, Godot 4.3 runtime compatibility, production networking or APK build success.
- No migration was applied, no Edge Function was deployed, and no public server was created.


## 0.9.0 Android CI preparation (2026-11-20)
- Added `export_presets.cfg` with an Android debug preset named `Android`, package ID `com.inksys.projectunknown`, app version `0.9.0-dev`, ARM64-only architecture and INTERNET permission.
- Added `.github/workflows/android-debug.yml` for GitHub-hosted builds on pushes to `main` and manual dispatch. It installs Godot 4.3 stable with matching export templates, JDK 17, Android Platform 34, Build Tools 34.0.0, NDK 23.2.8568313 and CMake 3.10.2.4988404.
- The workflow creates a fresh temporary debug signing key per run, smoke-tests the main scene, validates APK archive integrity and package metadata, then uploads `project-unknown-android-debug` for 7 days. Uninstall an older debug APK before installing one from a later run.
- No release keystore, Supabase secret, migration deployment, Edge Function deployment or public server setup is included.
- Local verification: 52/52 Python contract tests passed; 5/5 Edge Function tests passed; each Edge Function passed an independent strict TypeScript check; YAML parsed; Godot 4.7.2 headless import and main-scene startup exited 0.
- Limitations: this environment has no Android SDK, Android build-tools, JDK 17 or Godot 4.3 export templates, and network DNS is unavailable. Local APK export therefore remains unverified. Godot 4.7.2 was used only for local import/startup checks, not as a substitute for the planned Godot 4.3 cloud build. The GitHub Actions run remains pending until the project is uploaded to a private repository.

## Post-0.8 Supabase API-key compatibility review
- Found and fixed a current-key compatibility defect in both game-ticket Edge Functions: opaque `sb_secret_` keys were incorrectly copied into `Authorization: Bearer`, where Supabase treats them as invalid JWTs.
- New secret keys are now sent only through `apikey`; the legacy JWT `SUPABASE_SERVICE_ROLE_KEY` fallback retains its Bearer header.
- Regression tests were changed first and failed against the original implementation, then passed after the fix.
- Official reference: https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys
- This source fix is not deployed to the connected Supabase project. Live function behavior remains unverified until deployment in an approved test environment.

## 0.8 movement hardening verification
- Added RED→GREEN tests for non-finite vector rejection, stale-input expiry, fresh peer timeout initialization, and keeping the sanitizer as a local helper rather than an RPC endpoint.
- Manual self-review caught and corrected an RPC annotation accidentally attached to the local sanitizer helper before packaging.
- The Python tests are source-contract checks; they do not execute GDScript. Godot runtime validation remains unavailable in this environment.

## Next engineering gates
1. Reconcile the local migration with the Supabase CLI, then apply it and deploy both functions only in an explicitly approved Supabase environment.
2. Run Godot 4.3+ import/headless parse and client/server auth lifecycle tests; fix runtime errors before extending multiplayer.
3. Add encrypted transport or a proof-of-possession exchange, rate limiting and abuse controls before any public hosting.
4. Finish lobby UX, player representations and matchmaking.
5. Build one complete, testable game mode before expanding to the other modes.
6. Add social systems, trusted economy, content pipeline, Android QA and release infrastructure.
