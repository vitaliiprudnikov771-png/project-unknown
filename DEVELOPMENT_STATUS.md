# PROJECT UNKNOWN — development status

## Current source snapshot

Prepared local source package: `PROJECT_UNKNOWN_0.9.0_CODESPACES_IMPORT.zip`.

The project is an Android-first Godot 4.x prototype with:
- Supabase email/password authentication and player profiles.
- A procedural 3D block-style lobby and mobile controls.
- ENet client/server transport with server-owned movement simulation.
- A short-lived, single-use game-login ticket handshake.
- GitHub Actions workflow source for a debug Android APK.

## Verification completed on 2026-11-20

- Python contract suite: **52/52 passed**.
- Node Edge Function tests: **5/5 passed**.
- TypeScript strict checks: both game-ticket Edge Functions passed.
- Godot 4.7.2 Linux headless editor import: passed.
- Godot 4.7.2 main-scene smoke test: passed.

These checks do not prove Android export, live Supabase integration, public server deployment, or multiplayer behavior across real devices.

## Remaining release blockers

1. Import the full source tree into this repository.
2. Run the Android Debug APK workflow and inspect its artifact.
3. Test the APK on a physical Android device.
4. Apply the game-ticket migration and deploy both Edge Functions to Supabase.
5. Deploy the dedicated ENet server and run two-client authentication/movement tests.
6. Add encrypted transport or proof-of-possession before any public deployment.

## Security notes

- Never commit Supabase secret or service-role keys.
- Keep the game-server shared secret only in server-side environment variables.
- Do not expose the current development ENet server publicly until transport protection, abuse controls, and monitoring are implemented.
