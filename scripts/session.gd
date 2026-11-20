extends Node

# Runtime-only account context shared across scenes. Access tokens are never written to disk.
var access_token: String = ""
var current_user_id: String = ""
var current_email: String = ""
var current_profile: Dictionary = {}
var is_authenticated: bool = false

func set_authenticated_user(token: String, user_id: String, email: String, profile: Dictionary) -> bool:
	if token.is_empty() or user_id.is_empty():
		clear_session()
		return false
	access_token = token
	current_user_id = user_id
	current_email = email
	current_profile = profile.duplicate(true)
	is_authenticated = true
	return true

func update_profile(profile: Dictionary) -> void:
	if is_authenticated:
		current_profile = profile.duplicate(true)

func clear_session() -> void:
	access_token = ""
	current_user_id = ""
	current_email = ""
	current_profile.clear()
	is_authenticated = false
