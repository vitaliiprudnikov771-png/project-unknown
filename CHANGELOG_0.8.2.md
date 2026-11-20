# PROJECT UNKNOWN 0.8.2

Date: 2026-11-20

## Fixes
- Added explicit `int` annotations to the `send_auth()` and `complete_auth()` result variables in `scripts/network_client.gd`. The `multiplayer` property is dynamically typed at those call sites, so inferred declarations (`:=`) failed GDScript parsing. The calls and network/authentication behavior are unchanged.
- Added a regression test for all three affected declarations.

## Verification
- Godot 4.7.2 stable, Linux x86_64: headless editor import completed with no GDScript parser errors; main auth scene launched headlessly with exit code 0 and no runtime errors.
- Python contract tests: 45/45 passed.
- Edge Function handler tests: 5/5 passed with Node 22 `--experimental-strip-types`.
- Strict TypeScript checks: both Edge Function files passed with the repository's Deno ambient declarations.
- Security scan: no embedded Supabase secret keys, JWT-like credentials or private-key blocks found.

## Not verified
- Godot 4.3 binary compatibility was not directly executed (the project retains its Godot 4.3+ target).
- Android export, matching export templates, SDK setup, APK installation and physical-device QA.
- Live Supabase deployment, live ticket redemption and two-client ENet lifecycle.
