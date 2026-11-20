-- One-time login tickets for the dedicated Godot game server.
-- Tickets are stored as SHA-256 hashes and are never readable by client roles.

create table if not exists public.game_login_tickets (
    token_hash text primary key
        check (token_hash ~ '^[0-9a-f]{64}$'),
    user_id uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    expires_at timestamptz not null,
    consumed_at timestamptz,
    constraint game_login_tickets_expiry_after_creation
        check (expires_at > created_at)
);

create index if not exists game_login_tickets_user_created_idx
    on public.game_login_tickets (user_id, created_at desc);

create index if not exists game_login_tickets_expires_idx
    on public.game_login_tickets (expires_at);

alter table public.game_login_tickets enable row level security;

-- No user-facing policy is intentionally created. Only trusted Edge Functions
-- use the service-role key to issue and atomically consume tickets.
revoke all on table public.game_login_tickets from public, anon, authenticated;
grant select, insert, update, delete on table public.game_login_tickets to service_role;

comment on table public.game_login_tickets is
    'Private one-time game login tickets. token_hash is SHA-256; client roles have no access.';
