# PROJECT UNKNOWN — Dedicated Server

The dedicated server uses Godot 4.3+ and the same `Network` Autoload/RPC path as the client.

## Required environment

The server **fails closed** and does not bind UDP 2456 unless all three variables are set:

- `PROJECT_UNKNOWN_SUPABASE_URL`: Supabase project HTTPS URL.
- `PROJECT_UNKNOWN_SUPABASE_PUBLIC_KEY`: project publishable key (`sb_publishable_...`).
- `PROJECT_UNKNOWN_GAME_SERVER_SHARED_SECRET`: high-entropy secret of at least 32 characters. This must match the Supabase Edge Function secret `GAME_SERVER_SHARED_SECRET`.

Copy `.env.example` as a template for your host's environment configuration. Do not commit actual secrets. Do not place the server secret or Supabase service-role key in the Android client.

## Authentication flow

1. The signed-in client requests a 60-second one-time ticket from `issue-game-ticket` over HTTPS.
2. Godot's `SceneMultiplayer` authentication phase sends that opaque ticket through `send_auth`; regular gameplay RPCs are not enabled for an unverified peer.
3. The dedicated server redeems the ticket over HTTPS through `redeem-game-ticket`, using its server-only shared secret.
4. The function consumes the ticket atomically, checks expiry and returns the associated Supabase user ID and public profile fields.
5. Only after verification does the server call `complete_auth()`. The normal `peer_connected` handler then creates the player's server-owned body.

The Supabase access token is never sent through ENet. Ticket hashes, not raw tickets, are stored in Postgres. The ticket is single-use and expires after 60 seconds. The Edge Functions read the current injected `SUPABASE_PUBLISHABLE_KEYS.default` and `SUPABASE_SECRET_KEYS.default` values; legacy `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` variables are fallback-only.

## Backend preparation

The local backend source is in `backend/supabase/`:

- Apply `migrations/20261120170000_game_login_tickets.sql` to the intended Supabase project.
- Deploy `issue-game-ticket` with JWT verification enabled.
- Deploy `redeem-game-ticket` with platform JWT verification disabled; the handler independently checks `x-game-server-secret` before accessing ticket storage.
- Set `GAME_SERVER_SHARED_SECRET` in Supabase Edge Function secrets and the matching server environment variable.

The SQL migration and functions in this archive are source artifacts only. They have **not** been applied or deployed to the connected project. The timestamped migration was authored without the Supabase CLI because it is unavailable here; reconcile it with CLI migration history before applying it to any database.

## Important security limitation

ENet uses UDP and the current transport does not encrypt gameplay packets. Short-lived, single-use tickets reduce the impact of interception but do not provide transport confidentiality or replay resistance against an attacker who captures a ticket before redemption. Do not expose this development server publicly until an encrypted transport or proof-of-possession handshake, rate limiting, abuse controls, monitoring and production deployment hardening are completed.

Run the server locally only after configuring the environment:

```bash
godot --headless --path . -- --server
```
