class_name Bug
extends Node2D
## Bicho glitch que patrulla una plataforma. Poch lo esquiva con un salto.

var platform_idx := -1
var min_x := 0.0
var max_x := 0.0
var speed := 24.0
var direction := 1.0
var sprite: Sprite2D
var glow: Sprite2D
var _time := 0.0


func setup(idx: int, y: float, x_min: float, x_max: float, start_x: float, dir: float) -> void:
	platform_idx = idx
	min_x = x_min
	max_x = x_max
	position = Vector2(start_x, y)
	direction = dir


func _ready() -> void:
	add_to_group("bugs")
	z_index = 4
	var glow_tex: Texture2D = load("res://assets/sprites/glow.png")
	glow = Sprite2D.new()
	glow.texture = glow_tex
	glow.scale = Vector2(0.38, 0.22)
	glow.position = Vector2(0, -8)
	glow.modulate = Color(0.95, 0.25, 0.5, 0.22)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(glow)

	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/bug.png")
	sprite.hframes = 2
	sprite.vframes = 1
	sprite.scale = Vector2(1.35, 1.35)
	sprite.position = Vector2(0, -10)
	add_child(sprite)
	_time = randf() * 3.0


func _process(delta: float) -> void:
	_time += delta
	position.x += direction * speed * delta
	if position.x >= max_x:
		position.x = max_x
		direction = -1.0
	elif position.x <= min_x:
		position.x = min_x
		direction = 1.0
	sprite.flip_h = direction < 0.0
	sprite.frame = int(_time * 7.0) % 2
	sprite.position.y = -10.0 + sin(_time * 9.0) * 1.4
	glow.modulate.a = 0.16 + 0.08 * sin(_time * 6.0)
