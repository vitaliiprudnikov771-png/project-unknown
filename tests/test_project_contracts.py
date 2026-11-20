from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class ProjectContracts(unittest.TestCase):
    def test_project_targets_godot_43_gl_compatibility(self):
        project = source("project.godot")
        self.assertIn('"4.3"', project)
        self.assertIn('"GL Compatibility"', project)
        self.assertIn('run/main_scene="res://auth.tscn"', project)

    def test_autoloads_are_registered(self):
        project = source("project.godot")
        self.assertIn('Session="*res://scripts/session.gd"', project)
        self.assertIn('Network="*res://scripts/network_client.gd"', project)

    def test_session_is_memory_only_and_logout_clears_it(self):
        session = source("scripts/session.gd")
        self.assertIn("func set_authenticated_user", session)
        self.assertIn("func clear_session", session)
        self.assertNotIn("FileAccess.open", session)
        self.assertNotIn("ConfigFile.new", session)
        auth = source("scripts/auth_screen.gd")
        self.assertIn("Network.disconnect_from_server()", auth)
        self.assertIn("Session.clear_session()", auth)

    def test_auth_restores_session_and_opens_lobby(self):
        auth = source("scripts/auth_screen.gd")
        self.assertIn("if Session.is_authenticated:", auth)
        self.assertIn("Session.current_profile.duplicate(true)", auth)
        self.assertIn('change_scene_to_file("res://lobby.tscn")', auth)

    def test_legacy_game_peer_iteration_uses_compatible_packed_arrays(self):
        game = read("scripts/game.gd")
        self.assertNotIn("[1] + multiplayer.get_peers()", game)
        self.assertEqual(game.count("var peer_ids := PackedInt32Array([1])"), 2)
        self.assertEqual(game.count("peer_ids.append_array(multiplayer.get_peers())"), 2)

    def test_android_export_preset_is_debug_arm64_with_internet(self):
        preset = source("export_presets.cfg")
        self.assertIn('name="Android"', preset)
        self.assertIn('package/unique_name="com.inksys.projectunknown"', preset)
        self.assertIn("architectures/arm64-v8a=true", preset)
        self.assertIn("permissions/internet=true", preset)
        self.assertIn('version/name="0.9.0-dev"', preset)

    def test_android_workflow_builds_with_godot_43_and_no_secrets(self):
        workflow = source(".github/workflows/android-debug.yml")
        self.assertIn('GODOT_VERSION="4.3-stable"', workflow)
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("contents: read", workflow)
        self.assertIn("project-unknown-android-debug", workflow)
        self.assertNotIn("SUPABASE_SERVICE_ROLE_KEY", workflow)

    def test_client_requires_session_and_ticket_before_enet(self):
        network = source("scripts/network_client.gd")
        connect = network.split("func connect_to_server(", 1)[1].split("\nfunc ", 1)[0]
        self.assertIn("Session.is_authenticated", connect)
        self.assertIn("_request_game_ticket()", connect)
        self.assertIn("multiplayer.send_auth(peer_id, pending_game_ticket.to_utf8_buffer())", network)

    def test_server_fails_closed_and_checks_verified_identity(self):
        network = source("scripts/network_client.gd")
        self.assertIn('OS.get_environment("PROJECT_UNKNOWN_GAME_SERVER_SHARED_SECRET")', network)
        self.assertIn("game_server_shared_secret.length() < 32", network)
        connected = network.split("func _on_peer_connected(", 1)[1].split("\nfunc ", 1)[0]
        self.assertIn("verified_peer_identities.has(peer_id)", connected)

    def test_game_tickets_are_random_hashed_and_short_lived(self):
        issue = source("backend/supabase/functions/issue-game-ticket/index.ts")
        self.assertIn("crypto.getRandomValues", issue)
        self.assertIn("crypto.subtle.digest", issue)
        self.assertIn("GAME_TICKET_TTL_SECONDS = 60", issue)

    def test_ticket_redemption_requires_server_secret_and_single_use(self):
        redeem = source("backend/supabase/functions/redeem-game-ticket/index.ts")
        self.assertIn('req.headers.get("x-game-server-secret")', redeem)
        self.assertIn("constantTimeEquals", redeem)
        self.assertIn("consumed_at=is.null", redeem)
        self.assertIn('method: "PATCH"', redeem)

    def test_ticket_table_denies_client_roles(self):
        migration = source("backend/supabase/migrations/20261120170000_game_login_tickets.sql").upper()
        self.assertIn("ENABLE ROW LEVEL SECURITY", migration)
        self.assertIn("REVOKE ALL", migration)
        self.assertIn("FROM PUBLIC, ANON, AUTHENTICATED", migration)
        self.assertIn("TO SERVICE_ROLE", migration)

    def test_movement_input_is_bounded_rate_limited_and_expires(self):
        network = source("scripts/network_client.gd")
        self.assertIn("is_finite(direction.x)", network)
        self.assertIn("is_finite(direction.y)", network)
        self.assertIn("direction.limit_length(1.0)", network)
        self.assertIn("now_msec - last_input_msec < 15", network)
        self.assertIn("INPUT_TIMEOUT_MSEC := 250", network)


if __name__ == "__main__":
    unittest.main()
