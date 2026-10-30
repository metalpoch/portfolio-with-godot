class_name Poch
extends CharacterBody2D
## Poch: personaje autónomo. El jugador solo mueve el cursor; Poch planifica
## sobre el grafo de plataformas, salta, se deja caer, rompe cajas y esquiva bugs.

signal jumped(pos: Vector2)
signal landed(pos: Vector2, strength: float)
signal stepped(pos: Vector2)
signal stunned(pos: Vector2)
signal crate_broken(pos: Vector2)
signal collected(pos: Vector2)
signal impulse_used(pos: Vector2)
signal fell(pos: Vector2)

const GRAVITY := Level.GRAVITY
const JUMP_VELOCITY := Level.JUMP_VELOCITY
const RUN_SPEED := Level.RUN_SPEED
const START_POS := Vector2(333, 330)

var level: Level
var spark: CursorSpark
var active := false

var airborne := false
var current_platform := -1
var goal_platform := -1
var path: Array = []
var target_x := 0.0
var plan_timer := 0.0
var facing := 1
var stun_timer := 0.0
var invuln_timer := 0.0
var impulse_timer := 0.0
var impulse_cooldown := 0.0
var dodge_cooldown := 0.0
var drop_timer := 0.0
var footstep_timer := 0.0
var anim_time := 0.0
var squash := 0.0
var respawn_point := START_POS
var _last_air_vy := 0.0
var _blink_timer := 3.0
var _blink := 0.0
var _wants_impulse := false

var sprite: Sprite2D
var shadow: Sprite2D
var _glow_tex: Texture2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = Level.LAYER_SOLID | Level.LAYER_ONEWAY
	floor_snap_length = 5.0
	floor_stop_on_slope = true
	safe_margin = 0.08
	z_index = 5

	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 5.0
	capsule.height = 26.0
	shape.shape = capsule
	shape.position = Vector2(0, -13)
	add_child(shape)

	_glow_tex = load("res://assets/sprites/glow.png")
	shadow = Sprite2D.new()
	shadow.texture = _glow_tex
	shadow.position = Vector2(0, -1)
	shadow.scale = Vector2(0.4, 0.12)
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.42)
	shadow.z_index = -2
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/poch.png")
	sprite.hframes = 5
	sprite.vframes = 1
	sprite.frame = 0
	sprite.position = Vector2(0, -16)
	sprite.scale = Vector2(2, 2)
	sprite.z_index = 1
	add_child(sprite)

	add_to_group("player")
	position = START_POS
	velocity = Vector2.ZERO


func start() -> void:
	active = true
	airborne = false
	current_platform = level.platform_at(global_position)
	respawn_point = global_position
	_plan()


func _physics_process(delta: float) -> void:
	anim_time += delta
	_tick_timers(delta)
	if not active:
		_update_visual(delta)
		return

	if airborne:
		_last_air_vy = velocity.y
		velocity.y += GRAVITY * delta
		if is_on_wall():
			velocity.x = 0.0
		move_and_slide()
		if is_on_floor() and velocity.y >= 0.0:
			_land()
		elif global_position.y > 382.0:
			_respawn()
	elif stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		velocity.y = 0.0
		move_and_slide()
		if not is_on_floor():
			airborne = true
	else:
		if not is_on_floor():
			# se caminó fuera de un borde
			airborne = true
			velocity.y = 20.0
			path.clear()
		else:
			velocity.y = 0.0
			_grounded(delta)
			move_and_slide()
			if not is_on_floor() and not airborne:
				airborne = true
				path.clear()
	_update_visual(delta)


func _tick_timers(delta: float) -> void:
	stun_timer = maxf(0.0, stun_timer - delta)
	invuln_timer = maxf(0.0, invuln_timer - delta)
	impulse_timer = maxf(0.0, impulse_timer - delta)
	impulse_cooldown = maxf(0.0, impulse_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	drop_timer = maxf(0.0, drop_timer - delta)
	if drop_timer <= 0.0 and collision_mask != (Level.LAYER_SOLID | Level.LAYER_ONEWAY):
		collision_mask = Level.LAYER_SOLID | Level.LAYER_ONEWAY
	squash = move_toward(squash, 0.0, delta * 4.0)
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = 3.4 + randf() * 2.4
		_blink = 0.12
	_blink = maxf(0.0, _blink - delta)
	footstep_timer = maxf(0.0, footstep_timer - delta)


func _grounded(delta: float) -> void:
	current_platform = level.platform_at(global_position)
	if current_platform < 0:
		current_platform = level.nearest_platform(global_position)
		respawn_point = level.platform_point(current_platform, global_position)
		global_position = Vector2(global_position.x, level.platforms[current_platform].y())
	respawn_point = Vector2(
		clampf(global_position.x, level.platforms[current_platform].x1() + 10.0,
			level.platforms[current_platform].x2() - 10.0),
		level.platforms[current_platform].y()
	)

	plan_timer -= delta
	if plan_timer <= 0.0 or path.is_empty():
		_plan()
		plan_timer = 0.18

	_check_pickups()

	if _should_dodge():
		_dodge()
		return

	if path.size() > 1:
		var e: Level.Edge = level.get_edge(path[0], path[1])
		if e == null:
			_plan()
			return
		var speed := RUN_SPEED * (1.75 if impulse_timer > 0.0 else 1.0)
		_walk_toward(e.takeoff, delta, speed)
		if absf(e.takeoff - global_position.x) > 1.0:
			facing = 1 if e.takeoff > global_position.x else -1
		if absf(global_position.x - e.takeoff) <= 8.0 or _crossed_takeoff(e.takeoff):
			_execute_edge(e)
	else:
		var speed := RUN_SPEED * (1.75 if impulse_timer > 0.0 else 1.0)
		_walk_toward(target_x, delta, speed)
		if absf(target_x - global_position.x) > 3.0:
			facing = 1 if target_x > global_position.x else -1
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1300.0 * delta)


func _crossed_takeoff(takeoff: float) -> bool:
	var before := global_position.x - velocity.x * get_physics_process_delta_time()
	return (before - takeoff) * (global_position.x - takeoff) <= 0.0


func _walk_toward(x_target: float, delta: float, speed: float) -> void:
	var dx := x_target - global_position.x
	if absf(dx) <= 2.0:
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
		return
	var desired := signf(dx) * speed
	# limitar para no pasarse del objetivo
	var closing := absf(dx) / maxf(delta, 0.0001)
	desired *= minf(1.0, closing / maxf(absf(desired), 0.001))
	velocity.x = move_toward(velocity.x, desired, 1600.0 * delta)
	if absf(velocity.x) > 20.0 and footstep_timer <= 0.0:
		footstep_timer = 0.23
		stepped.emit(global_position + Vector2(-signf(velocity.x) * 5.0, -1.0))


func _plan() -> void:
	if level == null or spark == null:
		return
	if current_platform < 0:
		current_platform = level.platform_at(global_position)
	if current_platform < 0:
		return
	var res := level.plan(current_platform, spark.position)
	if res.is_empty():
		return
	goal_platform = int(res["goal"])
	path = res["path"]
	target_x = float(res["target_x"])
	if path.size() > 1:
		var e: Level.Edge = level.get_edge(path[0], path[1])
		if e == null:
			path = [current_platform]
			goal_platform = current_platform
			target_x = clampf(spark.position.x,
				level.platforms[current_platform].x1() + 8.0,
				level.platforms[current_platform].x2() - 8.0)


func _execute_edge(e: Level.Edge) -> void:
	path.clear()
	plan_timer = 0.1
	match e.kind:
		"up", "level":
			airborne = true
			velocity = Vector2(e.vx, e.vy)
			squash = -0.7
			emit_signal("jumped", global_position)
			_spawn_takeoff_dust()
		"fall":
			airborne = true
			velocity = Vector2(e.vx, -130.0)
			squash = -0.5
			emit_signal("jumped", global_position)
			_spawn_takeoff_dust()
		"drop":
			# atravesar plataformas de un solo sentido
			collision_mask = Level.LAYER_SOLID
			drop_timer = 0.5
			airborne = true
			velocity = Vector2(e.vx, 55.0)
			squash = 0.4
			emit_signal("jumped", global_position)


func _spawn_takeoff_dust() -> void:
	stepped.emit(global_position)


func _land() -> void:
	var impact := absf(_last_air_vy)
	airborne = false
	var was_drop := collision_mask != (Level.LAYER_SOLID | Level.LAYER_ONEWAY)
	collision_mask = Level.LAYER_SOLID | Level.LAYER_ONEWAY
	drop_timer = 0.0
	velocity.y = 0.0
	current_platform = level.platform_at(global_position)
	if current_platform < 0:
		current_platform = level.nearest_platform(global_position)
	goal_platform = -1
	path.clear()
	plan_timer = 0.0
	squash = clampf(impact / 620.0, 0.15, 0.9)
	if current_platform >= 0:
		respawn_point = Vector2(
			clampf(global_position.x, level.platforms[current_platform].x1() + 9.0,
				level.platforms[current_platform].x2() - 9.0),
			level.platforms[current_platform].y()
		)
	emit_signal("landed", global_position, impact)
	_check_pickups()
	_plan()


func _respawn() -> void:
	global_position = respawn_point
	velocity = Vector2.ZERO
	airborne = false
	collision_mask = Level.LAYER_SOLID | Level.LAYER_ONEWAY
	drop_timer = 0.0
	stun_timer = 0.5
	invuln_timer = 1.0
	current_platform = level.platform_at(global_position)
	if current_platform < 0:
		current_platform = level.nearest_platform(global_position)
		global_position = Vector2(level.platform_point(current_platform, global_position).x,
			level.platforms[current_platform].y())
	path.clear()
	plan_timer = 0.0
	squash = 0.8
	emit_signal("fell", global_position)


func try_impulse() -> bool:
	if not active or stun_timer > 0.0 or impulse_cooldown > 0.0:
		return false
	impulse_cooldown = 2.2
	impulse_timer = 1.1
	var dir := facing
	if spark != null and absf(spark.position.x - global_position.x) > 8.0:
		dir = 1 if spark.position.x > global_position.x else -1
	facing = dir
	if not airborne:
		airborne = true
		velocity = Vector2(dir * 175.0, -440.0)
		squash = -0.8
		emit_signal("jumped", global_position)
	else:
		velocity.y = minf(velocity.y, -330.0)
		velocity.x = clampf(velocity.x + dir * 80.0, -210.0, 210.0)
	emit_signal("impulse_used", global_position)
	return true


func _should_dodge() -> bool:
	if dodge_cooldown > 0.0:
		return false
	if absf(velocity.x) < 8.0:
		return false
	for bug in get_tree().get_nodes_in_group("bugs"):
		if bug is Bug and bug.platform_idx != current_platform:
			continue
		var dx: float = bug.global_position.x - global_position.x
		var dy: float = absf(bug.global_position.y - (global_position.y - 8.0))
		if dy > 20.0:
			continue
		if absf(dx) > 8.0 and absf(dx) < 55.0 and signf(dx) == signf(velocity.x):
			return true
	return false


func _dodge() -> void:
	dodge_cooldown = 1.15
	airborne = true
	velocity = Vector2(signf(velocity.x) * 112.0, -365.0)
	path.clear()
	plan_timer = 0.0
	squash = -0.6
	emit_signal("jumped", global_position)
	_spawn_takeoff_dust()


func _check_pickups() -> void:
	for packet in get_tree().get_nodes_in_group("packets"):
		if packet is DataPacket and packet.is_available():
			# medir desde el centro del cuerpo, no desde los pies
			if (global_position + Vector2(0, -14)).distance_to(packet.global_position) < 19.0:
				packet.collect()
				emit_signal("collected", packet.global_position)
	for crate in get_tree().get_nodes_in_group("crates"):
		if crate is Crate and not crate.broken:
			var dx: float = absf(crate.global_position.x - global_position.x)
			var dy: float = absf(crate.global_position.y - (global_position.y - 13.0))
			if dx < 16.0 and dy < 20.0:
				crate.smash()
				emit_signal("crate_broken", crate.global_position)
	_check_bugs()


func _check_bugs() -> void:
	if invuln_timer > 0.0 or stun_timer > 0.0:
		return
	for bug in get_tree().get_nodes_in_group("bugs"):
		if global_position.distance_to(bug.global_position + Vector2(0, -7)) < 15.0:
			_hit_by_bug(bug)
			return


func _hit_by_bug(bug: Node2D) -> void:
	stun_timer = 0.42
	invuln_timer = 1.9
	airborne = true
	path.clear()
	goal_platform = -1
	var away := -1.0 if bug.global_position.x > global_position.x else 1.0
	velocity = Vector2(away * 78.0, -160.0)
	squash = 0.5
	emit_signal("stunned", global_position)


func _update_visual(delta: float) -> void:
	if sprite == null:
		return
	var moving := absf(velocity.x) > 12.0 and not airborne
	var bob := 0.0
	if moving:
		bob = absf(sin(anim_time * 18.0)) * 1.6
	elif not airborne:
		bob = sin(anim_time * 3.0) * 0.6

	if airborne:
		sprite.frame = 4 if velocity.y < 0.0 else 3
	elif stun_timer > 0.0:
		sprite.frame = 1
	elif _blink > 0.0:
		sprite.frame = 3
	elif spark != null and global_position.distance_to(spark.position) < 56.0:
		sprite.frame = 4
	else:
		sprite.frame = 0
	sprite.flip_h = facing < 0
	sprite.position = Vector2(0, -16.0 - bob)

	var sx := 1.0
	var sy := 1.0
	if airborne:
		if velocity.y < -60.0:
			sx = 0.96
			sy = 1.06
		else:
			sx = 1.03
			sy = 0.98
	var s := squash
	if s >= 0.0:
		sx *= 1.0 + s * 0.16
		sy *= 1.0 - s * 0.18
	else:
		sx *= 1.0 + s * 0.10
		sy *= 1.0 - s * 0.12
	sprite.scale = Vector2(2.0 * sx, 2.0 * sy)

	if shadow:
		shadow.position = Vector2(0, -1)
		var height_off := 0.0
		if airborne:
			height_off = clampf(-velocity.y / 900.0, 0.0, 0.6)
		shadow.modulate = Color(0, 0, 0, 0.42 - height_off * 0.3)
		shadow.scale = Vector2(0.4 - height_off * 0.15, 0.12 - height_off * 0.03)

	if invuln_timer > 0.0:
		sprite.modulate = Color(1, 1, 1, 0.45 + 0.55 * absf(sin(anim_time * 24.0)))
	elif impulse_timer > 0.0:
		sprite.modulate = Color(0.8, 1.0, 0.9, 1.0)
	else:
		sprite.modulate = Color.WHITE
