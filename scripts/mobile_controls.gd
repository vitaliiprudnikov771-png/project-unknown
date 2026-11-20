extends Control
class_name MobileControls

const BUTTON_SIZE := Vector2(66, 66)
const BUTTON_COLOR := Color(0.10, 0.16, 0.24, 0.88)
const BUTTON_HOVER := Color(0.18, 0.30, 0.43, 0.96)

var held_actions: Array[String] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_register_actions()
	_add_direction_button("▲", "move_forward", Vector2(92, -218))
	_add_direction_button("▼", "move_back", Vector2(92, -76))
	_add_direction_button("◀", "move_left", Vector2(20, -147))
	_add_direction_button("▶", "move_right", Vector2(164, -147))
	_add_direction_button("ПРЫЖОК", "jump", Vector2(-154, -104), true)

func _register_actions() -> void:
	var keys := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keys[action]
		InputMap.action_add_event(action, key_event)

func _add_direction_button(caption: String, action: String, offset: Vector2, right_side := false) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = BUTTON_SIZE if not right_side else Vector2(118, 82)
	button.size = button.custom_minimum_size
	button.add_theme_font_size_override("font_size", 17 if not right_side else 15)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(BUTTON_COLOR))
	button.add_theme_stylebox_override("hover", _button_style(BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#2563eb")))
	if right_side:
		button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		button.position = offset
	else:
		button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		button.position = offset
	button.button_down.connect(func():
			Input.action_press(action)
			if not held_actions.has(action):
				held_actions.append(action)
		)
	button.button_up.connect(func():
			Input.action_release(action)
			held_actions.erase(action)
		)
	add_child(button)

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.25)
	return style

func _exit_tree() -> void:
	for action in held_actions:
		Input.action_release(action)
	held_actions.clear()
