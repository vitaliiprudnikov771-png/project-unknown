extends Node

signal auth_finished(success: bool, message: String, access_token: String, email: String, user_id: String)
signal profile_finished(success: bool, profile: Dictionary, message: String)

var project_url := ""
var public_key := ""
var auth_http: HTTPRequest
var profile_http: HTTPRequest
var request_in_flight := false

func _ready() -> void:
	auth_http = HTTPRequest.new()
	auth_http.timeout = 20.0
	add_child(auth_http)
	auth_http.request_completed.connect(_on_auth_request_completed)

	profile_http = HTTPRequest.new()
	profile_http.timeout = 20.0
	add_child(profile_http)
	profile_http.request_completed.connect(_on_profile_request_completed)

func configure(url: String, key: String) -> void:
	project_url = url.trim_suffix("/")
	public_key = key

func sign_up(email: String, password: String) -> void:
	_send_auth("/auth/v1/signup", {"email": email, "password": password})

func sign_in(email: String, password: String) -> void:
	_send_auth("/auth/v1/token?grant_type=password", {"email": email, "password": password})

func fetch_profile(access_token: String, user_id: String) -> void:
	if project_url.is_empty() or public_key.is_empty() or access_token.is_empty() or user_id.is_empty():
		profile_finished.emit(false, {}, "Не удалось подготовить запрос профиля.")
		return
	var headers := PackedStringArray([
		"apikey: " + public_key,
		"Authorization: Bearer " + access_token,
		"Accept: application/json"
	])
	var query := "/rest/v1/player_profiles?select=id,username,display_name,avatar,level,xp,coins&id=eq." + user_id
	var err := profile_http.request(project_url + query, headers, HTTPClient.METHOD_GET)
	if err != OK:
		profile_finished.emit(false, {}, "Не удалось загрузить профиль: " + error_string(err))

func _send_auth(path: String, payload: Dictionary) -> void:
	if request_in_flight:
		auth_finished.emit(false, "Предыдущий запрос ещё выполняется.", "", "", "")
		return
	if project_url.is_empty() or public_key.is_empty():
		auth_finished.emit(false, "Backend не настроен.", "", "", "")
		return
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + public_key])
	request_in_flight = true
	var err := auth_http.request(project_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		request_in_flight = false
		auth_finished.emit(false, "Не удалось отправить запрос: " + error_string(err), "", "", "")

func _on_auth_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS:
		auth_finished.emit(false, "Сетевая ошибка. Проверь интернет.", "", "", "")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		auth_finished.emit(false, "Некорректный ответ сервера.", "", "", "")
		return
	var data: Dictionary = parsed
	if response_code < 200 or response_code >= 300:
		var msg := str(data.get("msg", data.get("message", data.get("error_description", data.get("error", "")))))
		auth_finished.emit(false, _friendly_error(response_code, msg), "", "", "")
		return
	var token := str(data.get("access_token", ""))
	var user: Dictionary = data.get("user", {})
	var email := str(user.get("email", ""))
	var user_id := str(user.get("id", ""))
	if token.is_empty() or user_id.is_empty():
		auth_finished.emit(false, "Аккаунт создан. Подтверди почту, затем выполни вход.", "", email, "")
		return
	auth_finished.emit(true, "Авторизация успешна.", token, email, user_id)

func _on_profile_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		profile_finished.emit(false, {}, "Сетевая ошибка при загрузке профиля.")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code < 200 or response_code >= 300:
		var message := "Не удалось загрузить профиль (HTTP %d)." % response_code
		if typeof(parsed) == TYPE_DICTIONARY:
			message = str(parsed.get("message", parsed.get("details", message)))
		profile_finished.emit(false, {}, message)
		return
	if typeof(parsed) != TYPE_ARRAY or parsed.is_empty() or typeof(parsed[0]) != TYPE_DICTIONARY:
		profile_finished.emit(false, {}, "Профиль пока не найден. Обратись к поддержке.")
		return
	profile_finished.emit(true, parsed[0], "Профиль загружен.")

func _friendly_error(code: int, message: String) -> String:
	var lower := message.to_lower()
	if "invalid login credentials" in lower:
		return "Неверная почта или пароль."
	if code == 429:
		return "Слишком много попыток. Повтори позже."
	if code == 422 or "already registered" in lower:
		return "Адрес уже зарегистрирован или данные не прошли проверку."
	if "email not confirmed" in lower:
		return "Сначала подтверди адрес электронной почты."
	return "Ошибка сервера (%d). Проверь настройки и повтори позже."
