extends Node2D

var peer_id := 1
var is_local := false
const SPEED := 260.0
var tint := Color("65c8ff")

func _ready() -> void:
	tint = Color.from_hsv(fposmod(float(peer_id) * 0.173, 1.0), 0.62, 1.0)

func _process(delta: float) -> void:
	if is_local:
		var game := get_parent()
		var direction: Vector2 = game.get_local_input()
		position += direction * SPEED * delta
		position.x = clampf(position.x, -870.0, 870.0)
		position.y = clampf(position.y, -570.0, 570.0)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 3), 19, Color(0, 0, 0, 0.28))
	draw_circle(Vector2.ZERO, 16, tint)
	draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color.WHITE, 2.0)
	draw_circle(Vector2(5, -5), 4, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(-22, -27), "#%d" % peer_id, HORIZONTAL_ALIGNMENT_CENTER, 48, 13, Color.WHITE)
