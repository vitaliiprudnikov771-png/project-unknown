function readDefaultKeySet(name: string): Record<string, string> {
  const rawValue = Deno.env.get(name);
  if (!rawValue) {
    return {};
  }

  try {
    const parsed: unknown = JSON.parse(rawValue);
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return {};
    }

    return Object.fromEntries(
      Object.entries(parsed as Record<string, unknown>).filter(
        (entry): entry is [string, string] => typeof entry[1] === "string",
      ),
    );
  } catch {
    return {};
  }
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SECRET_KEYS = readDefaultKeySet("SUPABASE_SECRET_KEYS");
// Prefer the current secret-key map; keep legacy fallback for older local stacks.
const SUPABASE_SECRET_KEY = SUPABASE_SECRET_KEYS.default ?? "";
const LEGACY_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = SUPABASE_SECRET_KEY || LEGACY_SERVICE_ROLE_KEY;
const GAME_SERVER_SHARED_SECRET = Deno.env.get("GAME_SERVER_SHARED_SECRET") ?? "";

function jsonResponse(status: number, payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store, max-age=0",
      pragma: "no-cache",
    },
  });
}

function constantTimeEquals(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  if (leftBytes.length !== rightBytes.length) {
    return false;
  }

  let difference = 0;
  for (let index = 0; index < leftBytes.length; index += 1) {
    difference |= leftBytes[index] ^ rightBytes[index];
  }
  return difference === 0;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return bytesToHex(new Uint8Array(digest));
}

function serviceHeaders(prefer = "return=minimal"): HeadersInit {
  const headers: Record<string, string> = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    "content-type": "application/json",
    prefer,
  };
  // New sb_secret_ keys are opaque API keys, not JWTs. Only the legacy
  // service_role JWT is valid in the Authorization bearer header.
  if (!SUPABASE_SECRET_KEY && LEGACY_SERVICE_ROLE_KEY) {
    headers.authorization = `Bearer ${LEGACY_SERVICE_ROLE_KEY}`;
  }
  return headers;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || GAME_SERVER_SHARED_SECRET.length < 32) {
    return jsonResponse(503, { error: "ticket_redeemer_not_configured" });
  }

  const suppliedSecret = req.headers.get("x-game-server-secret") ?? "";
  if (!constantTimeEquals(suppliedSecret, GAME_SERVER_SHARED_SECRET)) {
    return jsonResponse(401, { error: "game_server_authentication_failed" });
  }

  let body: { ticket?: unknown };
  try {
    body = await req.json() as { ticket?: unknown };
  } catch {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const ticket = typeof body.ticket === "string" ? body.ticket : "";
  if (!/^[0-9a-f]{64}$/.test(ticket)) {
    return jsonResponse(400, { error: "invalid_ticket_format" });
  }

  const tokenHash = await sha256Hex(ticket);
  const now = new Date().toISOString();
  const consumeUrl = `${SUPABASE_URL}/rest/v1/game_login_tickets?token_hash=eq.${tokenHash}&consumed_at=is.null&expires_at=gt.${encodeURIComponent(now)}`;
  const consumeResponse = await fetch(consumeUrl, {
    method: "PATCH",
    headers: serviceHeaders("return=representation"),
    body: JSON.stringify({ consumed_at: now }),
  });

  if (!consumeResponse.ok) {
    return jsonResponse(503, { error: "ticket_store_unavailable" });
  }

  const consumedRows = await consumeResponse.json() as Array<{ user_id?: string }>;
  if (!Array.isArray(consumedRows) || consumedRows.length !== 1 || typeof consumedRows[0].user_id !== "string") {
    return jsonResponse(401, { error: "ticket_expired_invalid_or_used" });
  }

  const userId = consumedRows[0].user_id;
  const profileUrl = `${SUPABASE_URL}/rest/v1/player_profiles?select=username,display_name&id=eq.${encodeURIComponent(userId)}&limit=1`;
  const profileResponse = await fetch(profileUrl, {
    method: "GET",
    headers: serviceHeaders(),
  });
  if (!profileResponse.ok) {
    return jsonResponse(503, { error: "player_profile_lookup_failed" });
  }

  const profiles = await profileResponse.json() as Array<{ username?: string; display_name?: string | null }>;
  if (!Array.isArray(profiles) || profiles.length !== 1 || typeof profiles[0].username !== "string") {
    return jsonResponse(403, { error: "player_profile_missing" });
  }

  return jsonResponse(200, {
    user_id: userId,
    username: profiles[0].username,
    display_name: typeof profiles[0].display_name === "string" ? profiles[0].display_name : profiles[0].username,
  });
});
