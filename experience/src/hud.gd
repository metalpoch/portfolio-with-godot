class_name HUD
extends CanvasLayer
## Interfaz diegética de POCHLAND: marca, señal, paquetes, inicio y pausa.

signal start_requested
signal resume_requested

const PIXEL := preload("res://fonts/PressStart2P-Regular.ttf")
const MONO := preload("res://fonts/JetBrainsMono-Regular.ttf")
const MONO_BOLD := preload("res://fonts/JetBrainsMono-SemiBold.ttf")
const CREAM := Color(0.96, 0.91, 0.84)
const MUTED := Color(0.58, 0.65, 0.72)
const GREEN := Color(0.13, 0.65, 0.29)
const MINT := Color(0.35, 0.89, 0.48)
const CYAN := Color(0.4, 0.88, 0.82)
const AMBER := Color(0.91, 0.71, 0.35)
const PANEL_BG := Color(0.035, 0.07, 0.12, 0.94)
const LINE := Color(0.96, 0.91, 0.84, 0.16)

var root: Control
var start_overlay: Control
var pause_overlay: Control
var start_button: Button
var resume_button: Button
var segments: Array = []
var sync_value: Label
var packets_value: Label
var mute_label: Label
var hint: Label
var sync_label: Label
var _toasts: Array = []
var _sync_flash := 0.0
var _time := 0.0
var _portrait: TextureRect


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_start_overlay()
	_build_pause_overlay()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_sync_flash = maxf(0.0, _sync_flash - delta)
	if sync_value:
		var c := MINT.lerp(CREAM, _sync_flash)
		sync_value.modulate = c
	for i in range(_toasts.size() - 1, -1, -1):
		var t: Dictionary = _toasts[i]
		t["life"] -= delta
		var label: Label = t["label"]
		label.position.y -= delta * 18.0
		label.modulate.a = clampf(t["life"] / 0.8, 0.0, 1.0)
		if t["life"] <= 0.0:
			label.queue_free()
			_toasts.remove_at(i)


func _panel_style(bg: Color, border: Color, width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = width
	s.border_width_right = width
	s.border_width_top = width
	s.border_width_bottom = width
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _full_rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_hud() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# marca
	var brand := PanelContainer.new()
	brand.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, LINE, 1))
	brand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	brand.offset_left = 10
	brand.offset_top = 8
	brand.offset_right = 196
	brand.offset_bottom = 54
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brand)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	brand.add_child(bv)
	bv.add_child(_label("POCHLAND", PIXEL, 16, CREAM))
	bv.add_child(_label("SIGUE LA LUZ", PIXEL, 8, MINT))

	# señal + paquetes
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, LINE, 1))
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -210
	box.offset_top = 8
	box.offset_right = -10
	box.offset_bottom = 76
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)
	sync_label = _label("SEÑAL", PIXEL, 8, MUTED)
	sync_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sync_label)
	sync_value = _label("000%", MONO_BOLD, 12, CREAM)
	top.add_child(sync_value)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	v.add_child(bar)
	for i in range(12):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(12, 7)
		seg.color = Color(0.1, 0.17, 0.2, 0.9)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(seg)
		segments.append(seg)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	v.add_child(bottom)
	packets_value = _label("PAQUETES 00", PIXEL, 8, CYAN)
	packets_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(packets_value)
	var dot_holder := Control.new()
	dot_holder.custom_minimum_size = Vector2(10, 10)
	dot_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(dot_holder)
	var dot := ColorRect.new()
	dot.color = MINT
	dot.position = Vector2(2, 3)
	dot.size = Vector2(6, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_holder.add_child(dot)

	# pista de controles
	hint = _label("MUEVE EL CURSOR  ·  CLIC / ESPACIO: IMPULSO  ·  M: SONIDO", MONO, 11, MUTED)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -22
	hint.offset_bottom = -6
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	mute_label = _label("SONIDO OFF · M", MONO, 10, AMBER)
	mute_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mute_label.offset_left = -150
	mute_label.offset_top = -22
	mute_label.offset_right = -10
	mute_label.offset_bottom = -6
	mute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mute_label.visible = false
	mute_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mute_label)

	start_overlay = _build_overlay()
	pause_overlay = _build_overlay()
	pause_overlay.visible = false


func _build_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(_full_rect(Color(0.015, 0.03, 0.055, 0.82)))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.065, 0.11, 0.97), GREEN, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	box.add_child(header)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(74, 74)
	portrait_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.12, 0.1, 1), MINT, 1))
	header.add_child(portrait_frame)
	var portrait_center := CenterContainer.new()
	portrait_frame.add_child(portrait_center)
	_portrait = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/poch.png")
	atlas.region = Rect2(0, 0, 16, 16)
	_portrait.texture = atlas
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.custom_minimum_size = Vector2(56, 56)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_center.add_child(_portrait)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 3)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(titles)
	titles.add_child(_label("POCHLAND", PIXEL, 24, CREAM))
	titles.add_child(_label("SIGUE LA LUZ", PIXEL, 8, MINT))
	var tag := _label("Una experiencia interactiva de Keiber Urbila", MONO, 11, MUTED)
	titles.add_child(tag)

	box.add_child(_hrule())

	var head := _label("MUEVE EL CURSOR.", PIXEL, 16, CREAM)
	box.add_child(head)
	var body := _label("Poch planifica el camino: salta entre plataformas, rompe cajas y esquiva bugs para no perder tu señal.",
		MONO, 12, Color(0.78, 0.83, 0.87))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420, 34)
	box.add_child(body)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	box.add_child(controls)
	var key1 := _label("[ CURSOR ]", MONO_BOLD, 11, MINT)
	var key2 := _label("[ CLIC / ESPACIO ]", MONO_BOLD, 11, CYAN)
	var key3 := _label("[ M ]", MONO_BOLD, 11, AMBER)
	controls.add_child(key1)
	controls.add_child(_label("mover", MONO, 11, MUTED))
	controls.add_child(key2)
	controls.add_child(_label("impulso", MONO, 11, MUTED))
	controls.add_child(key3)
	controls.add_child(_label("sonido", MONO, 11, MUTED))

	var start := _make_button("CONECTAR CON POCH  >>", PIXEL, 16)
	box.add_child(start)
	if not start_overlay:
		start_button = start
		start.pressed.connect(func() -> void: start_requested.emit())
	else:
		resume_button = start
		start.text = "VOLVER AL JUEGO  >>"
		start.pressed.connect(func() -> void: resume_requested.emit())

	var foot := _label("El audio se activa al entrar  ·  Godot 4.7  ·  single-thread web", MONO, 10, MUTED)
	box.add_child(foot)

	return overlay


func _hrule() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.96, 0.91, 0.84, 0.13)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _make_button(text: String, font: Font, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.04, 0.09, 0.07))
	b.add_theme_color_override("font_hover_color", Color(0.02, 0.06, 0.04))
	b.add_theme_color_override("font_pressed_color", Color(0.02, 0.06, 0.04))
	b.add_theme_color_override("font_focus_color", Color(0.02, 0.06, 0.04))
	b.custom_minimum_size = Vector2(0, 38)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.26, 0.78, 0.4)
	normal.border_color = Color(0.55, 1.0, 0.65)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.38, 0.95, 0.55)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.18, 0.6, 0.3)
	pressed.border_width_bottom = 1
	pressed.content_margin_top = 3
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(0.96, 0.91, 0.84, 0.9)
	focus.border_width_left = 1
	focus.border_width_right = 1
	focus.border_width_top = 1
	focus.border_width_bottom = 1
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	return b


func _build_start_overlay() -> void:
	root.add_child(start_overlay)


func _build_pause_overlay() -> void:
	var box := pause_overlay.get_child(1).get_child(0).get_child(0).get_child(0) as VBoxContainer
	# limpiar el contenido clonado de la portada y construir pausa
	for c in box.get_children():
		c.queue_free()
	box.add_child(_label("SEÑAL EN ESPERA", PIXEL, 16, CREAM))
	var msg := _label("Poch se queda quieto mientras no estás. Tu señal sigue aquí.",
		MONO, 12, Color(0.78, 0.83, 0.87))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(420, 34)
	box.add_child(msg)
	box.add_child(_hrule())
	var b := _make_button("VOLVER AL JUEGO  >>", PIXEL, 16)
	b.pressed.connect(func() -> void: resume_requested.emit())
	resume_button = b
	box.add_child(b)
	var foot := _label("El juego se pausa cuando la pestaña o el iframe pierden el foco.",
		MONO, 10, MUTED)
	box.add_child(foot)
	root.add_child(pause_overlay)


func show_start() -> void:
	start_overlay.visible = true
	pause_overlay.visible = false
	start_button.call_deferred("grab_focus")


func hide_start() -> void:
	start_overlay.visible = false


func show_pause() -> void:
	pause_overlay.visible = true
	if resume_button:
		resume_button.call_deferred("grab_focus")


func hide_pause() -> void:
	pause_overlay.visible = false


func update_stats(sync: float, packets: int) -> void:
	var value := clampi(int(round(sync)), 0, 100)
	sync_value.text = "%03d%%" % value
	var filled := int(ceil(sync / 100.0 * segments.size()))
	for i in range(segments.size()):
		var seg: ColorRect = segments[i]
		if i < filled:
			var t := float(i) / float(segments.size() - 1)
			seg.color = Color(0.17, 0.6, 0.3).lerp(MINT, t * 0.7 + 0.25)
		else:
			seg.color = Color(0.1, 0.17, 0.2, 0.9)
	packets_value.text = "PAQUETES %02d" % packets


func set_muted(muted: bool) -> void:
	mute_label.visible = muted


func flash_sync() -> void:
	_sync_flash = 1.0


func toast(text: String, color := MINT) -> void:
	var label := _label(text, PIXEL, 8, color)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(320 - 80, 92 + _toasts.size() * 14)
	label.custom_minimum_size = Vector2(160, 12)
	root.add_child(label)
	_toasts.append({"label": label, "life": 0.9})
