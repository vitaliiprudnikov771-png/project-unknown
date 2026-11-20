# PROJECT UNKNOWN — development status

**Current milestone:** source import and Android CI preparation on branch `codex/project-bootstrap-0.9.0`.

## Imported source
- Godot 4.3+ project configuration and Android debug export preset.
- Supabase Auth screen, in-memory session manager and profile loading.
- Original procedural 3D block-style lobby with mobile controls and third-person player.
- ENet client/dedicated server autoload, server-owned movement, input bounds/rate limiting, stale-input timeout and authenticated single-use ticket handshake.
- Supabase Edge Function sources and migration for short-lived one-time game login tickets.
- GitHub Actions Android debug APK workflow.
- Build/security/release documentation.

## Local verification recorded for the 0.9.0 source package (2026-11-20)
- Python contract suite: **52/52 passed**.
- Node Edge Function handler tests: **5/5 passed**.
- Strict TypeScript checks: both ticket Edge Functions passed.
- Python compileall: passed.
- Godot 4.7.2 Linux headless editor import: passed.
- Godot 4.7.2 main-scene smoke test: passed.
- YAML workflow parse and secret scan: passed.

These checks do not prove Godot 4.3 runtime behavior, Android export, live Supabase integration, public server deployment, or multiplayer behavior across real devices.

## Release blockers
1. Run the GitHub Actions Android debug workflow and inspect its APK artifact.
2. Install and test the APK on a physical Android device.
3. Reconcile and apply the game-ticket migration, then deploy both Edge Functions to the intended Supabase project.
4. Deploy the dedicated ENet server and run two-client authentication/movement tests.
5. Add encrypted transport or proof-of-possession, rate limiting, abuse controls and monitoring before public hosting.

## Security
- Never commit Supabase secret/service_role keys or game-server shared secrets.
- The client-side Supabase publishable key is public by design.
- The current development ENet transport is not encrypted. Do not expose the development game server publicly.
- The GitHub repository is currently public; review that visibility before placing additional proprietary or sensitive source in it.
