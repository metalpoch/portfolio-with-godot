class_name Crate
extends Node2D
## Caja de carga frágil. Poch la rompe al pasar; reaparece tras un rato.

signal smashed_at(pos: Vector2)

const RESPAWN_TIME := 24.0

var broken := false
var respawn_timer := 0.0
var sprite: Sprite2D
var glow: Sprite2D
var _time := 0.0


func _ready() -> void:
	add_to_group("crates")
	z_index = 4
	var glow_tex: Texture2D = load("res://assets/sprites/glow.png")
	glow = Sprite2D.new()
	glow.texture = glow_tex
	glow.position = Vector2(0, -14)
	glow.scale = Vector2(0.45, 0.3)
	glow.modulate = Color(0.3, 0.9, 0.55, 0.1)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)

	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/crate.png")
	sprite.scale = Vector2(1.5, 1.5)
	sprite.position = Vector2(0, -14)
	add_child(sprite)


func _process(delta: float) -> void:
	_time += delta
	if broken:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			broken = false
			visible = true
			scale = Vector2(0.3, 1.8)
			var tween := create_tween()
			tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	sprite.position.y = -14.0 + sin(_time * 2.2) * 0.35
	glow.modulate.a = 0.08 + 0.04 * sin(_time * 3.0)


func smash() -> void:
	if broken:
		return
	broken = true
	respawn_timer = RESPAWN_TIME
	visible = false
	smashed_at.emit(global_position)
