extends Node2D
class_name SurvivalGame

# Survival mode: a separate arcade game reached from the Stats page.
# Waves of mobs (10 types, random mutations) pour out of portals; clear them and a
# boss arrives (10 named bosses, then endless generated ones). Beat it, pick an
# upgrade, next round. Pure GDScript, no AI server.

const TILESET := preload("res://resources/tile_set.tres")
const PLAYER_SCENE := preload("res://player/player.tscn")
const POST_SHADER := preload("res://shaders/post_fx.gdshader")
const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")
const W := 46                  # arena cells (incl. sand ring)
const H := 32
const M := 6                   # water margin cells
const TILE := 16.0
const GRASS := Vector2i(0, 0)
const DIRT := Vector2i(1, 0)
const SAND := Vector2i(0, 1)
const LAVA := Vector2i(1, 1)
const WATER := Vector2i(3, 1)

const BOSSES := [
	{"name": "Slime King", "tpl": "slime", "tint": Color(0.6, 1.0, 0.6), "shot": Color(0.5, 1.0, 0.45), "patterns": ["slam", "summon", "ring"]},
	{"name": "Bone Lord", "tpl": "skeleton", "tint": Color(1.0, 0.95, 0.85), "shot": Color(0.95, 0.92, 0.8), "patterns": ["ring", "aimed", "spiral"]},
	{"name": "Ember Golem", "tpl": "golem", "tint": Color(1.0, 0.6, 0.35), "shot": Color(1.0, 0.5, 0.15), "patterns": ["charge", "trail", "ring"], "minion": "zombie"},
	{"name": "Wraith Queen", "tpl": "ghost", "tint": Color(0.75, 0.75, 1.0), "shot": Color(0.7, 0.6, 1.0), "patterns": ["teleport", "spiral", "summon"]},
	{"name": "Brood Mother", "tpl": "spider", "tint": Color(1.0, 0.75, 0.8), "shot": Color(0.9, 0.3, 0.4), "patterns": ["web", "summon", "charge"]},
	{"name": "Storm Bat", "tpl": "bat", "tint": Color(0.7, 0.85, 1.0), "shot": Color(0.6, 0.85, 1.0), "patterns": ["charge", "aimed", "spread"]},
	{"name": "Necromancer", "tpl": "mage", "tint": Color(0.55, 0.45, 0.6), "shot": Color(0.6, 1.0, 0.6), "patterns": ["summon", "homing", "teleport"], "minion": "zombie"},
	{"name": "Dire Alpha", "tpl": "wolf", "tint": Color(0.9, 0.8, 0.7), "shot": Color(1.0, 0.8, 0.4), "patterns": ["charge", "summon", "spread"]},
	{"name": "Frost Titan", "tpl": "golem", "tint": Color(0.65, 0.85, 1.0), "shot": Color(0.7, 0.95, 1.0), "patterns": ["spread", "slam", "ring"], "minion": "bat"},
	{"name": "Hollow Twin", "tpl": "zombie", "tint": Color(0.75, 0.55, 1.0), "shot": Color(0.8, 0.5, 1.0), "patterns": ["clones", "spiral", "homing"]},
]
const ALL_PATTERNS := ["ring", "spread", "spiral", "aimed", "charge", "slam", "summon", "teleport", "trail", "web", "homing", "clones"]
const NAME_A := ["Ancient", "Cursed", "Feral", "Molten", "Hollow", "Rotten", "Thunder", "Frozen", "Shadow", "Iron", "Venom", "Crystal"]
const NAME_B := ["Behemoth", "Warden", "Tyrant", "Horror", "Matriarch", "Colossus", "Reaper", "Sovereign", "Devourer", "Lich", "Juggernaut", "Wyrm"]
const UPGRADES := [
	["Sharper bolts", "+1 damage"], ["Rapid fire", "Shoot 20% faster"], ["Multishot", "+1 bolt per shot"],
	["Piercing", "Bolts pass through\n+1 enemy"], ["Swift feet", "+15% move speed"], ["Quick dash", "Dash cooldown -30%"],
	["Big bolts", "Bigger bolts,\n+25% damage"], ["Second wind", "Heal 3 hearts"], ["Vampire fang", "Heal 1 heart\nevery 20 kills"],
]

var tilemap: TileMapLayer
var player                              # the shared player.tscn hero (script vars: speed, last_dir, airborne)
var hearts: HeartSystem
var arena: Rect2
var mobs: Array[SurvivalMob] = []
var shots: Array[SurvivalShot] = []
var fires: Array = []                   # [node, life]
var boss: SurvivalMob
var round_no := 0
var score := 0
var kills := 0
var to_spawn := 0
var portals_open := 0
var state := "intro"                    # waves, boss_wait, boss, upgrade, over
var stats := {"dmg": 1.0, "fire_cd": 0.32, "multishot": 1, "pierce": 0, "bolt_speed": 260.0,
	"size": 1.0, "dash_cd": 1.3, "speed": 1.0, "lifesteal": 0}
var _spawn_t := 1.0
var _fire_t := 0.0
var _dash_t := 0.0
var _invuln := 0.0
var _slow_t := 0.0
var _base_speed := 200.0
var _base_sprint := 350.0
var _dash_was := false
var _t := 0.0
# dev/testing: -- --surv-round=N --surv-bot (auto-aim + auto-upgrade) --surv-god (no damage)
var _bot := "--surv-bot" in OS.get_cmdline_user_args()
var _god := "--surv-god" in OS.get_cmdline_user_args()

var sfx: SurvivalSfx
var _hurt_flash: ColorRect
var _dash_fill: ColorRect
var _weapon_lbl: Label
var _round_lbl: Label
var _score_lbl: Label
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_fill: ColorRect
var _banner: Label


func _ready() -> void:
	randomize()
	_build_arena()
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = arena.get_center()
	add_child(player)
	player.add_to_group("actors")
	_base_speed = player.speed
	_base_sprint = player.sprint_speed
	hearts = HeartSystem.new()
	hearts.max_hearts = 6
	hearts.current_hearts = 6
	add_child(hearts)
	hearts.player_died.connect(_on_died)
	sfx = SurvivalSfx.new()
	add_child(sfx)
	_build_hud()
	_decorate_arena()
	_set_crosshair()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--surv-round="):
			round_no = int(a.get_slice("=", 1)) - 1
	if _bot:
		await get_tree().create_timer(0.8).timeout
		_next_round()
	else:
		_show_intro()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)   # give the rest of the game its normal cursor back


# Pixel crosshair so you always know where bolts will go.
func _set_crosshair() -> void:
	var img := Image.create(23, 23, false, Image.FORMAT_RGBA8)
	var c := Color(1.0, 0.9, 0.4)
	var o := Color(0.08, 0.05, 0.1)
	for i in range(0, 23):
		for k in [-1, 1]:
			if abs(i - 11) > 3:
				img.set_pixel(i, 11 + k, o); img.set_pixel(11 + k, i, o)
	for i in range(0, 23):
		if abs(i - 11) > 3:
			img.set_pixel(i, 11, c); img.set_pixel(11, i, c)
	img.set_pixel(11, 11, c)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2(11, 11))


# Flowers inside the arena and trees along its edges, so it isn't a flat green box.
func _decorate_arena() -> void:
	var flowers := ["res://assets/flowers/cherry_sapling.png", "res://assets/flowers/coral_fan_red.png",
		"res://assets/flowers/crimson_fungus.png"]
	for f in ResourceLoader.list_directory("res://assets/flowers"):   # works in exported builds too
		if f.ends_with(".png") and flowers.size() < 10:
			flowers.append("res://assets/flowers/" + f)
	for k in 45:
		var s := Sprite2D.new()
		s.texture = load(flowers.pick_random())
		s.position = Vector2(randf_range(arena.position.x, arena.end.x), randf_range(arena.position.y, arena.end.y))
		if tilemap.get_cell_atlas_coords(tilemap.local_to_map(s.position)) == LAVA:
			s.queue_free()
			continue
		s.offset = Vector2(0, -8)
		s.scale = Vector2.ONE * randf_range(0.7, 1.0)
		s.z_index = int(s.position.y / 2.0) - 2
		add_child(s)
	var trees := ["res://assets/trees/birch_1.png", "res://assets/trees/fir_tree_2.png", "res://assets/trees/jungle_tree_3.png",
		"res://assets/trees/middle_lane_tree2.png"]
	for k in 12:
		var t := Sprite2D.new()
		t.texture = load(trees.pick_random())
		t.centered = false
		t.offset = Vector2(-t.texture.get_width() / 2.0, -t.texture.get_height() + 10)
		t.scale = Vector2(0.5, 0.5)
		var top := k < 6
		t.position = Vector2(lerpf(arena.position.x + 30, arena.end.x - 30, (k % 6) / 5.0) + randf_range(-20, 20),
			arena.position.y - 6.0 if top else arena.end.y + 22.0)
		t.z_index = int(t.position.y / 2.0)
		t.modulate = Color(1, 1, 1, 0.95)
		add_child(t)


# First thing a player sees: what to do and how.
func _show_intro() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var v := PixelUI.page(layer, "💀 Survival", 640, func():
		get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn"))
	var best := int(Global.stats.get("survival_best_round", 0))
	v.add_child(PixelUI.label("Clear each wave, then defeat the boss.\nEvery boss lets you pick an upgrade. The bosses never end.", 26))
	var keys := GridContainer.new()
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 24)
	v.add_child(keys)
	for row in [["Shoot", "hold Left mouse  /  J"], ["Dash", "Right mouse  /  K"], ["Move", "WASD  ·  Shift sprint"],
			["Jump", "Space"], ["Pause", "Esc"]]:
		keys.add_child(PixelUI.label(row[0], 26, PixelUI.GOLD, false))
		keys.add_child(PixelUI.label(row[1], 26, PixelUI.CREAM, false))
	if best > 0:
		v.add_child(PixelUI.label("Your best: round %d" % best, 24, PixelUI.MUTED))
	var go := PixelUI.button("Fight!", func():
		get_tree().paused = false
		layer.queue_free()
		_next_round(), true)
	go.custom_minimum_size = Vector2(0, 60)
	v.add_child(go)
	get_tree().paused = true


# ------------------------------------------------------------------ arena
func _build_arena() -> void:
	tilemap = TileMapLayer.new()
	tilemap.tile_set = TILESET
	add_child(tilemap)
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.12
	for x in W + 2 * M:
		for y in H + 2 * M:
			var ax := x - M
			var ay := y - M
			var t := WATER
			if ax >= 0 and ay >= 0 and ax < W and ay < H:
				t = SAND if (ax == 0 or ay == 0 or ax == W - 1 or ay == H - 1) else (DIRT if noise.get_noise_2d(x, y) > 0.35 else GRASS)
			tilemap.set_cell(Vector2i(x, y), 0, t)
	var c := Vector2(M + W / 2.0, M + H / 2.0)
	for k in 4:   # lava pools away from the centre
		var p := Vector2(randf_range(M + 4, M + W - 5), randf_range(M + 4, M + H - 5))
		if p.distance_to(c) < 9.0:
			continue
		var rad := randf_range(1.4, 2.6)
		for x in range(-3, 4):
			for y in range(-3, 4):
				if Vector2(x, y * 1.2).length() < rad:
					tilemap.set_cell(Vector2i(p) + Vector2i(x, y), 0, LAVA)
	var water := Water.new()
	add_child(water)
	water.setup(tilemap, W + 2 * M, H + 2 * M)
	arena = Rect2(Vector2(M, M) * TILE, Vector2(W, H) * TILE).grow(-10.0)
	# invisible walls along the sand ring
	var body := StaticBody2D.new()
	add_child(body)
	var r := arena.grow(10.0)
	for rect in [Rect2(r.position.x - 32, r.position.y - 32, r.size.x + 64, 32), Rect2(r.position.x - 32, r.end.y, r.size.x + 64, 32),
			Rect2(r.position.x - 32, r.position.y, 32, r.size.y), Rect2(r.end.x, r.position.y, 32, r.size.y)]:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = rect.size
		cs.shape = sh
		cs.position = rect.get_center()
		body.add_child(cs)
	# post-processing like the main game (vignette, grade, grain)
	var layer := CanvasLayer.new()
	layer.layer = 1
	var fx := ColorRect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = POST_SHADER
	mat.set_shader_parameter("vignette", 0.5)
	fx.material = mat
	layer.add_child(fx)
	add_child(layer)


func clamp_arena(p: Vector2) -> Vector2:
	return p.clamp(arena.position, arena.end)


func near(p: Vector2, rmin: float, rmax: float) -> Vector2:
	return clamp_arena(p + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(rmin, rmax))


func near_player(rmin: float, rmax: float) -> Vector2:
	return near(player.position, rmin, rmax)


func ppos() -> Vector2:
	return player.position + Vector2(0, -8)


# ------------------------------------------------------------------ rounds
func _next_round() -> void:
	round_no += 1
	state = "waves"
	to_spawn = 0 if "--surv-boss-now" in OS.get_cmdline_user_args() else mini(6 + 3 * round_no, 45)
	_spawn_t = 1.2
	banner("Round %d" % round_no, PixelUI.GOLD)
	sfx.play("portal", 0.0)
	_update_hud()


func _boss_def() -> Dictionary:
	var d: Dictionary
	if round_no <= BOSSES.size():
		d = BOSSES[round_no - 1].duplicate()
	else:
		# endless: a fresh boss each round from random parts
		var pats := ALL_PATTERNS.duplicate()
		pats.shuffle()
		var tint := Color.from_hsv(randf(), randf_range(0.25, 0.6), 1.0)
		d = {"name": "%s %s" % [NAME_A.pick_random(), NAME_B.pick_random()], "tpl": SurvivalMob.ORDER.pick_random(),
			"tint": tint, "shot": Color.from_hsv(tint.h, 0.7, 1.0), "patterns": pats.slice(0, 3)}
	d["hp"] = 60.0 * (1.0 + 0.35 * (round_no - 1))
	d["scale"] = 3.0 if d.tpl != "golem" else 2.6
	d["speed"] = 26.0 + 2.0 * mini(round_no, 10)
	if not d.has("minion"):
		d["minion"] = d.tpl
	return d


func _spawn_boss() -> void:
	if state == "over":
		return
	var d := _boss_def()
	boss = SurvivalMob.new()
	add_child(boss)
	var away: Vector2 = (arena.get_center() - player.position).normalized()
	boss.position = clamp_arena(player.position + (away if away != Vector2.ZERO else Vector2.UP) * 150.0)
	boss.setup(self, d.tpl, [] as Array[String], round_no, d)
	mobs.append(boss)
	state = "boss"
	_boss_name.text = "💀 %s" % d.name
	_boss_panel.visible = true
	banner(d.name, Color(1.0, 0.5, 0.4))
	sfx.play("boss", 0.0)
	shake()


func _random_mutations() -> Array[String]:
	var out: Array[String] = []
	var chance := minf(0.15 + 0.07 * round_no, 0.7)
	if randf() < chance:
		out.append(SurvivalMob.MUTATIONS.pick_random())
		if round_no >= 5 and randf() < chance * 0.4:
			var m2: String = SurvivalMob.MUTATIONS.pick_random()
			if not (m2 in out) and not (m2 == "Tiny" and "Giant" in out) and not (m2 == "Giant" and "Tiny" in out):
				out.append(m2)
	return out


func portal(tname: String, at: Vector2, muts: Array[String]) -> void:
	portals_open += 1
	var p := _Portal.new()
	p.position = at
	p.z_index = int(at.y / 2.0)
	add_child(p)
	sfx.play("portal", 0.15)
	await get_tree().create_timer(0.7, false).timeout
	p.queue_free()
	portals_open -= 1
	if state == "over":
		return
	var m := SurvivalMob.new()
	add_child(m)
	m.position = at
	m.setup(self, tname, muts, round_no)
	mobs.append(m)


func clone_of(b: SurvivalMob) -> void:
	var m := SurvivalMob.new()
	add_child(m)
	m.position = near(b.position, 40.0, 80.0)
	m.setup(self, b.type_name, [] as Array[String], round_no)
	m.kind = m.kind.duplicate()
	m.kind.ai = "archer"
	m.is_clone = true
	m.hp = 4.0
	m.max_hp = 4.0
	m.scale_k = 2.2
	m.spr.scale = Vector2.ONE * 2.2
	m.tint = b.tint * Color(1, 1, 1, 0.8)
	mobs.append(m)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if state == "intro" or state == "over":
		return
	_t += delta
	_invuln -= delta
	_fire_t -= delta
	_dash_t -= delta
	_slow_t -= delta
	var sp: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	sp.self_modulate.a = 0.35 if (_invuln > 0.0 and int(_t * 14.0) % 2 == 0) else 1.0
	var slow := 0.5 if _slow_t > 0.0 else 1.0
	player.speed = _base_speed * stats.speed * slow
	player.sprint_speed = _base_sprint * stats.speed * slow

	# spawning
	if state == "waves":
		if to_spawn > 0:
			_spawn_t -= delta
			if _spawn_t <= 0.0:
				_spawn_t = maxf(0.35, 1.5 - round_no * 0.08)
				var pool: Array = SurvivalMob.ORDER.slice(0, mini(10, 2 + round_no))
				var tname: String = pool.pick_random()
				var at := _spawn_point()
				var n := 3 if tname == "wolf" else 1
				for k in mini(n, to_spawn):
					portal(tname, near(at, 0.0, 24.0), _random_mutations())
					to_spawn -= 1
		elif mobs.is_empty() and portals_open == 0:
			state = "boss_wait"
			banner("A boss approaches…", Color(1.0, 0.55, 0.45))
			get_tree().create_timer(2.0, false).timeout.connect(_spawn_boss)

	_player_combat(delta)
	var pp := ppos()
	for m in mobs.duplicate():
		if is_instance_valid(m) and not m.dead:
			m.tick(delta, pp)
	_separate()
	_update_shots(delta, pp)
	_update_fires(delta, pp)
	# contact damage
	for m in mobs:
		if is_instance_valid(m) and not m.dead and not m.untouchable() and m.center().distance_to(pp) < m.radius + 7.0:
			if hurt_player(m.dmg) and "Vampiric" in m.mutations:
				m.hp = minf(m.max_hp, m.hp + m.max_hp * 0.25)
	# lava under the player
	var cell := tilemap.local_to_map(player.position + Vector2(0, 14))
	if tilemap.get_cell_atlas_coords(cell) == LAVA and not player.airborne:
		hurt_player(1)
	_update_hud()


func _spawn_point() -> Vector2:
	for k in 20:
		var p := Vector2(randf_range(arena.position.x, arena.end.x), randf_range(arena.position.y, arena.end.y))
		if p.distance_to(player.position) > 130.0:
			return p
	return near_player(130.0, 160.0)


func _player_combat(_delta: float) -> void:
	if Global.input_locked:
		return
	var aim := Vector2.ZERO
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		aim = (get_local_mouse_position() - ppos()).normalized()
	elif Input.is_key_pressed(KEY_J):
		aim = player.last_dir
	elif _bot and not mobs.is_empty():
		var best: SurvivalMob = null
		for m in mobs:
			if is_instance_valid(m) and not m.dead and (best == null or m.position.distance_squared_to(player.position) < best.position.distance_squared_to(player.position)):
				best = m
		if best:
			aim = (best.center() - ppos()).normalized()
	if aim != Vector2.ZERO and player.velocity.length() < 5.0:
		player.last_dir = aim   # stand and face where you're shooting
	if aim != Vector2.ZERO and _fire_t <= 0.0:
		_fire_t = stats.fire_cd
		sfx.play("shoot")
		var fl := _Boom.new()
		fl.radius = 6.0
		fl.position = ppos() + aim * 9.0
		fl.z_index = 4050
		add_child(fl)
		var n: int = stats.multishot
		for i in n:
			var s := shoot(ppos() + aim * 8.0, aim.rotated((i - (n - 1) / 2.0) * 0.16) * stats.bolt_speed, stats.dmg, Color.CYAN, false)
			s.pierce = stats.pierce
			s.r = 3.0 * stats.size
			s.life = 1.6
	var dash_now := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_K)
	if dash_now and not _dash_was and _dash_t <= 0.0:
		_dash()
	_dash_was = dash_now


func _dash() -> void:
	sfx.play("dash")
	_dash_t = stats.dash_cd
	_invuln = maxf(_invuln, 0.35)
	var dir: Vector2 = player.velocity.normalized() if player.velocity.length() > 5.0 else player.last_dir
	var target := clamp_arena(player.position + dir * 70.0)
	var sp: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	for k in 3:   # afterimages
		var g := Sprite2D.new()
		g.texture = sp.sprite_frames.get_frame_texture(sp.animation, sp.frame)
		g.scale = sp.scale
		g.position = player.position.lerp(target, k / 3.0) + sp.position
		g.modulate = Color(0.5, 0.9, 1.0, 0.55)
		g.z_index = player.z_index - 1
		add_child(g)
		create_tween().tween_property(g, "modulate:a", 0.0, 0.3).finished.connect(g.queue_free)
	create_tween().tween_property(player, "position", target, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _separate() -> void:
	for i in mobs.size():
		var a := mobs[i]
		for j in range(i + 1, mobs.size()):
			var b := mobs[j]
			var d := a.position - b.position
			var min_d := (a.radius + b.radius) * 0.8
			if d.length_squared() < min_d * min_d and d.length_squared() > 0.01:
				var push := d.normalized() * (min_d - d.length()) * 0.5
				if not a.is_boss: a.position += push
				if not b.is_boss: b.position -= push


func _update_shots(delta: float, pp: Vector2) -> void:
	for s in shots.duplicate():
		if s.homing > 0.0:
			s.vel = s.vel.rotated(clampf(s.vel.angle_to(pp - s.position), -s.homing * delta, s.homing * delta))
		s.position += s.vel * delta
		s.life -= delta
		var gone: bool = s.life <= 0.0 or not arena.grow(40.0).has_point(s.position)
		if not gone and s.hostile:
			if s.position.distance_to(pp) < s.r + 7.0 and _invuln <= 0.0:
				if s.slows:
					_slow_t = 2.0
					banner_small("Webbed!")
					_invuln = 0.3
				else:
					hurt_player(int(s.dmg))
				gone = true
		elif not gone:
			for m in mobs.duplicate():   # a hit can kill (and free) mobs mid-loop
				if not is_instance_valid(m) or m.dead or m.untouchable() or m in s.hit_ids:
					continue
				if s.position.distance_to(m.center()) < s.r + m.radius:
					m.hit(s.dmg, s.vel.normalized())
					s.hit_ids.append(m)
					if s.pierce <= 0:
						gone = true
						break
					s.pierce -= 1
		if gone:
			shots.erase(s)
			s.queue_free()


func _update_fires(delta: float, pp: Vector2) -> void:
	for f in fires.duplicate():
		f[1] -= delta
		f[0].modulate.a = clampf(f[1], 0.0, 1.0)
		if f[1] <= 0.0:
			fires.erase(f)
			f[0].queue_free()
		elif f[0].position.distance_to(pp + Vector2(0, 8)) < 10.0:
			hurt_player(1)


# ------------------------------------------------------------------ helpers used by mobs
func shoot(at: Vector2, vel: Vector2, dmg: float, col: Color, hostile := true) -> SurvivalShot:
	var s := SurvivalShot.new()
	s.position = at
	s.vel = vel
	s.dmg = dmg
	s.color = col
	s.hostile = hostile
	s.z_index = 4000
	add_child(s)
	shots.append(s)
	return s


func fan(at: Vector2, dir: Vector2, n: int, step: float, spd: float, dmg: float, col: Color) -> void:
	for i in n:
		shoot(at, dir.rotated((i - (n - 1) / 2.0) * step) * spd, dmg, col)


func ring(at: Vector2, n: int, spd: float, dmg: float, col: Color) -> void:
	var off := randf() * TAU
	for i in n:
		shoot(at, Vector2.RIGHT.rotated(off + TAU * i / n) * spd, dmg, col)


func fire(at: Vector2) -> void:
	var f := _Fire.new()
	f.position = at
	f.z_index = int(at.y / 2.0) - 1
	add_child(f)
	fires.append([f, 3.5])


func explode(at: Vector2, radius: float, dmg: int, hurts_player: bool, hurts_mobs: bool, source: Node = null) -> void:
	var b := _Boom.new()
	b.position = at
	b.radius = radius
	b.z_index = 4050
	add_child(b)
	sfx.play("boom")
	shake()
	if hurts_player and ppos().distance_to(at) < radius:
		hurt_player(dmg)
	if hurts_mobs:
		for m in mobs.duplicate():
			if m != source and not m.dead and m.center().distance_to(at) < radius:
				m.hit(2.0, (m.position - at).normalized())


func floater(at: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.scale = Vector2(0.5, 0.5)
	l.position = at + Vector2(randf_range(-6, 2), -6)
	l.z_index = 4095
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


func shake() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake()


func hurt_player(dmg: int) -> bool:
	if _invuln > 0.0 or state == "over" or dmg <= 0 or _god:
		return false
	_invuln = 1.0
	hearts.damage(dmg)
	sfx.play("hurt")
	_hurt_flash.color.a = 0.35
	create_tween().tween_property(_hurt_flash, "color:a", 0.0, 0.35)
	var away: Vector2 = Vector2.ZERO
	for m in mobs:   # pushed back from the nearest attacker
		if is_instance_valid(m) and (away == Vector2.ZERO or m.position.distance_to(player.position) < away.length()):
			away = player.position - m.position
	if away != Vector2.ZERO:
		create_tween().tween_property(player, "position", clamp_arena(player.position + away.normalized() * 14.0), 0.08)
	return true


func mob_died(m: SurvivalMob, give_points := true) -> void:
	mobs.erase(m)
	_puff(m.center(), m.tint if m.tint != Color.WHITE else Color(0.9, 0.9, 0.9), m.scale_k)
	sfx.play("kill" if not m.is_boss else "boom")
	if give_points and not m.is_clone:
		kills += 1
		score += int((m.kind.pts if not m.is_boss else 250) * (1.0 + 0.1 * round_no))
		if stats.lifesteal > 0 and kills % int(20 / stats.lifesteal) == 0:
			hearts.heal(1)
	if "Explosive" in m.mutations:
		explode(m.position, 38.0, 1, true, false, m)
	if "Splitting" in m.mutations or (m.type_name == "slime" and not m.is_boss and m.scale_k > 1.3):
		for k in 2:
			var c := SurvivalMob.new()
			add_child(c)
			c.position = near(m.position, 6.0, 14.0)
			c.setup(self, m.type_name, [] as Array[String], round_no)
			c.hp = maxf(1.0, m.max_hp * 0.35)
			c.max_hp = c.hp
			c.scale_k = m.scale_k * 0.65
			c.radius = m.radius * 0.65
			c.spr.scale = Vector2.ONE * c.scale_k
			mobs.append(c)
	if randf() < 0.06 and not m.is_clone:
		_heart_drop(m.position)
	m.queue_free()
	if m == boss:
		boss = null
		_boss_panel.visible = false
		for o in mobs.duplicate():   # the boss's minions vanish with it
			_puff(o.center(), Color(0.8, 0.8, 1.0), o.scale_k)
			o.queue_free()
		mobs.clear()
		for s in shots.duplicate():
			if s.hostile:
				shots.erase(s); s.queue_free()
		_heart_drop(m.position)
		state = "upgrade"
		banner("Round %d cleared!" % round_no, Color(0.5, 1.0, 0.6))
		get_tree().create_timer(1.6, false).timeout.connect(_show_upgrades)


func _puff(at: Vector2, col: Color, k: float) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.z_index = 4060
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(10 * k)
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0 * k
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = col
	p.emitting = true
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _heart_drop(at: Vector2) -> void:
	var h := _Heart.new()
	h.position = at
	h.game = self
	h.z_index = int(at.y / 2.0)
	add_child(h)


# ------------------------------------------------------------------ upgrades / end
func _show_upgrades() -> void:
	if state == "over":
		return
	get_tree().paused = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var v := PixelUI.page(layer, "⚔ Choose an upgrade", 760, func(): pass)
	(v.get_child(0) as HBoxContainer).get_child(1).visible = false   # no close: you always pick one
	sfx.play("upgrade", 0.0)
	v.add_child(PixelUI.label("Round %d cleared · Score %d" % [round_no, score], 26, PixelUI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var picks := range(UPGRADES.size())
	picks.shuffle()
	for i in picks.slice(0, 3):
		var u: Array = UPGRADES[i]
		var b := PixelUI.button("%s\n%s" % [u[0], u[1]], func():
			_apply_upgrade(i)
			get_tree().paused = false
			layer.queue_free()
			_next_round(), i == picks[0])
		b.custom_minimum_size = Vector2(220, 120)
		if _bot and i == picks[0]:
			get_tree().create_timer(1.0, true).timeout.connect(b.emit_signal.bind("pressed"))
		b.add_theme_font_size_override("font_size", 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


func _apply_upgrade(i: int) -> void:
	match i:
		0: stats.dmg += 1.0
		1: stats.fire_cd *= 0.8
		2: stats.multishot += 1
		3: stats.pierce += 1
		4: stats.speed *= 1.15
		5: stats.dash_cd *= 0.7
		6: stats.size *= 1.35; stats.dmg *= 1.25
		7: hearts.heal(3)
		8: stats.lifesteal += 1


func _on_died() -> void:
	if state == "over":
		return
	state = "over"
	var best_round := int(Global.stats.get("survival_best_round", 0))
	var best_score := int(Global.stats.get("survival_best_score", 0))
	var new_best := round_no > best_round or score > best_score
	Global.stats["survival_best_round"] = maxi(best_round, round_no)
	Global.stats["survival_best_score"] = maxi(best_score, score)
	Global.save_game()
	RoundCard.show_card(self, "You fell in round %d" % round_no,
		"Score %d   ·   Kills %d\n%s" % [score, kills, "[color=#ffd166]New best![/color]" if new_best else "Best: round %d · %d pts" % [best_round, best_score]],
		[["Try again", func(): get_tree().reload_current_scene()],
		 ["Home", func(): get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn")]], true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and state != "over" and not get_tree().paused:
		get_viewport().set_input_as_handled()
		RoundCard.show_card(self, "Paused",
			"Mouse / J shoot · Right-click / K dash\nSpace jump · Shift sprint",
			[["Resume", func(): pass], ["Quit", func(): get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn")]], true)


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var info := PixelUI.panel(PixelUI.FRAME, 16, 6)
	info.position = Vector2(16, 14)
	hud.add_child(info)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	info.add_child(col)
	_round_lbl = PixelUI.label("", 30, PixelUI.GOLD, false)
	_score_lbl = PixelUI.label("", 22, PixelUI.CREAM, false)
	_weapon_lbl = PixelUI.label("", 20, PixelUI.MUTED, false)
	col.add_child(_round_lbl)
	col.add_child(_score_lbl)
	col.add_child(_weapon_lbl)
	var dash_bg := ColorRect.new()
	dash_bg.color = Color(0.1, 0.12, 0.2)
	dash_bg.custom_minimum_size = Vector2(160, 6)
	col.add_child(dash_bg)
	_dash_fill = ColorRect.new()
	_dash_fill.color = Color(0.45, 0.9, 1.0)
	_dash_fill.size = Vector2(160, 6)
	dash_bg.add_child(_dash_fill)

	_hurt_flash = ColorRect.new()
	_hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_flash.color = Color(0.85, 0.05, 0.1, 0.0)
	hud.add_child(_hurt_flash)
	hud.move_child(_hurt_flash, 0)

	_boss_panel = PixelUI.panel(PixelUI.FRAME, 18, 8)
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_panel.offset_top = 14
	_boss_panel.visible = false
	hud.add_child(_boss_panel)
	var bv := VBoxContainer.new()
	_boss_panel.add_child(bv)
	_boss_name = PixelUI.label("", 30, Color(1.0, 0.55, 0.45))
	bv.add_child(_boss_name)
	var bar := ColorRect.new()
	bar.color = Color(0.12, 0.05, 0.08)
	bar.custom_minimum_size = Vector2(520, 16)
	bv.add_child(bar)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.86, 0.18, 0.22)
	_boss_fill.size = Vector2(520, 16)
	bar.add_child(_boss_fill)

	_banner = PixelUI.label("", 58, PixelUI.GOLD)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = -150
	_banner.offset_bottom = -80
	_banner.modulate.a = 0.0
	hud.add_child(_banner)

	var keys := PixelUI.label("Shoot: mouse / J   ·   Dash: right-click / K   ·   Esc pause", 18, Color(PixelUI.MUTED, 0.75))
	keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	keys.offset_left = -400
	keys.offset_right = 400
	keys.offset_top = -30
	hud.add_child(keys)


func _update_hud() -> void:
	_round_lbl.text = "⚔ Round %d" % round_no
	var left := mobs.size() + to_spawn + portals_open
	_score_lbl.text = "Score %d · Kills %d%s" % [score, kills, ("   ·   %d left" % left) if state == "waves" else ""]
	_weapon_lbl.text = "DMG %s · %.1f/s · x%d%s" % [str(snappedf(stats.dmg, 0.1)).trim_suffix(".0"), 1.0 / stats.fire_cd,
		stats.multishot, (" · pierce %d" % stats.pierce) if stats.pierce > 0 else ""]
	_dash_fill.size.x = 160.0 * clampf(1.0 - _dash_t / stats.dash_cd, 0.0, 1.0)
	_dash_fill.color = Color(0.45, 0.9, 1.0) if _dash_t <= 0.0 else Color(0.3, 0.45, 0.6)
	if boss and is_instance_valid(boss):
		_boss_fill.size.x = 520.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0)
		_boss_fill.color = Color(1.0, 0.45, 0.15) if boss.enraged else Color(0.86, 0.18, 0.22)


func banner(text: String, col: Color) -> void:
	print("[Survival] ", text, "   (score %d, kills %d)" % [score, kills])
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func banner_small(text: String) -> void:
	floater(ppos() + Vector2(0, -20), text, Color(0.9, 0.9, 1.0))


# ------------------------------------------------------------------ little FX nodes
class _Portal extends Node2D:
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var k := clampf(_t / 0.7, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 4.0 + 10.0 * k, Color(0.25, 0.05, 0.35, 0.8))
		draw_arc(Vector2.ZERO, 4.0 + 12.0 * k, _t * 6.0, _t * 6.0 + 4.0, 16, Color(0.8, 0.4, 1.0), 2.0)


class _Boom extends Node2D:
	var radius := 40.0
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.35:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := _t / 0.35
		draw_circle(Vector2.ZERO, radius * k, Color(1.0, 0.6, 0.2, 0.45 * (1.0 - k)))
		draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, 1.0 - k), 2.0)


class _Fire extends Node2D:
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var t := Time.get_ticks_msec() * 0.01
		for i in 5:
			var p := Vector2(sin(t + i * 1.7) * 4.0, -absf(sin(t * 1.3 + i)) * 5.0)
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.5 + 0.1 * i, 0.1, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.4, 0.1, 0.35))


class _Heart extends Node2D:
	var game: Node
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		position.y += sin(_t * 4.0) * 0.1
		queue_redraw()
		if _t > 10.0:
			queue_free()
		elif game.ppos().distance_to(position) < 12.0:
			game.hearts.heal(1)
			game.sfx.play("pickup", 0.0)
			game.floater(position, "+1 heart", Color(1.0, 0.5, 0.6))
			queue_free()
	func _draw() -> void:
		var c := Color(0.95, 0.25, 0.35)
		draw_circle(Vector2(-2, -1), 2.5, c)
		draw_circle(Vector2(2, -1), 2.5, c)
		draw_colored_polygon(PackedVector2Array([Vector2(-4.5, 0), Vector2(4.5, 0), Vector2(0, 5)]), c)
