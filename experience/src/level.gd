class_name Level
extends Node2D
## Mundo de Pochland: plataformas, colisiones y grafo de saltos.
## El grafo se construye a partir de la física real del personaje para que
## la IA no improvise saltos imposibles.

const GRAVITY := 1500.0
const JUMP_VELOCITY := -470.0
const RUN_SPEED := 128.0
const MAX_JUMP_HEIGHT := 58.0
const MAX_EDGE_SPEED := 152.0
const LAYER_SOLID := 1
const LAYER_ONEWAY := 2

const PLATFORM_DEFS := [
	{"id": "G0", "x": 0.0, "w": 205.0, "y": 330.0, "one_way": false},
	{"id": "G1", "x": 245.0, "w": 200.0, "y": 330.0, "one_way": false},
	{"id": "G2", "x": 480.0, "w": 160.0, "y": 330.0, "one_way": false},
	{"id": "L1", "x": 300.0, "w": 100.0, "y": 288.0, "one_way": true},
	{"id": "L2", "x": 180.0, "w": 90.0, "y": 246.0, "one_way": true},
	{"id": "L3", "x": 60.0, "w": 100.0, "y": 204.0, "one_way": true},
	{"id": "L4", "x": 210.0, "w": 100.0, "y": 162.0, "one_way": true},
	{"id": "R1", "x": 500.0, "w": 100.0, "y": 288.0, "one_way": true},
	{"id": "R2", "x": 420.0, "w": 90.0, "y": 246.0, "one_way": true},
	{"id": "R3", "x": 520.0, "w": 90.0, "y": 204.0, "one_way": true},
	{"id": "R4", "x": 430.0, "w": 90.0, "y": 162.0, "one_way": true},
	{"id": "M1", "x": 340.0, "w": 90.0, "y": 120.0, "one_way": true},
	{"id": "M2", "x": 250.0, "w": 80.0, "y": 78.0, "one_way": true},
]


class Platform:
	var id: String = ""
	var rect: Rect2 = Rect2()
	var one_way: bool = true

	func x1() -> float:
		return rect.position.x

	func x2() -> float:
		return rect.position.x + rect.size.x

	func y() -> float:
		return rect.position.y

	func center_x() -> float:
		return rect.position.x + rect.size.x * 0.5


class Edge:
	var from: int = -1
	var to: int = -1
	var kind: String = "up" # up | drop | fall | level
	var takeoff: float = 0.0
	var land: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var weight: float = 1.0


class PlatformView:
	extends Node2D
	const TILE := preload("res://assets/sprites/platform_tile.png")
	const CAP_L := preload("res://assets/sprites/platform_cap_l.png")
	const CAP_R := preload("res://assets/sprites/platform_cap_r.png")
	const GLOW := preload("res://assets/sprites/glow.png")
	var spec: Platform

	func _draw() -> void:
		var x := spec.x1()
		var y := spec.y()
		var w := spec.rect.size.x
		var h := 16.0

		# sombra proyectada
		draw_rect(Rect2(x + 2.0, y + h + 1.0, w, 4.0), Color(0.01, 0.02, 0.04, 0.5))
		draw_rect(Rect2(x + 6.0, y + h + 5.0, w - 12.0, 2.0), Color(0.01, 0.02, 0.04, 0.25))

		# cuerpo embaldosado
		var cursor := 0.0
		while cursor < w:
			var piece := minf(16.0, w - cursor)
			draw_texture_rect_region(TILE, Rect2(Vector2(x + cursor, y), Vector2(piece, h)),
				Rect2(0, 0, piece, h))
			cursor += 16.0
		draw_texture(CAP_L, Vector2(x, y))
		draw_texture(CAP_R, Vector2(x + w - 16.0, y))

		# línea de energía superior
		draw_rect(Rect2(x + 4.0, y, w - 8.0, 1.0), Color(0.35, 0.95, 0.55, 0.22))
		draw_rect(Rect2(x + 8.0, y + 16.0, w - 16.0, 1.0), Color(0.22, 0.7, 0.45, 0.14))

		# detalles deterministas
		var tufts := int(w / 26.0)
		for i in range(tufts):
			var gx := x + 14.0 + float(i) * 26.0 + float((i * 7) % 9)
			var gh := 2.0 + float((i * 5) % 3)
			draw_rect(Rect2(gx, y - gh, 1.0, gh), Color(0.18, 0.55, 0.26, 0.9))
			draw_rect(Rect2(gx + 1.0, y - gh + 1.0, 1.0, gh - 1.0), Color(0.26, 0.72, 0.34, 0.8))
			if i % 3 == 0:
				draw_rect(Rect2(gx + 3.0, y - 2.0, 1.0, 2.0), Color(0.18, 0.55, 0.26, 0.7))

		# luces de cubierta
		var lights := int(w / 48.0)
		for i in range(lights):
			var lx := x + 20.0 + float(i) * 48.0
			draw_rect(Rect2(lx, y + 13.0, 3.0, 1.0), Color(0.35, 0.88, 0.85, 0.5))
			draw_rect(Rect2(lx + 1.0, y + 12.0, 1.0, 1.0), Color(0.55, 1.0, 0.95, 0.8))

		if spec.one_way:
			# propulsores anti-gravedad
			for tx in [x + 9.0, x + w - 9.0]:
				draw_rect(Rect2(tx - 2.0, y + 16.0, 4.0, 2.0), Color(0.1, 0.35, 0.38, 0.8))
				draw_rect(Rect2(tx - 1.0, y + 18.0, 2.0, 3.0), Color(0.33, 0.86, 0.8, 0.24))
				draw_texture_rect(GLOW, Rect2(tx - 8.0, y + 13.0, 16.0, 12.0), false,
					Color(0.35, 0.9, 0.85, 0.07))
			# enredaderas cortas
			for vx in [x + 27.0, x + w * 0.62]:
				var vh := 3.0 + fmod(vx, 4.0)
				draw_rect(Rect2(vx, y + 16.0, 1.0, vh), Color(0.15, 0.42, 0.24, 0.9))
				draw_rect(Rect2(vx + 1.0, y + 17.0, 1.0, maxf(0.0, vh - 2.0)),
					Color(0.23, 0.58, 0.3, 0.8))
			# farolillo colgante en plataformas altas
			if y < 300.0:
				var lx := x + w * 0.78
				draw_rect(Rect2(lx, y + 16.0, 1.0, 9.0), Color(0.12, 0.18, 0.2, 1.0))
				draw_rect(Rect2(lx - 2.0, y + 25.0, 5.0, 3.0), Color(0.38, 0.3, 0.16, 1.0))
				draw_rect(Rect2(lx - 1.0, y + 26.0, 3.0, 2.0), Color(0.96, 0.76, 0.4, 0.9))
				draw_texture_rect(GLOW, Rect2(lx - 11.0, y + 17.0, 22.0, 18.0), false,
					Color(0.95, 0.7, 0.35, 0.12))
			# pequeñas costillas bajo la plataforma
			for rx in [x + 8.0, x + w - 12.0]:
				draw_rect(Rect2(rx, y + 16.0, 1.0, 4.0), Color(0.15, 0.24, 0.31, 0.9))
				draw_rect(Rect2(rx + 1.0, y + 19.0, 2.0, 1.0), Color(0.15, 0.24, 0.31, 0.6))
		else:
			# farolillos de calle en el suelo
			for lx in [x + 30.0, x + w - 30.0]:
				if lx < x + 6.0 or lx > x + w - 6.0:
					continue
				draw_rect(Rect2(lx, y - 12.0, 1.0, 12.0), Color(0.16, 0.22, 0.24, 0.9))
				draw_rect(Rect2(lx - 2.0, y - 14.0, 5.0, 2.0), Color(0.2, 0.3, 0.3, 1.0))
				draw_rect(Rect2(lx - 1.0, y - 13.0, 3.0, 1.0), Color(0.95, 0.74, 0.38, 0.9))
				draw_rect(Rect2(lx - 3.0, y - 11.0, 7.0, 1.0), Color(0.9, 0.65, 0.3, 0.12))


var platforms: Array[Platform] = []
var adjacency: Array = [] # Array[Array[Edge]]
var player: Poch

var _edge_map: Dictionary = {}


func _ready() -> void:
	_build_platforms()
	_build_graph()
	_build_walls()


func _build_platforms() -> void:
	for def in PLATFORM_DEFS:
		var p := Platform.new()
		p.id = str(def["id"])
		p.one_way = bool(def["one_way"])
		p.rect = Rect2(float(def["x"]), float(def["y"]), float(def["w"]), 16.0)
		platforms.append(p)

		var view := PlatformView.new()
		view.spec = p
		view.z_index = 0
		add_child(view)

		var body := StaticBody2D.new()
		body.name = "col_" + p.id
		body.collision_layer = LAYER_ONEWAY if p.one_way else LAYER_SOLID
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(p.rect.size.x, 14.0)
		shape.shape = rect_shape
		shape.one_way_collision = p.one_way
		body.position = Vector2(p.center_x(), p.y() + 8.0)
		body.add_child(shape)
		add_child(body)

	adjacency.resize(platforms.size())
	for i in range(platforms.size()):
		adjacency[i] = []


func _build_walls() -> void:
	for x in [-8.0, 648.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = LAYER_SOLID
		wall.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(16.0, 420.0)
		shape.shape = rect_shape
		wall.position = Vector2(x, 180.0)
		wall.add_child(shape)
		add_child(wall)


func _build_graph() -> void:
	_edge_map.clear()
	for i in range(platforms.size()):
		adjacency[i] = []
	for i in range(platforms.size()):
		for j in range(platforms.size()):
			if i == j:
				continue
			var edge := _make_edge(i, j)
			if edge == null:
				continue
			var key := "%d:%d" % [i, j]
			if _edge_map.has(key) and _edge_map[key].weight <= edge.weight:
				continue
			_edge_map[key] = edge
	for key in _edge_map:
		var e: Edge = _edge_map[key]
		adjacency[e.from].append(e)


func _time_up(dy: float) -> float:
	var disc := JUMP_VELOCITY * JUMP_VELOCITY - 2.0 * GRAVITY * dy
	return (absf(JUMP_VELOCITY) + sqrt(maxf(disc, 0.0))) / GRAVITY


func _horizontal_gap(a: Platform, b: Platform) -> float:
	return maxf(0.0, maxf(a.x1(), b.x1()) - minf(a.x2(), b.x2()))


func _make_edge(i: int, j: int) -> Edge:
	var a := platforms[i]
	var b := platforms[j]
	var dy := a.y() - b.y() # >0: b está más arriba

	# mismo nivel: salto plano
	if absf(dy) <= 4.0:
		var gap := _horizontal_gap(a, b)
		if gap > 72.0 or gap <= 0.1:
			return null
		var dir := signf(b.center_x() - a.center_x())
		var takeoff := a.x2() - 7.0 if dir > 0 else a.x1() + 7.0
		var land := b.x1() + 10.0 if dir > 0 else b.x2() - 10.0
		var dx := land - takeoff
		var t := 2.0 * absf(JUMP_VELOCITY) / GRAVITY
		var vx := dx / t
		if absf(vx) > MAX_EDGE_SPEED:
			return null
		var e := Edge.new()
		e.from = i
		e.to = j
		e.kind = "level"
		e.takeoff = takeoff
		e.land = land
		e.vx = vx
		e.vy = JUMP_VELOCITY
		e.weight = absf(dx) + 8.0
		return e

	# b está arriba
	if dy > 0.0:
		if dy > MAX_JUMP_HEIGHT:
			return null
		var overlap_a := maxf(a.x1(), b.x1())
		var overlap_b := minf(a.x2(), b.x2())
		var takeoff := 0.0
		var land := 0.0
		var vx := 0.0
		if overlap_b - overlap_a >= 14.0:
			takeoff = clampf((overlap_a + overlap_b) * 0.5, a.x1() + 8.0, a.x2() - 8.0)
			land = clampf(takeoff, b.x1() + 10.0, b.x2() - 10.0)
		else:
			var dir := signf(b.center_x() - a.center_x())
			if absf(dir) < 0.1:
				dir = 1.0
			takeoff = a.x2() - 7.0 if dir > 0 else a.x1() + 7.0
			land = b.x1() + 10.0 if dir > 0 else b.x2() - 10.0
			var t := _time_up(dy)
			vx = (land - takeoff) / t
			if absf(vx) > MAX_EDGE_SPEED:
				return null
		var e := Edge.new()
		e.from = i
		e.to = j
		e.kind = "up"
		e.takeoff = takeoff
		e.land = land
		e.vx = vx
		e.vy = JUMP_VELOCITY
		e.weight = absf(land - takeoff) + dy * 1.15 + 8.0
		return e

	# b está abajo
	var drop := -dy
	if drop > 300.0:
		return null
	var oa := maxf(a.x1(), b.x1())
	var ob := minf(a.x2(), b.x2())
	if ob - oa >= 12.0:
		var takeoff := clampf((oa + ob) * 0.5, a.x1() + 8.0, a.x2() - 8.0)
		var land := clampf(takeoff, b.x1() + 10.0, b.x2() - 10.0)
		var e := Edge.new()
		e.from = i
		e.to = j
		e.kind = "drop"
		e.takeoff = takeoff
		e.land = land
		e.vx = 0.0
		e.vy = 0.0
		e.weight = drop * 0.8 + 10.0
		return e
	var fall_t := sqrt(2.0 * drop / GRAVITY)
	var dir := signf(b.center_x() - a.center_x())
	if absf(dir) < 0.1:
		return null
	var takeoff2 := a.x2() - 5.0 if dir > 0 else a.x1() + 5.0
	var land2 := b.x1() + 10.0 if dir > 0 else b.x2() - 10.0
	var dist := absf(land2 - takeoff2)
	if dist > fall_t * RUN_SPEED + 12.0:
		return null
	var e2 := Edge.new()
	e2.from = i
	e2.to = j
	e2.kind = "fall"
	e2.takeoff = takeoff2
	e2.land = land2
	e2.vx = clampf(dist / fall_t, 0.0, RUN_SPEED) * dir
	e2.vy = 0.0
	e2.weight = dist + drop * 0.7 + 12.0
	return e2


func get_edge(from_idx: int, to_idx: int) -> Edge:
	return _edge_map.get("%d:%d" % [from_idx, to_idx], null)


func platform_at(point: Vector2, tolerance: float = 7.0) -> int:
	var best := -1
	var best_dy := tolerance + 1.0
	for i in range(platforms.size()):
		var p := platforms[i]
		if point.x < p.x1() - 3.0 or point.x > p.x2() + 3.0:
			continue
		var dy := absf(point.y - p.y())
		if dy < best_dy:
			best_dy = dy
			best = i
	return best


func nearest_platform(point: Vector2) -> int:
	var best := 0
	var best_dist := INF
	for i in range(platforms.size()):
		var p := platforms[i]
		var q := Vector2(clampf(point.x, p.x1() + 8.0, p.x2() - 8.0), p.y())
		var d := q.distance_squared_to(point)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func platform_point(idx: int, point: Vector2) -> Vector2:
	var p := platforms[idx]
	return Vector2(clampf(point.x, p.x1() + 8.0, p.x2() - 8.0), p.y())


## Devuelve {path:[idx...], goal:int, target_x:float, cost:float}
func plan(from_idx: int, point: Vector2) -> Dictionary:
	if platforms.is_empty():
		return {}
	if from_idx < 0 or from_idx >= platforms.size():
		from_idx = nearest_platform(point)
	var n := platforms.size()
	var dist: Array = []
	var prev: Array = []
	var visited: Array = []
	dist.resize(n)
	prev.resize(n)
	visited.resize(n)
	for i in range(n):
		dist[i] = INF
		prev[i] = -1
		visited[i] = false
	dist[from_idx] = 0.0
	for _step in range(n):
		var u := -1
		var best := INF
		for i in range(n):
			if not visited[i] and dist[i] < best:
				best = dist[i]
				u = i
		if u == -1:
			break
		visited[u] = true
		for e in adjacency[u]:
			var nd: float = dist[u] + e.weight
			if nd < dist[e.to]:
				dist[e.to] = nd
				prev[e.to] = u

	var goal := from_idx
	var best_score := INF
	var target_x := clampf(point.x, platforms[from_idx].x1() + 8.0, platforms[from_idx].x2() - 8.0)
	for i in range(n):
		if dist[i] >= INF:
			continue
		var p := platforms[i]
		var px := clampf(point.x, p.x1() + 8.0, p.x2() - 8.0)
		var d := Vector2(px, p.y()).distance_to(point)
		# la cercanía al cursor manda; el coste del camino solo desempata
		var score: float = dist[i] * 0.10 + d
		if i == from_idx:
			score -= 8.0
		if score < best_score:
			best_score = score
			goal = i
			target_x = px
	var path: Array = []
	var cur := goal
	var guard := 0
	while cur != -1 and guard < n + 2:
		path.push_front(cur)
		if cur == from_idx:
			break
		cur = prev[cur]
		guard += 1
	if path.is_empty() or path[0] != from_idx:
		path = [from_idx]
		goal = from_idx
	return {"path": path, "goal": goal, "target_x": target_x, "cost": best_score}


func reachable_from(from_idx: int) -> Array:
	var seen := {}
	var queue: Array = [from_idx]
	seen[from_idx] = true
	while not queue.is_empty():
		var u: int = queue.pop_front()
		for e in adjacency[u]:
			if not seen.has(e.to):
				seen[e.to] = true
				queue.append(e.to)
	return seen.keys()
