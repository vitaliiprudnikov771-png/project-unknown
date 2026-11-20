# PROJECT UNKNOWN — 0.9.0 Android CI Preparation

Android-first Godot 4.3+ multiplayer prototype. Version 0.9.0 prepares repeatable cloud builds of a debug Android APK. The latest verified gameplay/runtime source remains 0.8.2, including the Supabase account flow, in-memory session service, original 3D block lobby, ENet movement prototype and authenticated game-server handshake. This is still an early development build, not a finished game.

## Android CI
- `.github/workflows/android-debug.yml` builds a Godot 4.3 Android debug APK on pushes to `main` or manual dispatch.
- Download the `project-unknown-android-debug` artifact from the completed GitHub Actions run.
- The workflow uses matching Godot export templates, Java 17 and the Android SDK toolchain.
- This is a debug APK only. Each CI run uses a fresh temporary debug key, so uninstall an older build before installing a newer run. No release keystore or Supabase secret is included.
- See `docs/ANDROID_BUILD.md` for toolchain and device validation steps.

## Account and profile backend
- Supabase Auth email/password registration and sign-in use HTTPS.
- `public.player_profiles` stores username, display name, avatar, level, XP and coins.
- RLS restricts profile access; the client cannot directly grant coins, XP, level or inventory.
- The publishable key in `scripts/auth_screen.gd` is intended for public clients. Never place a Supabase secret or `service_role` key in the APK.
- `Session` keeps the access token and loaded profile in memory across scenes; it does not write credentials to disk.

## 3D lobby and mobile controls
- Original procedural block/low-poly lobby built from Godot primitives.
- Third-person player, gravity, jumping and touch camera drag.
- On-screen mobile movement and jump buttons.
- Lobby displays the account username, level and coin balance.

## Development multiplayer transport
The `Network` Autoload supports ENet clients and a headless dedicated-server mode. The server listens on UDP `2456`, accepts up to 32 peers, owns player physics bodies, bounds/rate-limits movement input and broadcasts player positions at 20 Hz. Stale input is reset after 250 ms.

### Authenticated game-server handshake
1. The signed-in client requests a random, 60-second ticket from `issue-game-ticket` over HTTPS.
2. The client sends only that ticket through Godot `SceneMultiplayer.send_auth()`; it does not send the Supabase access token or a client-supplied user ID over ENet.
3. The dedicated server redeems the ticket over HTTPS with a server-only shared secret.
4. The redemption function consumes a valid ticket once and returns the Auth-linked user identity and public profile.
5. The server binds the ENet peer to that verified identity before creating the player body.

Tickets are random, stored as SHA-256 hashes and single-use. Current opaque `sb_secret_` keys are sent only in the `apikey` header; the legacy JWT `service_role` fallback also uses a Bearer header.

**Deployment is not included:** the migration and Edge Function files are source artifacts only. They have not been applied/deployed to the connected Supabase project. The dedicated server has not been hosted.

**Security limitation:** ENet traffic remains unencrypted, so a ticket intercepted before redemption may be replayed. Do not expose this development server publicly until encrypted transport or proof-of-possession, rate limiting, abuse controls and monitoring are implemented.

## Run locally
Open this folder in Godot 4.3+ and run `project.godot`. A dedicated server can be started after configuring the environment in `server/.env.example`:

```bash
godot --headless --path . -- --server
```

## Verification
The full 0.9.0 source archive delivered alongside this repository snapshot contains the extended 76 Python contract tests, 5 mocked Edge Function handler tests and strict TypeScript checks. The GitHub branch also includes a compact smoke-contract suite:

```bash
python -m unittest discover -s tests -p 'test_project_contracts.py' -v
```

Godot 4.7.2 stable on Linux x86_64 imported the local 0.9.0 source package and launched the main auth scene headlessly. This does not prove Godot 4.3 runtime behavior, Android export, live Supabase integration or two-client multiplayer.

## Roadmap
- Run the Android Actions workflow and test the APK on a physical device.
- Reconcile/apply the game-ticket migration and deploy both Edge Functions in an approved Supabase environment.
- Test two-client authentication and movement.
- Add encrypted transport/proof-of-possession and complete server-side match rules.
- Build one complete original mode before expanding into parties, chat, inventory, economy and additional modes.
