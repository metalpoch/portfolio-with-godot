class_name FX
extends Node2D
## Partículas pixel, luciérnagas, línea de señal y pequeños efectos de impacto.

var particles: Array = []
var fireflies: Array = []
var motes: Array = []
var time := 0.0
var link_a := Vector2.ZERO
var link_b := Vector2.ZERO
var link_amount := 0.0
var link_enabled := false
var shooting: Array = []
var shoot_timer := 6.0

const CREAM := Color(0.96, 0.91, 0.84)
const MINT := Color(0.35, 0.89, 0.48)
const CYAN := Color(0.4, 0.88, 0.82)
const AMBER := Color(0.91, 0.71, 0.35)
const MAGENTA := Color(0.9, 0.35, 0.55)
const WOOD := Color(0.42, 0.36, 0.22)
const GREEN := Color(0.16, 0.5, 0.25)


func _ready() -> void:
	z_index = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(14):
		fireflies.append({
			"p": Vector2(rng.randf_range(16, 624), rng.randf_range(40, 320)),
			"v": Vector2(rng.randf_range(-3, 3), rng.randf_range(-2, 2)),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.4, 1.1),
			"amp": rng.randf_range(3, 9),
			"base": Vector2.ZERO,
		})
		fireflies[i]["base"] = fireflies[i]["p"]
	for i in range(26):
		motes.append({
			"p": Vector2(rng.randf_range(0, 640), rng.randf_range(0, 360)),
			"v": Vector2(rng.randf_range(-2, 2), rng.randf_range(-5, -1.5)),
			"a": rng.randf_range(0.04, 0.14),
			"size": 1.0 if rng.randf() < 0.7 else 2.0,
		})


func set_link(a: Vector2, b: Vector2, amount: float, enabled: bool) -> void:
	link_a = a
	link_b = b
	link_amount = amount
	link_enabled = enabled


func _process(delta: float) -> void:
	time += delta
	for p in particles:
		p["life"] -= delta
		p["v"] += Vector2(0, p["gravity"] * delta)
		p["v"] *= 1.0 - p["drag"] * delta
		p["p"] += p["v"] * delta
		if p.has("ring"):
			p["radius"] += p["ring_speed"] * delta
	for i in range(particles.size() - 1, -1, -1):
		if particles[i]["life"] <= 0.0:
			particles.remove_at(i)

	for f in fireflies:
		f["phase"] += delta * f["speed"]
		f["p"] += f["v"] * delta
		if f["p"].x < 8.0 or f["p"].x > 632.0:
			f["v"].x *= -1.0
		if f["p"].y < 30.0 or f["p"].y > 330.0:
			f["v"].y *= -1.0
	for m in motes:
		m["p"] += m["v"] * delta
		if m["p"].y < -4.0:
			m["p"].y = 364.0
			m["p"].x = randf() * 640.0
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = randf_range(8.0, 16.0)
		shooting.append({
			"p": Vector2(randf_range(80, 560), randf_range(20, 100)),
			"v": Vector2(randf_range(140, 240), randf_range(45, 90)),
			"life": 0.7,
		})
	for i in range(shooting.size() - 1, -1, -1):
		var s: Dictionary = shooting[i]
		s["life"] -= delta
		s["p"] += s["v"] * delta
		if s["life"] <= 0.0:
			shooting.remove_at(i)
	queue_redraw()


func _draw() -> void:
	# motas de polvo ambientales
	for m in motes:
		var p: Vector2 = m["p"]
		draw_rect(Rect2(p.floor(), Vector2(m["size"], m["size"])), Color(CREAM.r, CREAM.g, CREAM.b, m["a"]))

	# luciérnagas verdes
	for f in fireflies:
		var p: Vector2 = f["p"] + Vector2(0, sin(f["phase"]) * f["amp"] * 0.25)
		var a := 0.4 + 0.35 * (0.5 + 0.5 * sin(f["phase"] * 2.0))
		draw_rect(Rect2(p.floor(), Vector2(1, 1)), Color(MINT.r, MINT.g, MINT.b, a))
		draw_rect(Rect2(p.floor() - Vector2(1, 0), Vector2(1, 1)), Color(MINT.r, MINT.g, MINT.b, a * 0.25))
		draw_rect(Rect2(p.floor() + Vector2(1, 0), Vector2(1, 1)), Color(MINT.r, MINT.g, MINT.b, a * 0.25))

	for s in shooting:
		var p: Vector2 = s["p"]
		var v: Vector2 = s["v"]
		var alpha: float = clampf(float(s["life"]) / 0.7, 0.0, 1.0) * 0.5
		draw_line(p, p - v * 0.07, Color(CREAM.r, CREAM.g, CREAM.b, alpha), 1.0)

	# línea de señal
	if link_enabled and link_amount > 0.02:
		var a2 := link_a
		var b2 := link_b
		var dist := a2.distance_to(b2)
		if dist > 16.0:
			var dir := (b2 - a2).normalized()
			var count := int(dist / 7.0)
			for i in range(count):
				var t := (float(i) + fmod(time * 10.0, 7.0)) / float(count)
				if t > 1.0:
					continue
				var p := a2 + dir * (t * dist)
				var flow := 0.5 + 0.5 * sin(t * TAU * 2.0 - time * 3.0)
				var alpha: float = link_amount * (0.08 + 0.16 * flow)
				draw_rect(Rect2(p.floor(), Vector2(1, 1)).grow(1.0 if flow > 0.7 else 0.0),
					Color(CYAN.r, CYAN.g, CYAN.b, alpha))

	# partículas
	for p in particles:
		var life: float = p["life"]
		var max_life: float = p["max_life"]
		var k: float = clampf(life / max_life, 0.0, 1.0)
		var col: Color = p["color"]
		var pos: Vector2 = p["p"]
		var size: float = p["size"]
		if p.has("ring"):
			var radius: float = p["radius"]
			var rc := Color(col.r, col.g, col.b, col.a * k)
			draw_circle(pos, radius, rc, false, 1.0, false)
			if radius > 10.0:
				draw_circle(pos, radius - 3.0, Color(col.r, col.g, col.b, rc.a * 0.3), false, 1.0, false)
			continue
		var alpha: float = col.a * k
		if k < 0.2 and int(time * 20.0) % 2 == 0:
			alpha *= 0.35
		if size <= 1.2:
			draw_rect(Rect2(pos.floor(), Vector2(1, 1)), Color(col.r, col.g, col.b, alpha))
		else:
			draw_rect(Rect2(pos.floor() - Vector2(size * 0.5, size * 0.5), Vector2(size, size)),
				Color(col.r, col.g, col.b, alpha))


func _add(p: Dictionary) -> void:
	if particles.size() > 300:
		particles.pop_front()
	particles.append(p)


func _spark(pos: Vector2, color: Color, count: int, speed_min: float, speed_max: float,
		life_min: float, life_max: float, size_min: float, size_max: float,
		gravity := 220.0, drag := 1.5) -> void:
	for i in range(count):
		var ang := randf() * TAU
		var sp := randf_range(speed_min, speed_max)
		var life := randf_range(life_min, life_max)
		_add({
			"p": pos + Vector2(randf_range(-2, 2), randf_range(-2, 2)),
			"v": Vector2(cos(ang), sin(ang)) * sp + Vector2(0, -10.0),
			"life": life, "max_life": life,
			"color": Color(color.r, color.g, color.b, 0.95),
			"size": randf_range(size_min, size_max),
			"gravity": gravity, "drag": drag,
		})


func spawn_step(pos: Vector2, dir: float) -> void:
	for i in range(2):
		var life := randf_range(0.22, 0.42)
		_add({
			"p": pos + Vector2(randf_range(-3, 3), randf_range(-2, 0)),
			"v": Vector2(-dir * randf_range(4, 18), randf_range(-18, -4)),
			"life": life, "max_life": life,
			"color": Color(CREAM.r, CREAM.g, CREAM.b, 0.28),
			"size": randf_range(1.0, 2.0),
			"gravity": -10.0, "drag": 3.0,
		})


func spawn_land(pos: Vector2, strength: float) -> void:
	var count := int(clampf(4.0 + strength * 0.02, 4.0, 14.0))
	for i in range(count):
		var life := randf_range(0.25, 0.55)
		var dir := -1.0 if i % 2 == 0 else 1.0
		_add({
			"p": pos + Vector2(randf_range(-4, 4), -1.0),
			"v": Vector2(dir * randf_range(18, 55), randf_range(-35, -8)),
			"life": life, "max_life": life,
			"color": Color(CREAM.r, CREAM.g, CREAM.b, 0.35),
			"size": randf_range(1.0, 2.5),
			"gravity": 160.0, "drag": 2.5,
		})
	_add({
		"p": pos + Vector2(0, 1), "v": Vector2.ZERO,
		"life": 0.22, "max_life": 0.22,
		"color": Color(CYAN.r, CYAN.g, CYAN.b, 0.4),
		"size": 1.0, "gravity": 0.0, "drag": 0.0,
		"ring": true, "radius": 2.0, "ring_speed": 55.0,
	})


func spawn_break(pos: Vector2) -> void:
	_spark(pos, WOOD, 10, 25, 90, 0.35, 0.8, 2.0, 3.5, 480.0, 0.8)
	_spark(pos, GREEN, 5, 15, 55, 0.3, 0.6, 1.0, 2.0, 380.0, 1.0)
	_spark(pos, MINT, 5, 20, 70, 0.15, 0.35, 1.0, 1.5, 60.0, 2.0)


func spawn_collect(pos: Vector2) -> void:
	_spark(pos, CYAN, 10, 20, 65, 0.2, 0.5, 1.0, 2.0, -20.0, 2.0)
	_add({
		"p": pos, "v": Vector2.ZERO,
		"life": 0.36, "max_life": 0.36,
		"color": Color(CYAN.r, CYAN.g, CYAN.b, 0.7),
		"size": 1.0, "gravity": 0.0, "drag": 0.0,
		"ring": true, "radius": 3.0, "ring_speed": 70.0,
	})


func spawn_sync(pos: Vector2) -> void:
	_spark(pos, MINT, 22, 30, 110, 0.35, 0.9, 1.0, 2.5, 40.0, 1.2)
	_spark(pos, CREAM, 10, 20, 70, 0.3, 0.7, 1.0, 2.0, 20.0, 1.5)
	for r in [22.0, 38.0]:
		_add({
			"p": pos, "v": Vector2.ZERO,
			"life": 0.5, "max_life": 0.5,
			"color": Color(MINT.r, MINT.g, MINT.b, 0.65),
			"size": 1.0, "gravity": 0.0, "drag": 0.0,
			"ring": true, "radius": r, "ring_speed": 90.0,
		})


func spawn_stun(pos: Vector2) -> void:
	_spark(pos, MAGENTA, 12, 30, 100, 0.3, 0.7, 1.0, 2.5, 150.0, 1.5)
	_spark(pos, CYAN, 5, 10, 45, 0.2, 0.45, 1.0, 1.5, 0.0, 2.0)


func spawn_impulse(pos: Vector2) -> void:
	for i in range(10):
		var life := randf_range(0.2, 0.45)
		var dir := -1.0 if i % 2 == 0 else 1.0
		_add({
			"p": pos + Vector2(randf_range(-4, 4), randf_range(-22, -2)),
			"v": Vector2(dir * randf_range(10, 45), randf_range(-15, 15)),
			"life": life, "max_life": life,
			"color": Color(MINT.r, MINT.g, MINT.b, 0.7),
			"size": randf_range(1.0, 2.0),
			"gravity": 0.0, "drag": 2.0,
		})


func spawn_respawn(pos: Vector2) -> void:
	_spark(pos, CYAN, 16, 20, 70, 0.3, 0.7, 1.0, 2.0, 40.0, 1.5)
	_add({
		"p": pos, "v": Vector2.ZERO,
		"life": 0.5, "max_life": 0.5,
		"color": Color(CYAN.r, CYAN.g, CYAN.b, 0.5),
		"size": 1.0, "gravity": 0.0, "drag": 0.0,
		"ring": true, "radius": 4.0, "ring_speed": 80.0,
	})
