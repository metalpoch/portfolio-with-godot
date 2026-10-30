class_name CursorSpark
extends Node2D
## Chispa que persigue al cursor. El cursor real se dibuja aquí mismo
## (pixel-art) porque el cursor del sistema se oculta dentro del juego.

var cursor_pos := Vector2(470, 232)
var target := cursor_pos
var active := false
var autopilot := false
var has_mouse := false
var sync_factor := 0.0

var glow: Sprite2D
var _trail: Array = []
var _time := 0.0
var _accent := Color(0.4, 0.88, 0.85)


func _ready() -> void:
	z_index = 8
	var glow_tex: Texture2D = load("res://assets/sprites/glow.png")
	glow = Sprite2D.new()
	glow.texture = glow_tex
	glow.position = Vector2.ZERO
	glow.scale = Vector2(0.68, 0.68)
	glow.modulate = Color(0.4, 0.95, 0.9, 0.4)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)
	visible = false


func _input(event: InputEvent) -> void:
	if not active or autopilot:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		cursor_pos = get_global_mouse_position()
		has_mouse = true
	elif event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		cursor_pos = get_viewport().get_canvas_transform().affine_inverse() * ev.position
		has_mouse = true
	elif event is InputEventScreenDrag:
		var ev := event as InputEventScreenDrag
		cursor_pos = get_viewport().get_canvas_transform().affine_inverse() * ev.position
		has_mouse = true


func set_active(value: bool) -> void:
	active = value
	visible = value
	if value:
		has_mouse = false
		_trail.clear()
		if autopilot:
			cursor_pos = target
			position = target


func set_cursor(world_pos: Vector2) -> void:
	cursor_pos = world_pos
	has_mouse = true


func _process(delta: float) -> void:
	_time += delta
	if not active:
		return
	if not autopilot and has_mouse:
		# el cursor real es 1:1; la chispa tiene una pequeña inercia
		target = cursor_pos
	target = Vector2(clampf(target.x, 10.0, 630.0), clampf(target.y, 10.0, 350.0))
	var rate := 16.0 if not autopilot else 9.0
	position = position.lerp(target, 1.0 - exp(-rate * delta))
	if autopilot and not has_mouse:
		cursor_pos = target

	_trail.push_front({"p": position, "t": _time})
	while _trail.size() > 20:
		_trail.pop_back()

	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var near := 0.0
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		near = clampf(1.0 - player.global_position.distance_to(position) / 90.0, 0.0, 1.0)
	sync_factor = near
	glow.modulate = Color(0.35 + 0.4 * near, 0.95, 0.8 - 0.3 * near, 0.28 + 0.18 * pulse + near * 0.2)
	glow.scale = Vector2(0.45 + pulse * 0.08 + near * 0.25, 0.45 + pulse * 0.08 + near * 0.25)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	# estela de la chispa
	for i in range(_trail.size()):
		var item: Dictionary = _trail[i]
		var age := float(i) / float(_trail.size())
		var p: Vector2 = to_local(item["p"])
		var alpha := (1.0 - age) * 0.35
		var size := 2.0 if i < 6 else 1.0
		draw_rect(Rect2(p.floor(), Vector2(size, size)), Color(_accent.r, _accent.g, _accent.b, alpha))

	# chispa central
	var pv := 0.5 + 0.5 * sin(_time * 7.0)
	draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 4)), Color(0.9, 1.0, 0.95, 0.95))
	draw_rect(Rect2(Vector2(-1, -5), Vector2(2, 1)), Color(0.55, 1.0, 0.9, 0.9))
	draw_rect(Rect2(Vector2(-1, 4), Vector2(2, 1)), Color(0.55, 1.0, 0.9, 0.9))
	draw_rect(Rect2(Vector2(-5, -1), Vector2(1, 2)), Color(0.55, 1.0, 0.9, 0.9))
	draw_rect(Rect2(Vector2(4, -1), Vector2(1, 2)), Color(0.55, 1.0, 0.9, 0.9))

	if not has_mouse and not autopilot:
		return
	# retícula del cursor, 1:1 con el mouse
	var c := to_local(cursor_pos)
	var col := Color(0.96, 0.92, 0.85, 0.8)
	var dim := Color(0.4, 0.88, 0.85, 0.45)
	var r := 12.0 + pv * 1.5
	for i in range(16):
		var a := TAU * float(i) / 16.0 + _time * 0.45
		var q := c + Vector2(cos(a), sin(a)) * r
		if i % 2 == 0:
			draw_rect(Rect2(q.floor(), Vector2(1, 1)), Color(dim.r, dim.g, dim.b, 0.65))
	# corchetes
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(sx * 17.0, sy * 17.0)
			var hx := corner.x if sx < 0.0 else corner.x - 5.0
			var vy := corner.y if sy < 0.0 else corner.y - 5.0
			draw_rect(Rect2(Vector2(hx, corner.y).floor(), Vector2(6, 1)), col)
			draw_rect(Rect2(Vector2(corner.x, vy).floor(), Vector2(1, 6)), col)
	# cruz
	draw_rect(Rect2(c.floor() + Vector2(-1, -1), Vector2(3, 3)), col)
	draw_rect(Rect2(c.floor() + Vector2(-5, 0), Vector2(3, 1)), Color(col.r, col.g, col.b, 0.65))
	draw_rect(Rect2(c.floor() + Vector2(3, 0), Vector2(3, 1)), Color(col.r, col.g, col.b, 0.65))
	draw_rect(Rect2(c.floor() + Vector2(0, -5), Vector2(1, 3)), Color(col.r, col.g, col.b, 0.65))
	draw_rect(Rect2(c.floor() + Vector2(0, 3), Vector2(1, 3)), Color(col.r, col.g, col.b, 0.65))
	if sync_factor > 0.05:
		var rr := 18.0 + (1.0 - sync_factor) * 8.0
		for i in range(12):
			var a := TAU * float(i) / 12.0 - _time * 0.6
			var q := c + Vector2(cos(a), sin(a)) * rr
			draw_rect(Rect2(q.floor(), Vector2(1, 1)), Color(0.4, 1.0, 0.6, 0.15 + sync_factor * 0.3))
