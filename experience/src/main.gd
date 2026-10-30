extends Node2D
## POCHLAND · SIGUE LA LUZ
## Experiencia 2D embebible: Poch persigue al cursor resolviendo plataformas,
## cajas y bugs. Construida para Godot 4.7, export Web single-thread.

const VIEW := Vector2(640, 360)
const START_SPARK := Vector2(470, 232)
const MUSIC_PATH := "res://assets/audio/music_loop.ogg"
const SFX_PATHS := {
	"jump": "res://assets/audio/sfx_jump.ogg",
	"land": "res://assets/audio/sfx_land.ogg",
	"collect": "res://assets/audio/sfx_collect.ogg",
	"break": "res://assets/audio/sfx_break.ogg",
	"glitch": "res://assets/audio/sfx_glitch.ogg",
	"sync": "res://assets/audio/sfx_sync.ogg",
	"impulse": "res://assets/audio/sfx_impulse.ogg",
	"click": "res://assets/audio/sfx_click.ogg",
}
const PACKET_POSITIONS := [
	Vector2(112, 184),
	Vector2(476, 142),
	Vector2(390, 100),
	Vector2(60, 306),
	Vector2(465, 226),
	Vector2(260, 142),
]
const BUG_SETUP := [
	{"platform": 12, "x": 285.0, "dir": 1.0, "speed": 25.0}, # M2
	{"platform": 5, "x": 140.0, "dir": -1.0, "speed": 22.0}, # L3
	{"platform": 8, "x": 480.0, "dir": 1.0, "speed": 28.0}, # R2
	{"platform": 2, "x": 540.0, "dir": -1.0, "speed": 20.0}, # G2
]
const CRATE_POSITIONS := [
	{"platform": 1, "x": 405.0},
	{"platform": 3, "x": 350.0},
	{"platform": 8, "x": 488.0},
]
const SELFTEST_POINTS := [
	Vector2(470, 232),
	Vector2(112, 184),
	Vector2(390, 100),
	Vector2(565, 250),
	Vector2(60, 306),
	Vector2(560, 156),
	Vector2(330, 252),
	Vector2(300, 58),
]

var level: Level
var player: Poch
var spark: CursorSpark
var fx: FX
var hud: HUD
var bridge: WebBridge
var camera: Camera2D
var debug_draw: DebugDraw

var music: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}

var started := false
var paused := false
var muted := false

var sync := 0.0
var best_sync := 0.0
var packets := 0
var sync_cooldown := 0.0
var stats_timer := 0.0
var shake := 0.0
var flash := 0.0
var flash_color := Color(0.9, 0.3, 0.5)

var flash_rect: ColorRect
var _time := 0.0
var _ready_sent := false
var _start_delay := 0.0

# selftest
var selftest := false
var selftest_index := 0
var selftest_timer := 0.0
var selftest_log := 0.0
var visited: Dictionary = {}
var stun_count := 0
var fall_count := 0
var crate_count := 0
var selftest_finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	selftest = "--selftest" in OS.get_cmdline_user_args()
	_build_world()
	_build_audio()
	_build_ui()
	_build_bridge()
	_connect_game()
	if selftest:
		_begin_selftest()
	else:
		hud.show_start()


func _build_world() -> void:
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/sprites/bg.png")
	bg.position = VIEW * 0.5
	bg.z_index = -20
	bg.centered = true
	add_child(bg)

	camera = Camera2D.new()
	camera.position = VIEW * 0.5
	camera.enabled = true
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(camera)
	camera.make_current()

	level = Level.new()
	level.name = "Level"
	add_child(level)

	fx = FX.new()
	fx.name = "FX"
	add_child(fx)

	spark = CursorSpark.new()
	spark.position = START_SPARK
	spark.target = START_SPARK
	spark.cursor_pos = START_SPARK
	add_child(spark)

	for p in PACKET_POSITIONS:
		var packet := DataPacket.new()
		packet.position = p
		add_child(packet)

	for b in BUG_SETUP:
		var idx := int(b["platform"])
		var plat := level.platforms[idx]
		var bug := Bug.new()
		bug.setup(idx, plat.y(), plat.x1() + 18.0, plat.x2() - 18.0,
			float(b["x"]), float(b["dir"]))
		bug.speed = float(b["speed"])
		add_child(bug)

	for c in CRATE_POSITIONS:
		var idx := int(c["platform"])
		var plat := level.platforms[idx]
		var crate := Crate.new()
		crate.position = Vector2(float(c["x"]), plat.y())
		add_child(crate)

	player = Poch.new()
	player.name = "Poch"
	player.level = level
	player.spark = spark
	add_child(player)

	debug_draw = DebugDraw.new()
	debug_draw.level = level
	debug_draw.player = player
	add_child(debug_draw)


func _build_audio() -> void:
	music = AudioStreamPlayer.new()
	var stream = load(MUSIC_PATH)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	music.stream = stream
	music.volume_db = -17.0
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)

	for key in SFX_PATHS:
		sfx_streams[key] = load(str(SFX_PATHS[key]))
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.volume_db = -7.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_players.append(p)


func _build_ui() -> void:
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 5
	add_child(crt_layer)
	var crt := ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float scan = step(0.5, fract(SCREEN_UV.y * 180.0)) * 0.05;
	vec2 d = SCREEN_UV - 0.5;
	float edge = smoothstep(0.84, 0.24, length(d));
	float vignette = (1.0 - edge) * 0.42;
	float alpha = clamp(scan + vignette * 0.9, 0.0, 0.55);
	COLOR = vec4(0.0, 0.012, 0.02, alpha);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	crt.material = mat
	crt_layer.add_child(crt)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 6
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.3, 0.4, 0)
	flash_layer.add_child(flash_rect)

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)


func _build_bridge() -> void:
	bridge = WebBridge.new()
	bridge.name = "WebBridge"
	add_child(bridge)
	bridge.host_message.connect(_on_host_message)


func _connect_game() -> void:
	hud.start_requested.connect(_start_game)
	hud.resume_requested.connect(_resume)
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)
	player.stepped.connect(_on_stepped)
	player.stunned.connect(_on_stunned)
	player.crate_broken.connect(_on_crate_broken)
	player.collected.connect(_on_collected)
	player.impulse_used.connect(_on_impulse_used)
	player.fell.connect(_on_fell)


func _process(delta: float) -> void:
	_time += delta
	if not _ready_sent and _time > 0.45:
		_ready_sent = true
		if bridge:
			bridge.send_ready()

	if flash_rect:
		flash = maxf(0.0, flash - delta * 2.8)
		flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, flash * 0.18)

	if shake > 0.0 and camera:
		shake = maxf(0.0, shake - delta * 16.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	elif camera:
		camera.offset = Vector2.ZERO

	if not started:
		return
	if paused:
		return

	sync_cooldown = maxf(0.0, sync_cooldown - delta)
	var dist := player.global_position.distance_to(spark.position)
	var raw := clampf(100.0 - maxf(0.0, dist - 15.0) * 0.72, 0.0, 100.0)
	sync = lerpf(sync, raw, 1.0 - exp(-5.0 * delta))
	best_sync = maxf(best_sync, sync)
	hud.update_stats(sync, packets)
	fx.set_link(player.global_position + Vector2(0, -14), spark.position,
		clampf(1.0 - dist / 180.0, 0.0, 1.0), true)

	if dist < 25.0 and sync_cooldown <= 0.0 and not selftest:
		_sync_perfect()

	stats_timer -= delta
	if stats_timer <= 0.0:
		stats_timer = 0.4
		_broadcast_stats()

	if debug_draw:
		debug_draw.visible = debug_draw.visible

	if selftest:
		_tick_selftest(delta)


func _sync_perfect() -> void:
	sync_cooldown = 6.0
	best_sync = 100.0
	hud.flash_sync()
	hud.toast("SINCRONÍA PERFECTA", HUD.MINT)
	play_sfx("sync")
	fx.spawn_sync(player.global_position + Vector2(0, -14))
	shake = 2.0
	bridge.send_event("sync")


func _broadcast_stats() -> void:
	if bridge:
		bridge.send_stats(int(round(sync)), packets, int(round(best_sync)))


func _start_game() -> void:
	if started:
		return
	started = true
	paused = false
	get_tree().paused = false
	hud.hide_start()
	hud.hide_pause()
	player.start()
	var mp := get_global_mouse_position()
	if mp.x >= 0.0 and mp.x <= 640.0 and mp.y >= 0.0 and mp.y <= 360.0:
		spark.cursor_pos = mp
		spark.target = mp
		spark.position = mp
	spark.set_active(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_set_css_cursor(true)
	play_sfx("click")
	music.play()
	spark.has_mouse = true
	_broadcast_stats()


func _pause() -> void:
	if not started or paused or selftest:
		return
	paused = true
	get_tree().paused = true
	hud.show_pause()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_css_cursor(false)
	if music:
		music.stream_paused = true


func _resume() -> void:
	if not started:
		_start_game()
		return
	if not paused:
		return
	paused = false
	get_tree().paused = false
	hud.hide_pause()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_set_css_cursor(true)
	if music:
		music.stream_paused = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if started and not paused and not selftest:
			_pause()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_M:
			_toggle_mute()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_F3:
			if debug_draw:
				debug_draw.visible = not debug_draw.visible
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			if not started:
				_start_game()
				get_viewport().set_input_as_handled()
			elif paused:
				_resume()
				get_viewport().set_input_as_handled()
			else:
				_use_impulse()
				get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		if not started:
			_start_game()
			get_viewport().set_input_as_handled()
		elif paused:
			_resume()
			get_viewport().set_input_as_handled()
		else:
			_use_impulse()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		if not started:
			_start_game()
			get_viewport().set_input_as_handled()
		elif paused:
			_resume()
			get_viewport().set_input_as_handled()
		else:
			_use_impulse()


func _use_impulse() -> void:
	if player == null:
		return
	if player.try_impulse():
		pass # la señal impulse_used dispara el sonido
	else:
		play_sfx("click", 1.2, -12.0)


func _set_css_cursor(hidden: bool) -> void:
	if not OS.has_feature("web"):
		return
	var value := "none" if hidden else "default"
	JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas'); if(c){c.style.cursor='%s';}})();" % value, true)


func _toggle_mute() -> void:
	_set_muted(not muted)


func _set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(0, muted)
	hud.set_muted(muted)
	if not muted and started and not paused:
		music.stream_paused = false


func _on_host_message(data: Dictionary) -> void:
	var kind := str(data.get("type", ""))
	match kind:
		"pause":
			_pause()
		"resume":
			_resume()
		"mute":
			_set_muted(bool(data.get("muted", false)))


func play_sfx(key: String, pitch := 1.0, volume_db := -7.0) -> void:
	if not sfx_streams.has(key):
		return
	var chosen: AudioStreamPlayer = null
	for p in sfx_players:
		if not p.playing:
			chosen = p
			break
	if chosen == null:
		chosen = sfx_players[0]
	chosen.stream = sfx_streams[key]
	chosen.volume_db = volume_db
	chosen.pitch_scale = pitch
	chosen.play()


# ------------------------------------------------------------------ señales
func _on_jumped(pos: Vector2) -> void:
	play_sfx("jump", randf_range(0.94, 1.08), -8.0)
	if bridge:
		bridge.send_event("jump")


func _on_landed(pos: Vector2, strength: float) -> void:
	if strength > 70.0:
		play_sfx("land", randf_range(0.92, 1.05), clampf(-4.0 - strength * 0.008, -12.0, -5.0))
	fx.spawn_land(pos, strength)
	shake = maxf(shake, clampf(strength / 500.0, 0.2, 2.6))


func _on_stepped(pos: Vector2) -> void:
	fx.spawn_step(pos, player.facing)


func _on_stunned(pos: Vector2) -> void:
	stun_count += 1
	play_sfx("glitch", 1.0, -5.0)
	fx.spawn_stun(pos + Vector2(0, -14))
	flash_color = Color(0.95, 0.25, 0.5)
	flash = 1.0
	shake = 5.0
	hud.toast("SEÑAL INTERRUMPIDA", HUD.AMBER)
	sync = maxf(0.0, sync - 22.0)


func _on_crate_broken(pos: Vector2) -> void:
	crate_count += 1
	play_sfx("break", randf_range(0.9, 1.05), -5.0)
	fx.spawn_break(pos + Vector2(0, -14))
	shake = maxf(shake, 2.8)
	hud.toast("CAJA ABIERTA", HUD.AMBER)


func _on_collected(pos: Vector2) -> void:
	packets += 1
	play_sfx("collect", randf_range(0.97, 1.06), -6.0)
	fx.spawn_collect(pos)
	sync = clampf(sync + 7.0, 0.0, 100.0)
	hud.toast("+1 PAQUETE", HUD.CYAN)
	shake = maxf(shake, 1.4)
	_broadcast_stats()
	if bridge:
		bridge.send_event("collect")


func _on_impulse_used(pos: Vector2) -> void:
	play_sfx("impulse", randf_range(0.95, 1.05), -6.0)
	fx.spawn_impulse(pos + Vector2(0, -14))
	shake = maxf(shake, 1.2)


func _on_fell(pos: Vector2) -> void:
	fall_count += 1
	play_sfx("glitch", 0.8, -9.0)
	fx.spawn_respawn(pos)
	flash_color = Color(0.3, 0.85, 0.85)
	flash = 0.6
	shake = 3.0
	hud.toast("RECALIBRANDO", HUD.AMBER)


# ------------------------------------------------------------------ selftest
func _begin_selftest() -> void:
	started = true
	paused = false
	hud.hide_start()
	hud.hide_pause()
	player.start()
	var mp := get_global_mouse_position()
	if mp.x >= 0.0 and mp.x <= 640.0 and mp.y >= 0.0 and mp.y <= 360.0:
		spark.cursor_pos = mp
		spark.target = mp
		spark.position = mp
	spark.set_active(true)
	spark.autopilot = true
	spark.target = SELFTEST_POINTS[0]
	spark.position = SELFTEST_POINTS[0]
	spark.cursor_pos = SELFTEST_POINTS[0]
	selftest_timer = 0.0
	selftest_log = 0.0
	print("SELFTEST_START")
	var reach := level.reachable_from(1)
	print("SELFTEST_GRAPH platforms=%d reachable_from_G1=%d" % [level.platforms.size(), reach.size()])
	if reach.size() != level.platforms.size():
		print("SELFTEST_GRAPH_WARN reachable=", reach)
	visited[player.current_platform] = true


func _tick_selftest(delta: float) -> void:
	if selftest_finished:
		return
	selftest_timer += delta
	selftest_log += delta
	visited[player.current_platform] = true
	if selftest_timer >= 4.2:
		selftest_timer = 0.0
		selftest_index += 1
		if selftest_index >= SELFTEST_POINTS.size():
			_finish_selftest()
			return
		spark.target = SELFTEST_POINTS[selftest_index]
	if selftest_log >= 1.0:
		selftest_log = 0.0
		var plat_id := "?"
		if player.current_platform >= 0:
			plat_id = level.platforms[player.current_platform].id
		var goal_id := "?"
		if player.goal_platform >= 0:
			goal_id = level.platforms[player.goal_platform].id
		print("SELFTEST t=%.1f plat=%s goal=%s path=%d pos=(%.0f,%.0f) air=%s packets=%d stun=%d sync=%.0f" % [
			selftest_index, plat_id, goal_id, player.path.size(),
			player.global_position.x, player.global_position.y, player.airborne,
			packets, stun_count, sync,
		])


func _finish_selftest() -> void:
	selftest_finished = true
	var ids: Array = []
	for i in visited:
		if int(i) >= 0:
			ids.append(level.platforms[int(i)].id)
	ids.sort()
	print("SELFTEST_END visited=%s packets=%d crates=%d stuns=%d falls=%d best_sync=%d" % [
		str(ids), packets, crate_count, stun_count, fall_count, int(best_sync)])
	var ok := (crate_count > 0 and packets > 0 and visited.size() >= 6)
	print("SELFTEST_RESULT ", "PASS" if ok else "CHECK")
	get_tree().quit(0 if ok else 1)
