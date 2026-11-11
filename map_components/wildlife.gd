extends Node2D
class_name Wildlife

# Living world. Sparrows flutter away, rabbits / deer / foxes run off, frogs hop by the water
# whenever any player (local or remote) gets close. Butterflies by day, buzzing flies,
# and flocks of birds crossing the sky. Plain Sprite2Ds driven from one _process,
# and only what's near the camera is animated.

const BIRD_TEX := preload("res://assets/wildlife/bird.png")
const SHADOW_TEX := preload("res://assets/wildlife/shadow_soft.png")
const BUTTERFLY_TEX := preload("res://assets/wildlife/butterfly.png")
const FLOCK_TEX := preload("res://assets/wildlife/flockbird.png")
const FROG_TEX := preload("res://assets/wildlife/frog.png")

const WATER := Vector2i(3, 1)
const LAVA := Vector2i(1, 1)
const MAGMA := Vector2i(2, 1)

# runners: texture, count, scale, scare distance, run speed, hop height
const RUNNERS := [
	{"tex": preload("res://assets/wildlife/rabbit.png"), "count": 16, "scale": 0.9, "scare": 60.0, "speed": 130.0, "hop": 6.0, "fps": 8.0},
	{"tex": preload("res://assets/wildlife/deer.png"), "count": 8, "scale": 1.1, "scare": 90.0, "speed": 165.0, "hop": 3.0, "fps": 9.0},
	{"tex": preload("res://assets/wildlife/fox.png"), "count": 8, "scale": 1.0, "scare": 75.0, "speed": 175.0, "hop": 1.0, "fps": 12.0},
]
const SPARROWS := 35
const FROGS := 18
const BUTTERFLIES := 22
const FLY_SWARMS := 12
const SCARE_BIRD := 70.0     # map-local px (the map is scaled 2x on screen)
const VIEW_R := 520.0        # only animate what could be on screen

var tilemap: TileMapLayer
var _land: Array[Vector2i] = []
var _shore: Array[Vector2i] = []   # land next to water, for frogs
var _birds: Array = []
var _runners: Array = []
var _frogs: Array = []
var _butterflies: Array = []
var _flies: Array = []
var _flock: Dictionary = {}
var _next_flock := 6.0
var _t := 0.0
var _is_day := true


func setup(map_tilemap: TileMapLayer, _is_snow: bool) -> void:
	tilemap = map_tilemap
	for cell in tilemap.get_used_cells():
		var a := tilemap.get_cell_atlas_coords(cell)
		if a == WATER or a == LAVA or a == MAGMA:
			continue
		_land.append(cell)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if tilemap.get_cell_atlas_coords(cell + d) == WATER:
				_shore.append(cell)
				break
	if _land.is_empty():
		return
	for i in Screen.fx_count(SPARROWS, 0.45):
		_birds.append(_critter(BIRD_TEX, 4, 0.9, _random_cell(_land)))
	for kind in RUNNERS:
		for i in Screen.fx_count(int(kind.count), 0.5):
			var c := _critter(kind.tex, 3, kind.scale, _random_cell(_land))
			c.kind = kind
			_runners.append(c)
	for i in Screen.fx_count(FROGS, 0.45):
		_frogs.append(_critter(FROG_TEX, 2, 0.9, _random_cell(_shore if not _shore.is_empty() else _land)))
	for i in Screen.fx_count(BUTTERFLIES, 0.45):
		_spawn_butterfly()
	for i in Screen.fx_count(FLY_SWARMS, 0.45):
		_spawn_flies()


func set_daylight(is_day: bool) -> void:
	_is_day = is_day


# ------------------------------------------------------------------ spawning
func _random_cell(cells: Array[Vector2i]) -> Vector2:
	return tilemap.map_to_local(cells.pick_random()) + Vector2(randf_range(-6, 6), randf_range(-6, 6))


func _is_walkable(p: Vector2) -> bool:
	var a := tilemap.get_cell_atlas_coords(tilemap.local_to_map(p))
	return a != WATER and a != LAVA and a != MAGMA and a != Vector2i(-1, -1)


func _critter(tex: Texture2D, frames: int, scl: float, pos: Vector2) -> Dictionary:
	var root := Node2D.new()
	root.position = pos
	add_child(root)
	var shadow := Sprite2D.new()
	shadow.texture = SHADOW_TEX
	shadow.scale = Vector2(0.5, 0.5) * scl
	shadow.position = Vector2(0, 5)
	root.add_child(shadow)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.hframes = frames
	spr.scale = Vector2(scl, scl)
	spr.offset = Vector2(0, -tex.get_height() * 0.5 + 6)  # feet on the ground
	spr.flip_h = randf() < 0.5
	root.add_child(spr)
	return {"root": root, "spr": spr, "shadow": shadow, "state": "idle", "t": randf() * 3.0,
		"vel": Vector2.ZERO, "alt": 0.0, "kind": {}}


func _spawn_butterfly() -> void:
	var s := Sprite2D.new()
	s.texture = BUTTERFLY_TEX
	s.hframes = 2
	s.scale = Vector2(0.8, 0.8)
	s.modulate = [Color("ffd166"), Color("ef476f"), Color("8ecae6"), Color("ffffff"), Color("cdb4db")].pick_random()
	var home := _random_cell(_land)
	s.position = home
	s.z_index = 3000
	add_child(s)
	_butterflies.append({"spr": s, "home": home, "seed": randf() * 100.0, "flee": Vector2.ZERO})


func _spawn_flies() -> void:
	var home := _random_cell(_land)
	var dots := []
	for i in 5:
		var d := ColorRect.new()
		d.size = Vector2(1, 1)
		d.color = Color(0.08, 0.08, 0.08, 0.9)
		d.z_index = 3000
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(d)
		dots.append(d)
	_flies.append({"home": home, "dots": dots, "seed": randf() * 50.0})


# A V-formation of birds that crosses the sky above the camera, with soft ground shadows.
func _spawn_flock(view_c: Vector2) -> void:
	var dir := Vector2.RIGHT.rotated(randf_range(-0.5, 0.5)) * (1.0 if randf() < 0.5 else -1.0)
	var root := Node2D.new()
	root.position = view_c - dir * (VIEW_R + 60.0) + dir.orthogonal() * randf_range(-200, 200)
	root.z_index = 4090
	add_child(root)
	var birds := []
	var n := randi_range(5, 9)
	for i in n:
		var side := 1 if i % 2 == 0 else -1
		var rank := (i + 1) / 2
		var off := -dir * rank * 12.0 + dir.orthogonal() * side * rank * 9.0
		var sh := Sprite2D.new()
		sh.texture = FLOCK_TEX
		sh.hframes = 2
		sh.modulate = Color(0, 0, 0, 0.18)
		sh.position = off + Vector2(30, 46)   # shadow falls on the ground below
		root.add_child(sh)
		var b := Sprite2D.new()
		b.texture = FLOCK_TEX
		b.hframes = 2
		b.position = off
		root.add_child(b)
		birds.append([b, sh, randf() * 10.0])
	_flock = {"root": root, "vel": dir * 70.0, "birds": birds, "life": 0.0}


# ------------------------------------------------------------------ update
func _process(delta: float) -> void:
	if _land.is_empty():
		return
	_t += delta
	var actors: Array[Vector2] = []
	for a in get_tree().get_nodes_in_group("actors"):
		actors.append(a.position)
	if actors.is_empty():
		return
	var cam := get_viewport().get_camera_2d()
	var vc: Vector2 = to_local(cam.get_screen_center_position()) if cam else actors[0]

	for b in _birds: _update_bird(b, actors, delta, vc)
	for r in _runners: _update_runner(r, actors, delta, vc)
	for f in _frogs: _update_frog(f, actors, delta, vc)
	for f in _butterflies: _update_butterfly(f, actors, delta, vc)
	for f in _flies: _update_flies(f, vc)
	_update_flock(delta, vc)


func _nearest(p: Vector2, actors: Array[Vector2]) -> Vector2:
	var best := actors[0]
	for a in actors:
		if a.distance_squared_to(p) < best.distance_squared_to(p):
			best = a
	return best


func _depth(p: Vector2) -> int:
	return int(p.y * 2.0 / 4.0)  # same rule as player.update_depth (map is scaled 2x)


func _update_bird(b: Dictionary, actors: Array[Vector2], delta: float, vc: Vector2) -> void:
	var root: Node2D = b.root
	var spr: Sprite2D = b.spr
	b.t += delta
	match b.state:
		"idle":
			if root.position.distance_to(vc) > VIEW_R:
				return
			spr.frame = 1 if fmod(b.t, 1.6) > 1.3 else 0     # peck now and then
			if fmod(b.t, 4.0) < delta:                          # tiny hop
				root.position += Vector2(randf_range(-4, 4), randf_range(-2, 2))
			root.z_index = _depth(root.position)
			var threat := _nearest(root.position, actors)
			if threat.distance_to(root.position) < SCARE_BIRD:
				var away := (root.position - threat).normalized()
				if away == Vector2.ZERO: away = Vector2.UP
				b.vel = (away + Vector2(0, -0.6)).normalized() * randf_range(150, 210)
				b.state = "fly"
				b.t = 0.0
				spr.flip_h = b.vel.x < 0
				root.z_index = 4000
		"fly":
			root.position += b.vel * delta
			b.alt = min(b.alt + 60.0 * delta, 80.0)
			spr.position.y = -b.alt
			spr.frame = 2 + int(b.t * 12.0) % 2
			b.shadow.modulate.a = clamp(1.0 - b.alt / 80.0, 0.0, 1.0)
			root.modulate.a = clamp(3.0 - b.t, 0.0, 1.0)
			if b.t > 3.0:
				b.state = "gone"
				b.t = 0.0
				root.visible = false
		"gone":
			if b.t > 10.0:  # land somewhere else, out of sight
				root.position = _random_cell(_land)
				if root.position.distance_to(vc) < VIEW_R:
					return
				spr.position.y = 0
				b.alt = 0.0
				b.shadow.modulate.a = 1.0
				root.modulate.a = 1.0
				root.visible = true
				b.state = "idle"


func _update_runner(r: Dictionary, actors: Array[Vector2], delta: float, vc: Vector2) -> void:
	var root: Node2D = r.root
	var spr: Sprite2D = r.spr
	if root.position.distance_to(vc) > VIEW_R:
		return
	var k: Dictionary = r.kind
	r.t += delta
	var threat := _nearest(root.position, actors)
	if r.state == "idle":
		spr.frame = 0
		spr.position.y = 0.0
		if fmod(r.t, 5.0) < delta:  # graze / look around
			spr.flip_h = not spr.flip_h
		if threat.distance_to(root.position) < k.scare:
			var away := (root.position - threat).normalized()
			if away == Vector2.ZERO: away = Vector2.RIGHT
			r.vel = away.rotated(randf_range(-0.5, 0.5)) * k.speed * randf_range(0.85, 1.1)
			r.state = "run"
			r.t = 0.0
	else:
		var next: Vector2 = root.position + r.vel * delta
		if _is_walkable(next):
			root.position = next
		else:
			r.vel = r.vel.rotated(PI * 0.6)  # turn away from water / lava
		spr.flip_h = r.vel.x < 0
		var cycle := fmod(r.t * k.fps * 0.5, 1.0)
		spr.frame = 1 if cycle < 0.5 else 2
		spr.position.y = -sin(cycle * PI) * k.hop
		if r.t > 1.6 and threat.distance_to(root.position) > k.scare * 1.6:
			r.state = "idle"
			r.t = 0.0
	root.z_index = _depth(root.position)


func _update_frog(f: Dictionary, actors: Array[Vector2], delta: float, vc: Vector2) -> void:
	var root: Node2D = f.root
	var spr: Sprite2D = f.spr
	if root.position.distance_to(vc) > VIEW_R:
		return
	f.t += delta
	if f.state == "idle":
		spr.frame = 0
		spr.position.y = 0.0
		var threat := _nearest(root.position, actors)
		if threat.distance_to(root.position) < 40.0 or fmod(f.t, 7.0) < delta:
			var away := (root.position - threat).normalized()
			if away == Vector2.ZERO: away = Vector2.LEFT
			f.vel = away.rotated(randf_range(-0.7, 0.7)) * 70.0
			f.state = "hop"
			f.t = 0.0
			spr.flip_h = f.vel.x < 0
	else:
		var hop := clampf(f.t / 0.35, 0.0, 1.0)
		var next: Vector2 = root.position + f.vel * delta
		if _is_walkable(next):
			root.position = next
		spr.frame = 1
		spr.position.y = -sin(hop * PI) * 8.0
		if hop >= 1.0:
			f.state = "idle"
			f.t = randf() * 3.0
	root.z_index = _depth(root.position)


func _update_butterfly(f: Dictionary, actors: Array[Vector2], delta: float, vc: Vector2) -> void:
	var s: Sprite2D = f.spr
	s.visible = _is_day and f.home.distance_to(vc) < VIEW_R
	if not s.visible:
		return
	var k: float = _t * 0.8 + f.seed
	var threat := _nearest(s.position, actors)
	if threat.distance_to(s.position) < 30.0:
		f.flee = f.flee.lerp((s.position - threat).normalized() * 40.0, delta * 3.0)
	else:
		f.flee = f.flee.lerp(Vector2.ZERO, delta * 0.5)
	s.position = f.home + f.flee + Vector2(sin(k * 1.3) * 22.0, sin(k * 2.1) * 12.0 - 10.0)
	s.frame = int((_t + f.seed) * 10.0) % 2


func _update_flies(f: Dictionary, vc: Vector2) -> void:
	var show: bool = f.home.distance_to(vc) < VIEW_R
	for i in f.dots.size():
		var d: ColorRect = f.dots[i]
		d.visible = show
		if show:
			var k: float = _t * 5.0 + f.seed + i * 1.7
			d.position = f.home + Vector2(sin(k * 1.9) * 7.0 + sin(k * 4.3) * 2.0, cos(k * 2.3) * 5.0 - 8.0)


func _update_flock(delta: float, vc: Vector2) -> void:
	if _flock.is_empty():
		_next_flock -= delta
		if _next_flock <= 0.0 and _is_day:
			_spawn_flock(vc)
			_next_flock = randf_range(18.0, 35.0)
		return
	_flock.life += delta
	var root: Node2D = _flock.root
	root.position += _flock.vel * delta
	for b in _flock.birds:
		var fr := int((_t + b[2]) * 6.0) % 2
		b[0].frame = fr
		b[1].frame = fr
		b[0].position.y += sin((_t + b[2]) * 3.0) * 0.05  # gentle bobbing
	if _flock.life > 20.0:
		root.queue_free()
		_flock = {}
