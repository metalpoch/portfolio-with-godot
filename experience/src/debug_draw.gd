class_name DebugDraw
extends Node2D
## Visualización opcional (F3) del grafo de plataformas y la ruta activa.

var level: Level
var player: Poch


func _ready() -> void:
	z_index = 30
	visible = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if level == null:
		return
	for i in range(level.platforms.size()):
		var p: Level.Platform = level.platforms[i]
		var col := Color(0.2, 0.9, 0.6, 0.45) if p.one_way else Color(0.9, 0.7, 0.3, 0.5)
		draw_rect(Rect2(p.x1(), p.y(), p.rect.size.x, 16.0), col, false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(p.x1() + 3, p.y() - 4), p.id,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.9, 0.95, 0.85, 0.75))
		for e in level.adjacency[i]:
			var c := Color(0.4, 0.8, 1.0, 0.22)
			if e.kind == "drop":
				c = Color(0.9, 0.4, 0.7, 0.2)
			elif e.kind == "fall":
				c = Color(0.9, 0.6, 0.2, 0.2)
			draw_line(Vector2(e.takeoff, p.y()), Vector2(e.land, level.platforms[e.to].y()), c, 1.0)
	if player:
		var px := player.global_position
		draw_circle(px, 4.0, Color(1, 1, 0, 0.8), false, 1.0)
		for i in range(player.path.size() - 1):
			var a := level.platforms[player.path[i]]
			var b := level.platforms[player.path[i + 1]]
			draw_line(Vector2(a.center_x(), a.y() - 4), Vector2(b.center_x(), b.y() - 4),
				Color(1, 1, 0, 0.8), 1.0)
