class_name DataPacket
extends Node2D
## Paquete de datos coleccionable. Reaparece para que la sesión nunca muera.

signal collected_at(pos: Vector2)

const RESPAWN_TIME := 9.0

var active := true
var respawn_timer := 0.0
var base_y := 0.0
var phase := 0.0
var sprite: Sprite2D
var glow: Sprite2D
var _time := 0.0


func _ready() -> void:
	add_to_group("packets")
	z_index = 4
	base_y = position.y
	phase = randf() * TAU
	var glow_tex: Texture2D = load("res://assets/sprites/glow.png")
	glow = Sprite2D.new()
	glow.texture = glow_tex
	glow.scale = Vector2(0.38, 0.38)
	glow.modulate = Color(0.35, 0.95, 0.9, 0.32)
	glow.z_index = -1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)

	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/packet.png")
	sprite.hframes = 4
	sprite.vframes = 1
	sprite.scale = Vector2(2, 2)
	add_child(sprite)


func _process(delta: float) -> void:
	_time += delta
	if not active:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return
	position.y = base_y + sin(_time * 2.4 + phase) * 2.5
	sprite.frame = int(_time * 8.0 + phase) % 4
	glow.modulate.a = 0.25 + 0.12 * sin(_time * 3.0 + phase)
	glow.scale = Vector2(0.34, 0.34) + Vector2.ONE * (0.03 * sin(_time * 3.0 + phase))


func is_available() -> bool:
	return active


func collect() -> void:
	if not active:
		return
	active = false
	visible = false
	respawn_timer = RESPAWN_TIME
	collected_at.emit(global_position)


func _respawn() -> void:
	active = true
	visible = true
	scale = Vector2(0.2, 0.2)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	collected_at.emit(global_position + Vector2(0, -12))
