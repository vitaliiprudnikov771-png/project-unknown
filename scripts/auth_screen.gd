extends Control

const AUTH_CLIENT := preload("res://scripts/supabase_auth.gd")
const SUPABASE_URL := "https://kqsropnoapnvxetvnqan.supabase.co"
# Publishable key is intentionally client-side. Never replace it with a secret/service_role key.
const SUPABASE_PUBLIC_KEY := "sb_publishable_lOJl2i7GRkIiLK9xyvvjOw_r6bvoRRp"

var auth = AUTH_CLIENT.new()
var email_input: LineEdit
var password_input: LineEdit
var status_label: Label
var login_button: Button
var signup_button: Button
var access_token := "" # Memory only. Never persisted.
var current_email := ""
var current_user_id := ""
var current_profile: Dictionary = {}

func _ready() -> void:
	if Network.is_dedicated_server:
		return
	add_child(auth)
	auth.auth_finished.connect(_on_auth_finished)
	auth.profile_finished.connect(_on_profile_finished)
	auth.configure(SUPABASE_URL, SUPABASE_PUBLIC_KEY)
	Network.configure_identity_backend(SUPABASE_URL, SUPABASE_PUBLIC_KEY)
	_build_ui()
	if Session.is_authenticated:
		access_token = Session.access_token
		current_user_id = Session.current_user_id
		current_email = Session.current_email
		current_profile = Session.current_profile.duplicate(true)
		_show_account_home()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#111827")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PROJECT UNKNOWN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "CLASSIC MULTIPLAYER • ACCOUNT ACCESS"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var backend := Label.new()
	backend.text = "BACKEND CONNECTED  •  EUROPE"
	backend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backend.add_theme_color_override("font_color", Color("#34d399"))
	box.add_child(backend)
	var sep := HSeparator.new()
	box.add_child(sep)
	var form_title := Label.new()
	form_title.text = "Вход или создание аккаунта"
	form_title.add_theme_font_size_override("font_size", 18)
	box.add_child(form_title)
	email_input = LineEdit.new()
	email_input.placeholder_text = "Электронная почта"
	email_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	box.add_child(email_input)
	password_input = LineEdit.new()
	password_input.placeholder_text = "Пароль (минимум 8 символов)"
	password_input.secret = true
	box.add_child(password_input)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	login_button = Button.new()
	login_button.text = "Войти"
	login_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login_button.pressed.connect(_login)
	buttons.add_child(login_button)
	signup_button = Button.new()
	signup_button.text = "Регистрация"
	signup_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	signup_button.pressed.connect(_signup)
	buttons.add_child(signup_button)
	status_label = Label.new()
	status_label.text = "Создай аккаунт PROJECT UNKNOWN или войди в существующий."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
	var note := Label.new()
	note.text = "Пароль не сохраняется на устройстве. Используй действующий адрес электронной почты."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	box.add_child(note)

func _validate_form() -> bool:
	var email := email_input.text.strip_edges()
	if not email.contains("@") or email.length() < 5:
		_set_status("Введи корректный адрес электронной почты.")
		return false
	if password_input.text.length() < 8:
		_set_status("Пароль должен содержать минимум 8 символов.")
		return false
	return true

func _login() -> void:
	if _validate_form():
		_set_busy(true)
		auth.sign_in(email_input.text.strip_edges(), password_input.text)

func _signup() -> void:
	if _validate_form():
		_set_busy(true)
		auth.sign_up(email_input.text.strip_edges(), password_input.text)

func _on_auth_finished(success: bool, message: String, token: String, user_email: String, user_id: String) -> void:
	_set_busy(false)
	_set_status(message)
	if success:
		access_token = token
		current_email = user_email
		current_user_id = user_id
		_set_status("Вход выполнен. Загружаю игровой профиль…")
		auth.fetch_profile(access_token, current_user_id)

func _on_profile_finished(success: bool, profile: Dictionary, message: String) -> void:
	if not success:
		_set_status(message)
		return
	current_profile = profile
	if not Session.set_authenticated_user(access_token, current_user_id, current_email, current_profile):
		_set_status("Не удалось сохранить сессию. Выполни вход повторно.")
		return
	_set_status(message)
	_show_account_home()

func _show_account_home() -> void:
	for child in get_children():
		if child is CenterContainer:
			child.hide()
	var old := get_node_or_null("AccountCenter")
	if old:
		old.queue_free()
	var center := CenterContainer.new()
	center.name = "AccountCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 190)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	var title := Label.new()
	title.text = "АККАУНТ PROJECT UNKNOWN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var username := Label.new()
	username.text = "@" + str(current_profile.get("username", "player"))
	username.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(username)
	var email := Label.new()
	email.text = current_email
	email.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(email)
	var stats := Label.new()
	stats.text = "Уровень %s   •   XP %s   •   Монеты %s" % [str(current_profile.get("level", 1)), str(current_profile.get("xp", 0)), str(current_profile.get("coins", 0))]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	var next := Label.new()
	next.text = "Игровой профиль синхронизирован с сервером."
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(next)
	var play := Button.new()
	play.text = "ВОЙТИ В ИГРУ"
	play.pressed.connect(func():
		get_tree().change_scene_to_file("res://lobby.tscn")
	)
	box.add_child(play)

	var logout := Button.new()
	logout.text = "Выйти"
	logout.pressed.connect(func():
		access_token = ""
		current_email = ""
		current_user_id = ""
		current_profile.clear()
		Network.disconnect_from_server()
		Session.clear_session()
		get_tree().reload_current_scene()
	)
	box.add_child(logout)

func _set_busy(value: bool) -> void:
	login_button.disabled = value
	signup_button.disabled = value

func _set_status(value: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = value
