extends Control

signal vector_changed(value: Vector2)

var active := false
var origin := Vector2(105, 420)
var radius := 68.0
var vector := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < size.x * 0.55 and event.position.y > size.y * 0.45:
			active = true
			vector = ((event.position - origin) / radius).limit_length(1.0)
			vector_changed.emit(vector)
		elif not event.pressed and active:
			active = false
			vector = Vector2.ZERO
			vector_changed.emit(vector)
		queue_redraw()
	elif event is InputEventScreenDrag and active:
		vector = ((event.position - origin) / radius).limit_length(1.0)
		vector_changed.emit(vector)
		queue_redraw()

func _draw() -> void:
	draw_circle(origin, radius, Color(0.08, 0.10, 0.15, 0.38))
	draw_arc(origin, radius, 0, TAU, 48, Color(0.65, 0.75, 0.9, 0.45), 2.0)
	draw_circle(origin + vector * 34.0, 25.0, Color(0.45, 0.72, 1.0, 0.65))
