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
const SUPABASE_PUBLISHABLE_KEYS = readDefaultKeySet("SUPABASE_PUBLISHABLE_KEYS");
const SUPABASE_SECRET_KEYS = readDefaultKeySet("SUPABASE_SECRET_KEYS");
// Prefer current key maps. Legacy names remain only as a migration fallback.
const SUPABASE_ANON_KEY = SUPABASE_PUBLISHABLE_KEYS.default
  ?? Deno.env.get("SUPABASE_ANON_KEY")
  ?? "";
const SUPABASE_SECRET_KEY = SUPABASE_SECRET_KEYS.default ?? "";
const LEGACY_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = SUPABASE_SECRET_KEY || LEGACY_SERVICE_ROLE_KEY;
const GAME_TICKET_TTL_SECONDS = 60;

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

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return bytesToHex(new Uint8Array(digest));
}

function serviceHeaders(): HeadersInit {
  const headers: Record<string, string> = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    "content-type": "application/json",
    prefer: "return=minimal",
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

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    return jsonResponse(503, { error: "ticket_service_not_configured" });
  }

  const authorization = req.headers.get("authorization") ?? "";
  const bearerMatch = authorization.match(/^Bearer\s+(.+)$/i);
  if (!bearerMatch) {
    return jsonResponse(401, { error: "user_session_required" });
  }

  // Ask Supabase Auth for the user instead of trusting a client-supplied user ID
  // or parsing unsigned/unverified JWT claims in the game client.
  const authResponse = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    method: "GET",
    headers: {
      apikey: SUPABASE_ANON_KEY,
      authorization: `Bearer ${bearerMatch[1]}`,
    },
  });

  if (!authResponse.ok) {
    return jsonResponse(401, { error: "invalid_user_session" });
  }

  const authenticatedUser = await authResponse.json() as { id?: string };
  const userId = typeof authenticatedUser.id === "string" ? authenticatedUser.id : "";
  if (!userId) {
    return jsonResponse(401, { error: "invalid_user_identity" });
  }

  // 256 bits of cryptographic randomness; only the digest is stored in Postgres.
  const randomBytes = crypto.getRandomValues(new Uint8Array(32));
  const ticket = bytesToHex(randomBytes);
  const tokenHash = await sha256Hex(ticket);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + GAME_TICKET_TTL_SECONDS * 1000);

  const insertResponse = await fetch(`${SUPABASE_URL}/rest/v1/game_login_tickets`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify({
      token_hash: tokenHash,
      user_id: userId,
      expires_at: expiresAt.toISOString(),
    }),
  });

  if (!insertResponse.ok) {
    return jsonResponse(503, { error: "ticket_issue_failed" });
  }

  // Best-effort cleanup keeps expired one-time tickets from accumulating.
  const cleanupUrl = `${SUPABASE_URL}/rest/v1/game_login_tickets?expires_at=lt.${encodeURIComponent(now.toISOString())}`;
  await fetch(cleanupUrl, {
    method: "DELETE",
    headers: serviceHeaders(),
  });

  return jsonResponse(200, {
    ticket,
    expires_at: expiresAt.toISOString(),
  });
});
