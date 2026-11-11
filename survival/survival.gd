extends Node2D
class_name SurvivalGame

# Survival mode: a separate arcade game reached from the Stats page (🐛 button).
# A random island (beaches, ponds, lava). Waves of mobs (12 types, random mutations)
# pour out of portals; clear them and a boss arrives (12 named bosses, then endless
# generated ones). Beat it, pick a perk, spend coins in the Armory on new weapons and
# weapon levels (saved between runs), next round. Pure GDScript, no AI server.

const TILESET := preload("res://resources/tile_set.tres")
const PLAYER_SCENE := preload("res://player/player.tscn")
const POST_SHADER := preload("res://shaders/post_fx.gdshader")
const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")
const W := 62                  # island bounding box (cells)
const H := 44
const M := 8                   # open water around it (cells)
const TILE := 16.0
const GRASS := Vector2i(0, 0)
const DIRT := Vector2i(1, 0)
const SAND := Vector2i(0, 1)
const LAVA := Vector2i(1, 1)
const WATER := Vector2i(3, 1)

const BOSSES := [
	{"name": "Slime King", "tpl": "slime", "sprite": "slime_king", "tint": Color(0.5, 0.75, 1.0), "shot": Color(0.5, 0.8, 1.0), "patterns": ["slam", "summon", "ring"]},
	{"name": "The Watcher", "tpl": "eye", "tint": Color(1.0, 0.85, 0.85), "shot": Color(1.0, 0.35, 0.4), "patterns": ["aimed", "charge", "summon"]},
	{"name": "Bone Lord", "tpl": "skeleton", "tint": Color(1.0, 0.95, 0.85), "shot": Color(0.95, 0.92, 0.8), "patterns": ["ring", "aimed", "spiral"]},
	{"name": "Ember Golem", "tpl": "golem", "tint": Color(1.0, 0.6, 0.35), "shot": Color(1.0, 0.5, 0.15), "patterns": ["charge", "trail", "ring"], "minion": "zombie"},
	{"name": "Wraith Queen", "tpl": "ghost", "tint": Color(0.75, 0.75, 1.0), "shot": Color(0.7, 0.6, 1.0), "patterns": ["teleport", "spiral", "summon"]},
	{"name": "Brood Mother", "tpl": "spider", "tint": Color(1.0, 0.75, 0.8), "shot": Color(0.9, 0.3, 0.4), "patterns": ["web", "summon", "charge"]},
	{"name": "Hive Queen", "tpl": "hornet", "tint": Color(1.0, 0.85, 0.6), "shot": Color(1.0, 0.85, 0.2), "patterns": ["spread", "summon", "homing"]},
	{"name": "Storm Bat", "tpl": "bat", "tint": Color(0.7, 0.85, 1.0), "shot": Color(0.6, 0.85, 1.0), "patterns": ["charge", "aimed", "spread"]},
	{"name": "Necromancer", "tpl": "mage", "tint": Color(0.55, 0.45, 0.6), "shot": Color(0.6, 1.0, 0.6), "patterns": ["summon", "homing", "teleport"], "minion": "zombie"},
	{"name": "Dire Alpha", "tpl": "wolf", "tint": Color(0.9, 0.8, 0.7), "shot": Color(1.0, 0.8, 0.4), "patterns": ["charge", "summon", "spread"]},
	{"name": "Frost Titan", "tpl": "golem", "tint": Color(0.65, 0.85, 1.0), "shot": Color(0.7, 0.95, 1.0), "patterns": ["spread", "slam", "ring"], "minion": "bat"},
	{"name": "Hollow Twin", "tpl": "zombie", "tint": Color(0.75, 0.55, 1.0), "shot": Color(0.8, 0.5, 1.0), "patterns": ["clones", "spiral", "homing"]},
]
const ALL_PATTERNS := ["ring", "spread", "spiral", "aimed", "charge", "slam", "summon", "teleport", "trail", "web", "homing", "clones"]
const NAME_A := ["Ancient", "Cursed", "Feral", "Molten", "Hollow", "Rotten", "Thunder", "Frozen", "Shadow", "Iron", "Venom", "Crystal"]
const NAME_B := ["Behemoth", "Warden", "Tyrant", "Horror", "Matriarch", "Colossus", "Reaper", "Sovereign", "Devourer", "Lich", "Juggernaut", "Wyrm"]
# Perks: pick 1 of 3 after every boss (this run only). They boost every weapon.
const UPGRADES := [
	["Sharper magic", "+25% damage"], ["Rapid fire", "Attack 20% faster"], ["Multishot", "+1 projectile"],
	["Piercing", "Shots pass through\n+1 enemy"], ["Swift feet", "+15% move speed"], ["Quick dash", "Dash cooldown -30%"],
	["Big shots", "Bigger shots,\n+20% damage"], ["Second wind", "Heal 3 hearts"], ["Vampire fang", "Heal 1 heart\nevery 20 kills"],
	["Lucky star", "+10% critical hits\n(double damage)"], ["Coin magnet", "Pick up coins\nfrom further away"], ["Iron heart", "+1 max heart"],
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
var stats := {"dmg": 1.0, "fire_rate": 1.0, "multishot": 1, "pierce": 0,
	"size": 1.0, "dash_cd": 1.3, "speed": 1.0, "lifesteal": 0, "crit": 0.08, "magnet": 34.0}
var walk := {}                          # Vector2i cell -> true for land you can stand on
var walk_cells: Array[Vector2i] = []
var weapons: Array = ["bolt"]           # owned weapon ids (from the Armory)
var weapon_i := 0
var run_coins := 0                      # coins picked up this run (already banked)
var aim_dir := Vector2.RIGHT            # last aim, for the reticle
var _aim_touch := -1                    # phones: finger on the aim stick (right half)
var _aim_origin := Vector2.ZERO
var _aim_vec := Vector2.ZERO
var _aim_view: Control
var _reticle: Node2D
var _coin_lbl: Label
var _arm_list: VBoxContainer
# co-op (Net room in "survival" mode): see survival_net.gd
var net: SurvivalNet
var down := false                     # co-op: knocked out until the next round
var local_ready := false              # co-op: finished picking perk + armory this break
var _upgrade_wait := 0.0
var _net_shots: Array = []            # host: hostile shots to send this frame
# day / night: one full day every DAY_LEN seconds
const DAY_LEN := 210.0
var _day_t := 0.25 * DAY_LEN          # start in the morning
var _night_mod: CanvasModulate
var _torch: HandTorch
var _lava_lights: Array[PointLight2D] = []
var _post: ShaderMaterial
var dark := 0.0                       # 0 noon … 1 midnight
var _was_night := false
static var UNSHADED := _unshaded_mat()

static func _unshaded_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # glows: not darkened at night
	return m
var _arm_coins: Label
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
var _fire_t_max := 0.3
var _god := "--surv-god" in OS.get_cmdline_user_args()
var _touch_dash := false   # DASH button tapped (phones)
var touch: TouchControls

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
	if Net.in_survival():   # co-op: everybody builds the same island from the host's seed
		seed(int(Net.round_data.get("seed", 1)))
	_build_arena()
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = _island_center()
	if Net.in_survival():
		player.position += Vector2(((Net.my_id - 1) % 5) * 24 - 48, ((Net.my_id - 1) / 5) * 24)
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
	weapons = SurvivalArsenal.owned()
	_build_hud()
	if Net.in_survival():
		seed(int(Net.round_data.get("seed", 1)) + 7)
	_decorate_arena()
	randomize()
	_build_daynight()
	_reticle = _Reticle.new()
	_reticle.game = self
	_reticle.z_index = 4090
	_reticle.material = UNSHADED
	add_child(_reticle)
	if Screen.is_touch:
		_build_touch()
	else:
		_set_crosshair()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--surv-round="):
			round_no = int(a.get_slice("=", 1)) - 1
	if Net.in_survival():
		net = SurvivalNet.new()
		add_child(net)
		net.setup(self)
		if net.is_host:
			banner("Co-op: get ready!", PixelUI.GOLD)
			await get_tree().create_timer(3.0).timeout
			_next_round()
		else:
			state = "waves"
			banner("Co-op: the host starts the waves", PixelUI.GOLD, false)
	elif _bot:
		await get_tree().create_timer(0.8).timeout
		_next_round()
	else:
		_show_intro()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)   # give the rest of the game its normal cursor back
	Global.save_game()                    # coins picked up are kept even if you quit


# Phones: twin-stick. Left joystick moves; drag anywhere on the right half to aim and fire
# (let go and it auto-aims at the nearest monster). DASH, JUMP, weapon swap and pause buttons.
func _build_touch() -> void:
	var joy: CanvasLayer = load("res://ui/gameplay/joy_stick_ui.tscn").instantiate()
	add_child(joy)
	(joy.get_node("VirtualJoystick") as Control).modulate.a = 0.6
	touch = TouchControls.new()
	add_child(touch)
	touch.show_when = func() -> bool:
		return state != "over" and get_tree().get_nodes_in_group("modal").is_empty()
	touch.add("pause", "II", Vector2(1, 0), Vector2(-14, 86), 60, "", func():
		if state != "over" and not get_tree().paused:
			_open_pause(), false)
	touch.add("jump", "icon:jump", Vector2(1, 1), Vector2(-22, -40), 96, "jump")
	touch.add("dash", "DASH", Vector2(1, 1), Vector2(-134, -150), 96, "", func(): _touch_dash = true)
	touch.add("weapon", "⇄", Vector2(1, 1), Vector2(-22, -150), 72, "", func(): _cycle_weapon(1))
	var lay := CanvasLayer.new()
	lay.layer = 24
	add_child(lay)
	_aim_view = _AimStickView.new()
	_aim_view.game = self
	_aim_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aim_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(_aim_view)


func _input(event: InputEvent) -> void:
	if not Screen.is_touch or state in ["intro", "over"] or get_tree().paused:
		return
	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and _aim_touch == -1 and event.position.x > vp.x * 0.45 \
				and not (touch and touch.hit_test(event.position)):
			_aim_touch = event.index
			_aim_origin = event.position
			_aim_vec = Vector2.ZERO
		elif not event.pressed and event.index == _aim_touch:
			_aim_touch = -1
			_aim_vec = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == _aim_touch:
		_aim_vec = event.position - _aim_origin
		if _aim_vec.length() > 70.0:   # the stick follows a finger that wanders off
			_aim_origin = event.position - _aim_vec.limit_length(70.0)
			_aim_vec = event.position - _aim_origin


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


# Flowers and grass tufts on the island, trees around the shore and by the ponds.
func _decorate_arena() -> void:
	var flowers := ["res://assets/flowers/cherry_sapling.png", "res://assets/flowers/coral_fan_red.png",
		"res://assets/flowers/crimson_fungus.png"]
	for f in ResourceLoader.list_directory("res://assets/flowers"):   # works in exported builds too
		if f.ends_with(".png") and flowers.size() < 12:
			flowers.append("res://assets/flowers/" + f)
	for k in 70:
		var c: Vector2i = walk_cells.pick_random()
		if tilemap.get_cell_atlas_coords(c) != GRASS:
			continue
		var s := Sprite2D.new()
		s.texture = load(flowers.pick_random())
		s.position = (Vector2(c) + Vector2(randf(), randf())) * TILE
		s.offset = Vector2(0, -8)
		s.scale = Vector2.ONE * randf_range(0.7, 1.0)
		s.z_index = int(s.position.y / 2.0) - 2
		add_child(s)
	var trees := ["res://assets/trees/birch_1.png", "res://assets/trees/fir_tree_2.png", "res://assets/trees/jungle_tree_3.png",
		"res://assets/trees/middle_lane_tree2.png", "res://assets/trees/birch_3.png", "res://assets/trees/fir_tree_1.png"]
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < 26 and tries < 600:
		tries += 1
		var c: Vector2i = walk_cells.pick_random()
		if not _near_water(c, 2) or Vector2(c).distance_to(Vector2(_island_center() / TILE)) < 10.0:
			continue
		var at := (Vector2(c) + Vector2(0.5, 0.9)) * TILE
		if placed.any(func(q): return q.distance_to(at) < 40.0):
			continue
		placed.append(at)
		var t := Sprite2D.new()
		t.texture = load(trees.pick_random())
		t.centered = false
		t.offset = Vector2(-t.texture.get_width() / 2.0, -t.texture.get_height() + 10)
		t.scale = Vector2(0.5, 0.5)
		t.position = at
		t.z_index = int(t.position.y / 2.0)
		add_child(t)


func _near_water(c: Vector2i, r: int) -> bool:
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if not walk.has(c + Vector2i(x, y)) and tilemap.get_cell_atlas_coords(c + Vector2i(x, y)) == WATER:
				return true
	return false


# First thing a player sees: what to do and how.
func _show_intro() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var v := PixelUI.page(layer, "💀 Survival", 640, func():
		get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn"))
	var best := int(Global.stats.get("survival_best_round", 0))
	var intro := PixelUI.label("Clear each wave, then defeat the boss. Monsters drop coins:\nspend them in the Armory on new weapons and weapon levels (kept between runs).", 24)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = minf(580.0, PixelUI.avail_width(60.0))
	v.add_child(intro)
	var keys := GridContainer.new()
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 24)
	v.add_child(keys)
	var rows := [["Aim + shoot", "mouse (hold left button)  /  J"], ["Weapons", "Q / E, 1-6 or mouse wheel"],
			["Dash", "right mouse  /  K"], ["Move", "WASD  ·  Shift sprint  ·  Space jump"], ["Pause", "Esc"]]
	if Screen.is_touch:
		rows = [["Move", "left joystick (push far to sprint)"], ["Aim + shoot", "drag on the right side"],
			["Auto-aim", "let go: fires at the nearest monster"], ["Weapons", "⇄ button"], ["Dash / jump", "DASH and ↑ buttons"]]
	for row in rows:
		keys.add_child(PixelUI.label(row[0], 26, PixelUI.GOLD, false))
		keys.add_child(PixelUI.label(row[1], 26, PixelUI.CREAM, false))
	if best > 0:
		v.add_child(PixelUI.label("Your best: round %d" % best, 24, PixelUI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var shop := PixelUI.button("🛒 Armory  ·  🪙 %d" % SurvivalArsenal.coins(), func():
		layer.queue_free()
		_show_armory(func(): _show_intro()))
	shop.custom_minimum_size = Vector2(0, 60)
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(shop)
	var coop := PixelUI.button("👥 Co-op", func():
		layer.queue_free()
		get_tree().paused = false   # the lobby needs the game running to take input
		Lobby.open(self, func(): return "", "survival", func(): _show_intro()))
	coop.custom_minimum_size = Vector2(0, 60)
	coop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coop.tooltip_text = "Play with friends: create a room or join with a code / invite link"
	row.add_child(coop)
	var go := PixelUI.button("Fight!", func():
		get_tree().paused = false
		layer.queue_free()
		_next_round(), true)
	go.custom_minimum_size = Vector2(0, 60)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	get_tree().paused = true


# ------------------------------------------------------------------ arena
func _build_arena() -> void:
	tilemap = TileMapLayer.new()
	tilemap.tile_set = TILESET
	add_child(tilemap)
	var shape := FastNoiseLite.new()   # coastline wobble: bays and peninsulas
	shape.seed = randi()
	shape.frequency = 0.07
	var ground := FastNoiseLite.new()  # dirt patches
	ground.seed = randi()
	ground.frequency = 0.12
	var c := Vector2(M + W / 2.0, M + H / 2.0)
	walk.clear()
	walk_cells.clear()
	for x in W + 2 * M:
		for y in H + 2 * M:
			var e := Vector2((x + 0.5 - c.x) / (W / 2.0), (y + 0.5 - c.y) / (H / 2.0)).length_squared()
			e += shape.get_noise_2d(x, y) * 0.55
			var t := WATER
			if e < 1.0:
				t = SAND if e > 0.84 else (DIRT if ground.get_noise_2d(x, y) > 0.38 else GRASS)
			tilemap.set_cell(Vector2i(x, y), 0, t)
	# ponds and lava pools away from the middle (where you start)
	for k in 7:
		var p := Vector2(randf_range(M + 6, M + W - 7), randf_range(M + 5, M + H - 6))
		if p.distance_to(c) < 10.0 or tilemap.get_cell_atlas_coords(Vector2i(p)) == WATER:
			continue
		var pond := k < 3
		var rad := randf_range(1.8, 3.0) if pond else randf_range(1.3, 2.3)
		for x in range(-4, 5):
			for y in range(-4, 5):
				var cell := Vector2i(p) + Vector2i(x, y)
				if Vector2(x, y * 1.2).length() < rad and tilemap.get_cell_atlas_coords(cell) != WATER:
					tilemap.set_cell(cell, 0, WATER if pond else LAVA)
				elif pond and Vector2(x, y * 1.2).length() < rad + 1.0 and tilemap.get_cell_atlas_coords(cell) in [GRASS, DIRT]:
					tilemap.set_cell(cell, 0, SAND)
	# keep only land connected to the middle (no unreachable islets)
	var start := Vector2i(c)
	var todo: Array[Vector2i] = [start]
	walk[start] = true
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		walk_cells.append(cell)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + d
			if not walk.has(n) and tilemap.get_cell_atlas_coords(n) not in [WATER, Vector2i(-1, -1)]:
				walk[n] = true
				todo.append(n)
	for x in W + 2 * M:
		for y in H + 2 * M:
			var cell := Vector2i(x, y)
			if not walk.has(cell) and tilemap.get_cell_atlas_coords(cell) != WATER:
				tilemap.set_cell(cell, 0, WATER)
	var water := Water.new()
	add_child(water)
	water.setup(tilemap, W + 2 * M, H + 2 * M)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for cell in walk_cells:
		lo = lo.min(Vector2(cell))
		hi = hi.max(Vector2(cell) + Vector2.ONE)
	arena = Rect2(lo * TILE, (hi - lo) * TILE)
	# the player can't walk into water: a small wall block on every shore cell
	var body := StaticBody2D.new()
	add_child(body)
	for x in W + 2 * M:
		for y in H + 2 * M:
			var cell := Vector2i(x, y)
			if walk.has(cell):
				continue
			var shore := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				if walk.has(cell + d):
					shore = true
					break
			if shore:
				var cs := CollisionShape2D.new()
				var sh := RectangleShape2D.new()
				sh.size = Vector2(TILE, TILE)
				cs.shape = sh
				cs.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
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
	_post = mat
	fx.material = mat
	fx.visible = not Screen.low()
	layer.add_child(fx)
	add_child(layer)


# ------------------------------------------------------------------ day / night
# Same idea as the main island: one CanvasModulate darkens the world, lights add it
# back (your torch, glowing lava), shots and blasts stay bright, low sun = light shafts.
func _build_daynight() -> void:
	_night_mod = CanvasModulate.new()
	add_child(_night_mod)
	_torch = HandTorch.new(player.get_node("AnimatedSprite2D"))
	_torch.max_energy = 0.9
	player.add_child(_torch)
	var buckets := {}
	for cell in tilemap.get_used_cells():
		if tilemap.get_cell_atlas_coords(cell) == LAVA:
			var key := Vector2i(cell.x / 5, cell.y / 5)
			if not buckets.has(key):
				buckets[key] = [Vector2.ZERO, 0]
			buckets[key][0] += (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
			buckets[key][1] += 1
	for key in buckets:
		if Screen.low() and _lava_lights.size() >= 3:
			break
		var n: int = buckets[key][1]
		var l := PointLight2D.new()
		l.texture = preload("res://assets/wildlife/light_soft.png")
		l.color = Color(1.0, 0.45, 0.12)
		l.texture_scale = clampf(0.35 + sqrt(n) * 0.16, 0.45, 1.4)
		l.position = buckets[key][0] / n
		l.range_z_min = -4096
		l.range_z_max = 4096
		l.energy = 0.0
		add_child(l)
		_lava_lights.append(l)


func _update_daynight(delta: float) -> void:
	if state != "intro":
		_day_t = fmod(_day_t + delta, DAY_LEN)
	var h := _day_t / DAY_LEN * 24.0                  # 0..24 "hours"
	var day := smoothstep(4.5, 7.5, h) * (1.0 - smoothstep(17.5, 20.5, h))
	dark = 1.0 - day
	var dusk := clampf(1.0 - absf(h - 19.0) / 1.8, 0.0, 1.0) + clampf(1.0 - absf(h - 6.0) / 1.8, 0.0, 1.0)
	var night := Color(0.3, 0.34, 0.58)
	var c := night.lerp(Color.WHITE, day).lerp(Color(1.0, 0.75, 0.55), dusk * 0.45)
	_night_mod.color = c
	_torch.set_lit(dark > 0.4)
	for l in _lava_lights:
		l.energy = lerpf(0.15, 0.9, dark) * (0.9 + 0.1 * sin(_t * 2.0 + l.position.x))
	if _post:
		_post.set_shader_parameter("vignette", lerpf(0.42, 0.62, dark))
		_post.set_shader_parameter("saturation", lerpf(1.12, 0.92, dark))
		_post.set_shader_parameter("sun_rays", dusk * day * 0.9)
		_post.set_shader_parameter("sun_pos", Vector2(1.15 if h < 12.0 else -0.15, -0.2))
	var is_night := dark > 0.6
	if is_night != _was_night and state in ["waves", "boss_wait", "boss"]:
		banner_small("Night falls… light your way" if is_night else "The sun rises")
	_was_night = is_night


func _island_center() -> Vector2:
	return Vector2(M + W / 2.0, M + H / 2.0).floor() * TILE + Vector2(TILE, TILE) * 0.5


func is_walk(p: Vector2) -> bool:
	return walk.has(Vector2i((p / TILE).floor()))


# Nearest spot on land (teleports, knock-backs, spawn spots).
func clamp_arena(p: Vector2) -> Vector2:
	if is_walk(p):
		return p
	var c := Vector2i((p / TILE).floor())
	for r in range(1, 12):
		var best := Vector2.INF
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r or not walk.has(c + Vector2i(x, y)):
					continue
				var q := (Vector2(c + Vector2i(x, y)) + Vector2(0.5, 0.5)) * TILE
				if best == Vector2.INF or q.distance_squared_to(p) < best.distance_squared_to(p):
					best = q
		if best != Vector2.INF:
			return best
	return _island_center()


# Inside the island's bounding box (flyers and bosses may hover over water).
func clamp_box(p: Vector2) -> Vector2:
	return p.clamp(arena.position + Vector2(6, 6), arena.end - Vector2(6, 6))


# Walking movement that slides along the shore instead of entering water.
func move_in(from: Vector2, to: Vector2) -> Vector2:
	if is_walk(to):
		return to
	if is_walk(Vector2(to.x, from.y)):
		return Vector2(to.x, from.y)
	if is_walk(Vector2(from.x, to.y)):
		return Vector2(from.x, to.y)
	return from if is_walk(from) else clamp_arena(from)


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
	_revive()
	local_ready = false
	to_spawn = 0 if "--surv-boss-now" in OS.get_cmdline_user_args() else mini(5 + 2 * round_no, 36)
	_spawn_t = 1.2
	banner("Round %d" % round_no, PixelUI.GOLD)
	sfx.play("portal", 0.0)
	_update_hud()
	if net:
		net.send_state()


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
	d["hp"] = 45.0 * (1.0 + 0.3 * (round_no - 1))   # gentler: weapons level up too
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
	var away: Vector2 = (_island_center() - player.position).normalized()
	boss.position = clamp_arena(player.position + (away if away != Vector2.ZERO else Vector2.UP) * 150.0)
	boss.setup(self, d.tpl, [] as Array[String], round_no, d)
	_add_mob(boss)
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
	_add_mob(m)


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
	m.set_size(2.2)
	m.tint = b.tint * Color(1, 1, 1, 0.8)
	_add_mob(m)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	_update_daynight(delta)
	if state == "intro" or state == "over":
		return
	_t += delta
	_invuln -= delta
	_fire_t -= delta
	_dash_t -= delta
	_slow_t -= delta
	var sp: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	sp.self_modulate.a = 0.35 if (_invuln > 0.0 and int(_t * 14.0) % 2 == 0) else 1.0
	sp.modulate.a = 0.35 if down else 1.0   # co-op: a ghost while knocked out
	var slow := 0.5 if _slow_t > 0.0 else 1.0
	player.speed = _base_speed * stats.speed * slow
	player.sprint_speed = _base_sprint * stats.speed * slow

	var authority := net == null or net.is_host
	if net and net.is_host and state == "upgrade":   # co-op: don't wait forever for a slow picker
		_upgrade_wait += delta
		if _upgrade_wait > 40.0:
			start_next_round_mp()
	# spawning
	if authority and state == "waves":
		if to_spawn > 0:
			_spawn_t -= delta
			if _spawn_t <= 0.0:
				_spawn_t = maxf(0.35, 1.5 - round_no * 0.08)
				var pool: Array = SurvivalMob.ORDER.slice(0, mini(SurvivalMob.ORDER.size(), 2 + round_no))
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
	if authority:
		var targets: Array[Vector2] = []
		if net:
			targets = net.alive_targets()
		for m in mobs.duplicate():
			if is_instance_valid(m) and not m.dead:
				m.tick(delta, _target_for(m, pp, targets))
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
	if not _net_shots.is_empty():   # co-op host: this frame's monster shots in one packet
		var l := []
		for sh in _net_shots:
			if is_instance_valid(sh):
				l.append([snappedf(sh.position.x, 0.1), snappedf(sh.position.y, 0.1), snappedf(sh.vel.x, 0.1), snappedf(sh.vel.y, 0.1),
					sh.dmg, sh.color.to_html(false), sh.r, 1 if sh.slows else 0, sh.homing, snappedf(sh.life, 0.1)])
		net.send({"t": "hsb", "l": l})
		_net_shots = []


# Co-op host: each monster goes for the closest player who is still standing.
func _target_for(m: SurvivalMob, pp: Vector2, targets: Array[Vector2]) -> Vector2:
	if targets.is_empty():
		return pp
	var best: Vector2 = targets[0]
	for q in targets:
		if q.distance_squared_to(m.position) < best.distance_squared_to(m.position):
			best = q
	return best + Vector2(0, -8)


func _add_mob(m: SurvivalMob) -> void:
	mobs.append(m)
	if net and net.is_host:
		net.register(m)


func _spawn_point() -> Vector2:
	for k in 30:
		var c: Vector2i = walk_cells.pick_random()
		var p := (Vector2(c) + Vector2(0.5, 0.5)) * TILE
		var d := p.distance_to(player.position)
		if d > 140.0 and d < 420.0:
			return p
	return near_player(140.0, 200.0)


# ------------------------------------------------------------------ weapons
func weapon_id() -> String:
	return str(weapons[weapon_i % weapons.size()]) if not weapons.is_empty() else "bolt"


func _cycle_weapon(step: int) -> void:
	if weapons.size() < 2:
		banner_small("Buy more weapons in the Armory")
		return
	weapon_i = posmod(weapon_i + step, weapons.size())
	_on_weapon_changed()


func _select_weapon(i: int) -> void:
	if i < weapons.size():
		weapon_i = i
		_on_weapon_changed()


func _on_weapon_changed() -> void:
	var d: Dictionary = SurvivalArsenal.WEAPONS[weapon_id()]
	banner_small("%s %s" % [d.icon, d.name])
	sfx.play("pickup", 0.1)
	_fire_t = minf(_fire_t, 0.15)
	_update_hud()


# Where the player is aiming, or ZERO when not attacking this frame.
func _aim_input() -> Vector2:
	if Screen.is_touch:
		if _aim_touch != -1 and _aim_vec.length() > 14.0:
			return _aim_vec.normalized()
		var best := _nearest_mob(ppos(), 260.0)
		return (best.center() - ppos()).normalized() if best else Vector2.ZERO
	# Every finger is also a "left click" on touch devices, so the mouse is desktop only.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return (get_local_mouse_position() - ppos()).normalized()
	if Input.is_key_pressed(KEY_J):
		return player.last_dir
	if _bot:
		var best := _nearest_mob(ppos(), 400.0)
		return (best.center() - ppos()).normalized() if best else Vector2.ZERO
	return Vector2.ZERO


func _nearest_mob(at: Vector2, max_d: float, skip: Array = []) -> SurvivalMob:
	var best: SurvivalMob = null
	var bd := max_d * max_d
	for m in mobs:
		if is_instance_valid(m) and not m.dead and not m.untouchable() and not (m in skip):
			var d2 := m.center().distance_squared_to(at)
			if d2 < bd:
				bd = d2
				best = m
	return best


func _player_combat(_delta: float) -> void:
	if Global.input_locked or down:
		return
	var aim := _aim_input()
	if aim != Vector2.ZERO:
		aim_dir = aim
		if player.velocity.length() < 5.0:
			player.last_dir = aim   # stand and face where you're shooting
	elif not Screen.is_touch:
		aim_dir = (get_local_mouse_position() - ppos()).normalized()
	if aim != Vector2.ZERO and _fire_t <= 0.0:
		_fire(weapon_id(), aim)
	var dash_now := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_K) or _touch_dash
	_touch_dash = false
	if dash_now and not _dash_was and _dash_t <= 0.0:
		_dash()
	_dash_was = dash_now


func _roll_dmg(base: float) -> Array:   # [damage, crit?]
	var crit := randf() < float(stats.crit)
	return [base * float(stats.dmg) * (2.0 if crit else 1.0), crit]


func _fire(id: String, aim: Vector2) -> void:
	var w := SurvivalArsenal.at_level(id, SurvivalArsenal.level(id))
	_fire_t = float(w.cd) / float(stats.fire_rate)
	_fire_t_max = _fire_t
	var col: Color = w.color
	var at := ppos() + aim * 9.0
	var n: int = stats.multishot
	var flash := _Boom.new()
	flash.radius = 6.0
	flash.color = col
	flash.position = at
	flash.z_index = 4050
	add_child(flash)
	match id:
		"scatter":
			sfx.play("boom", 0.25)
			for i in int(w.pellets) + (n - 1) * 2:
				var s := _player_shot(at, aim.rotated(randf_range(-0.45, 0.45)) * float(w.speed) * randf_range(0.85, 1.1), w, "pellet")
				s.life = float(w.life)
			shake_small()
		"flame":
			sfx.play("shoot", 0.0)
			for i in n:
				var s := _player_shot(at, aim.rotated((i - (n - 1) / 2.0) * 0.22) * float(w.speed), w, "fire")
				s.boom = float(w.radius) * float(stats.size)
				s.life = 1.4
		"spear":
			sfx.play("dash", 0.0)
			for i in n:
				var s := _player_shot(at, aim.rotated((i - (n - 1) / 2.0) * 0.12) * float(w.speed), w, "spear")
				s.pierce = int(w.pierce) + int(stats.pierce)
		"moon":
			sfx.play("dash", 0.0)
			for i in n:
				var s := _player_shot(at, aim.rotated((i - (n - 1) / 2.0) * 0.35) * float(w.speed), w, "moon")
				s.pierce = 999
				s.life = 2.2
				s.r *= float(w.get("size", 1.0))
		"storm":
			_storm(aim, w)
		_:
			sfx.play("shoot")
			for i in n:
				var s := _player_shot(at, aim.rotated((i - (n - 1) / 2.0) * 0.16) * float(w.speed), w, "bolt")
				s.pierce = int(stats.pierce)
				s.life = 1.6


func _player_shot(at: Vector2, vel: Vector2, w: Dictionary, kind: String) -> SurvivalShot:
	var s := shoot(at, vel, float(w.dmg), w.color, false)
	s.kind = kind
	s.r = 3.0 * float(stats.size)
	s.pierce = int(stats.pierce)
	return s


# Lightning: hits the monster closest to where you aim, then jumps to neighbours.
func _storm(aim: Vector2, w: Dictionary) -> void:
	var rng: float = w.range
	var first: SurvivalMob = null
	var best := INF
	for m in mobs:
		if not is_instance_valid(m) or m.dead or m.untouchable():
			continue
		var to: Vector2 = m.center() - ppos()
		var d := to.length()
		if d > rng:
			continue
		var off := absf(aim.angle_to(to))
		if off > 0.7:
			continue
		var score_v := d * (1.0 + off * 2.0)
		if score_v < best:
			best = score_v
			first = m
	var pts: Array[Vector2] = [ppos()]
	if first == null:   # nothing in front: a short crackle so the tap still does something
		pts.append(ppos() + aim * rng * 0.5)
		_zap(pts)
		sfx.play("hit", 0.3)
		_fire_t *= 0.5
		return
	sfx.play("boom", 0.4)
	var hit: Array = []
	var cur := first
	for k in int(w.chains) + 1:
		if cur == null:
			break
		hit.append(cur)
		pts.append(cur.center())
		var r := _roll_dmg(float(w.dmg))
		cur.hit(r[0], (cur.center() - pts[pts.size() - 2]).normalized(), r[1])
		cur = _nearest_mob(pts.back(), 95.0, hit)
	_zap(pts)


func _zap(pts: Array[Vector2]) -> void:
	var z := _Zap.new()
	z.points = pts
	z.z_index = 4070
	z.material = UNSHADED
	add_child(z)


func _dash() -> void:
	sfx.play("dash")
	_dash_t = stats.dash_cd
	_invuln = maxf(_invuln, 0.35)
	var dir: Vector2 = player.velocity.normalized() if player.velocity.length() > 5.0 else player.last_dir
	var target: Vector2 = player.position
	for k in 14:   # 70 px in 5 px steps, stopping at the water's edge
		var nxt: Vector2 = target + dir * 5.0
		if not is_walk(nxt + Vector2(0, 4)):
			break
		target = nxt
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
		s.t += delta
		if s.kind == "moon":   # boomerang: slows, turns round, flies back to you
			if s.t > 0.42:
				var back: Vector2 = (pp - s.position)
				s.vel = s.vel.move_toward(back.normalized() * 300.0, 900.0 * delta)
				if not s.returning:
					s.returning = true
					s.hit_ids.clear()   # may hit everything again on the way back
				if back.length() < 10.0:
					shots.erase(s)
					s.queue_free()
					continue
		s.position += s.vel * delta
		s.life -= delta
		var gone: bool = s.life <= 0.0 or not arena.grow(60.0).has_point(s.position)
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
					if s.boom > 0.0:   # fireball: explode on the first monster
						gone = true
						break
					var r := _roll_dmg(s.dmg)
					m.hit(r[0], s.vel.normalized(), r[1])
					s.hit_ids.append(m)
					if s.pierce <= 0:
						gone = true
						break
					s.pierce -= 1
		if gone:
			if s.boom > 0.0 and not s.hostile:
				var r := _roll_dmg(s.dmg)
				explode(s.position, s.boom, 0, false, true, null, r[0])
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
func shoot(at: Vector2, vel: Vector2, dmg: float, col: Color, hostile := true, broadcast := true) -> SurvivalShot:
	var s := SurvivalShot.new()
	s.position = at
	s.vel = vel
	s.dmg = dmg
	s.color = col
	s.hostile = hostile
	s.z_index = 4000
	s.material = UNSHADED
	add_child(s)
	shots.append(s)
	if hostile and broadcast and net and net.is_host:
		_net_shots.append(s)   # sent at the end of the frame (after r / homing / slows are set)
	return s


func fan(at: Vector2, dir: Vector2, n: int, step: float, spd: float, dmg: float, col: Color) -> void:
	for i in n:
		shoot(at, dir.rotated((i - (n - 1) / 2.0) * step) * spd, dmg, col)


func ring(at: Vector2, n: int, spd: float, dmg: float, col: Color) -> void:
	var off := randf() * TAU
	for i in n:
		shoot(at, Vector2.RIGHT.rotated(off + TAU * i / n) * spd, dmg, col)


func fire(at: Vector2, broadcast := true) -> void:
	if broadcast and net and net.is_host:
		net.send({"t": "hf", "x": snappedf(at.x, 0.1), "y": snappedf(at.y, 0.1)})
	var f := _Fire.new()
	f.position = at
	f.z_index = int(at.y / 2.0) - 1
	add_child(f)
	fires.append([f, 3.5])


func explode(at: Vector2, radius: float, dmg: int, hurts_player: bool, hurts_mobs: bool, source: Node = null, mob_dmg := 2.0, broadcast := true) -> void:
	if hurts_player and broadcast and net and net.is_host:
		net.send({"t": "hx", "x": snappedf(at.x, 0.1), "y": snappedf(at.y, 0.1), "r": radius, "dm": dmg})
	var b := _Boom.new()
	b.position = at
	b.radius = radius
	b.z_index = 4050
	b.material = UNSHADED
	add_child(b)
	sfx.play("boom", 0.2)
	if hurts_player or radius > 34.0:
		shake()
	if hurts_player and ppos().distance_to(at) < radius:
		hurt_player(dmg)
	if hurts_mobs:
		for m in mobs.duplicate():
			if m != source and not m.dead and m.center().distance_to(at) < radius:
				m.hit(mob_dmg, (m.position - at).normalized())


var _floaters := 0

func floater(at: Vector2, text: String, col: Color) -> void:
	# cap damage numbers (shotguns + swarms made hundreds of labels on phones)
	if _floaters > (12 if Screen.low() else 30) and not text.ends_with("!"):
		return
	_floaters += 1
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
	l.material = UNSHADED
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(func():
		_floaters -= 1
		l.queue_free())


func telegraph(at: Vector2, radius: float, time: float, broadcast := true) -> void:
	if broadcast and net and net.is_host:
		net.send({"t": "hw", "x": snappedf(at.x, 0.1), "y": snappedf(at.y, 0.1), "r": radius, "tm": time})
	var w := _Warn.new()
	w.position = at
	w.radius = radius
	w.time = time
	w.z_index = int(at.y / 2.0) - 1
	w.material = UNSHADED
	add_child(w)


func telegraph_line(from: Vector2, dir: Vector2, length: float, time: float, broadcast := true) -> void:
	if broadcast and net and net.is_host:
		net.send({"t": "hl", "x": snappedf(from.x, 0.1), "y": snappedf(from.y, 0.1), "dx": snappedf(dir.x, 0.001), "dy": snappedf(dir.y, 0.001), "ln": length, "tm": time})
	var w := _Warn.new()
	w.position = from
	w.line = dir * length
	w.time = time
	w.z_index = int(from.y / 2.0) - 1
	w.material = UNSHADED
	add_child(w)


func drop_coins(at: Vector2, total: int) -> void:
	while total > 0:
		var v := 5 if total >= 10 else 1
		total -= v
		var c := _Coin.new()
		c.game = self
		c.value = v
		c.position = at
		c.vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 90.0)
		c.z_index = int(at.y / 2.0) + 1
		c.material = UNSHADED
		add_child(c)


func collect_coin(v: int, at: Vector2) -> void:
	run_coins += v
	SurvivalArsenal.add_coins(v)
	sfx.play("pickup", 0.25)
	if v >= 5:
		floater(at, "+%d" % v, Color(1.0, 0.85, 0.3))
	_update_hud()


func shake_small() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake") and randf() < 0.5:
		cam.shake()


func shake() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake()


func hurt_player(dmg: int) -> bool:
	if _invuln > 0.0 or state == "over" or dmg <= 0 or _god or down:
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
			c.radius = m.radius * 0.65
			c.set_size(m.scale_k * 0.65)
			if m.type_name == "slime":
				c.tint = m.tint   # same colour as the parent
			_add_mob(c)
	var coins := 0
	if give_points and not m.is_clone:
		coins = 25 + 5 * round_no if m.is_boss else 1 + int(m.kind.pts) / 12 + (1 if m.mutations.size() > 0 else 0)
		drop_coins(m.position, coins)
	if net and net.is_host and m.net_id != 0:
		net.died(m, coins)   # every player gets their own coins
	if randf() < 0.08 and not m.is_clone:
		_heart_drop(m.position)
	m.queue_free()
	if m == boss:
		boss = null
		_boss_panel.visible = false
		for o in mobs.duplicate():   # the boss's minions vanish with it
			_puff(o.center(), Color(0.8, 0.8, 1.0), o.scale_k)
			o.queue_free()
		mobs.clear()
		if net and net.is_host:
			net.by_id.clear()
			net.send({"t": "mc"})
		for s in shots.duplicate():
			if s.hostile:
				shots.erase(s); s.queue_free()
		_heart_drop(m.position)
		state = "upgrade"
		_upgrade_wait = 0.0
		if net:
			net.send_state()
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
	if net == null:
		get_tree().paused = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var v := PixelUI.page(layer, "⚔ Choose a perk", 760, func(): pass)
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
			layer.queue_free()
			if _bot:
				get_tree().paused = false
				_next_round()
			elif net:
				_show_armory(_mark_ready)
			else:
				_show_armory(func():
					get_tree().paused = false
					_next_round()), i == picks[0])
		b.custom_minimum_size = Vector2(220, 120)
		if _bot and i == picks[0]:
			get_tree().create_timer(1.0, true).timeout.connect(b.emit_signal.bind("pressed"))
		b.add_theme_font_size_override("font_size", 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


# Armory: buy weapons and level them up with coins. Progress is saved, so every run
# starts with everything bought so far. `on_done` runs when the page is closed.
func _show_armory(on_done: Callable) -> void:
	if net == null:
		get_tree().paused = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var close := func():
		layer.queue_free()
		weapons = SurvivalArsenal.owned()
		weapon_i = clampi(weapon_i, 0, weapons.size() - 1)
		_update_hud()
		on_done.call()
	var v := PixelUI.page(layer, "🛒 Armory", 760, close)
	var coins_lbl := PixelUI.label("", 30, PixelUI.GOLD)
	v.add_child(coins_lbl)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(420.0, get_viewport().get_visible_rect().size.y - 260.0))
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_arm_list = list
	_arm_coins = coins_lbl
	_fill_armory()
	var go := PixelUI.button("Continue", close, true)
	go.custom_minimum_size = Vector2(0, 56)
	v.add_child(go)


func _fill_armory() -> void:
	_arm_coins.text = "🪙 %d coins" % SurvivalArsenal.coins()
	for c in _arm_list.get_children():
		c.queue_free()
	for id in SurvivalArsenal.ORDER:
		var d: Dictionary = SurvivalArsenal.WEAPONS[id]
		var lvl := SurvivalArsenal.level(id)
		var price := SurvivalArsenal.next_price(id)
		var card := PixelUI.panel()
		_arm_list.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		card.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		h.add_child(info)
		var stars := "★".repeat(lvl) + "☆".repeat(SurvivalArsenal.MAX_LEVEL - lvl)
		info.add_child(PixelUI.label("%s %s   %s" % [d.icon, d.name, stars if lvl > 0 else "(locked)"], 28,
			PixelUI.GOLD if lvl > 0 else PixelUI.MUTED, false))
		var desc := PixelUI.label(d.desc, 20, PixelUI.CREAM, false)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
		var label := "MAX" if price < 0 else ("Buy  🪙%d" if lvl == 0 else "Level up  🪙%d") % price
		var b := PixelUI.button(label, func():
			if SurvivalArsenal.buy_next(id):
				sfx.play("upgrade", 0.0)
				_fill_armory.call_deferred()
			else:
				sfx.play("hurt", 0.0), lvl == 0)
		b.custom_minimum_size = Vector2(190, 56)
		b.add_theme_font_size_override("font_size", 24)
		b.disabled = price < 0 or SurvivalArsenal.coins() < price
		h.add_child(b)


func _apply_upgrade(i: int) -> void:
	match i:
		0: stats.dmg *= 1.25
		1: stats.fire_rate *= 1.25
		2: stats.multishot += 1
		3: stats.pierce += 1
		4: stats.speed *= 1.15
		5: stats.dash_cd *= 0.7
		6: stats.size *= 1.3; stats.dmg *= 1.2
		7: hearts.heal(3)
		8: stats.lifesteal += 1
		9: stats.crit += 0.1
		10: stats.magnet *= 1.8
		11:
			hearts.set_max(hearts.max_hearts + 1)
			hearts.heal(1)


func _on_died() -> void:
	if state == "over":
		return
	if net:   # co-op: knocked out until the next round (or until everyone is down)
		down = true
		banner_small("You're down! Your friends can still win the round")
		if net.is_host and net.everyone_down():
			game_over_mp()
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
		_open_pause()
		return
	if state in ["intro", "over"] or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: _cycle_weapon(-1)
			KEY_E: _cycle_weapon(1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6: _select_weapon(event.keycode - KEY_1)
	elif event is InputEventMouseButton and event.pressed and not Screen.is_touch:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(1)


func _open_pause() -> void:
	var buttons := [["Resume", func(): pass]]
	buttons.append(["Settings", func(): SettingsPage.open(self)])
	buttons.append(["Leave" if net else "Quit", func():
		if net:
			Net.leave()
		get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn")])
	RoundCard.show_card(self, "Paused",
		"Left stick move · drag right side to aim\n⇄ weapon · DASH dodge · ↑ jump" if Screen.is_touch
			else "Mouse aim, hold left to shoot · Q/E or wheel: weapon\nRight-click / K dash · Space jump · Shift sprint", buttons, net == null)


# ------------------------------------------------------------------ co-op helpers
func _revive() -> void:
	if down:
		down = false
		hearts.heal(hearts.max_hearts)
		banner_small("Back in the fight!")
	var sp: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	sp.modulate.a = 1.0


func _mark_ready() -> void:
	local_ready = true
	banner_small("Waiting for the others…")
	if net.is_host:
		net.check_ready()
	else:
		net.send({"t": "rdy"}, 1)


func start_next_round_mp() -> void:
	if state == "upgrade":
		_next_round()


# Guest: a monster's hit lands on our screen; the host applies it.
func report_hit(m: SurvivalMob, amount: float, dir: Vector2, crit: bool) -> void:
	if net and m.net_id != 0:
		net.send({"t": "hit", "id": m.net_id, "d": snappedf(amount, 0.01), "dx": snappedf(dir.x, 0.01), "dy": snappedf(dir.y, 0.01), "cr": crit}, 1)


# Guest: the host spawned a monster; make a local copy that mirrors it.
func spawn_copy(d: Dictionary) -> void:
	var m := SurvivalMob.new()
	m.remote = true
	add_child(m)
	m.position = Vector2(float(d.x), float(d.y))
	m.net_target = m.position
	var muts: Array[String] = []
	for x in d.get("mu", []):
		muts.append(str(x))
	var bdef := {}
	if d.has("bn"):
		bdef = {"name": str(d.bn), "hp": 100.0, "scale": float(d.sc), "speed": 0.0, "tint": Color.html(str(d.tn)),
			"sprite": str(d.get("bs", d.ty)), "shot": Color.WHITE, "patterns": []}
	m.setup(self, str(d.ty), muts if bdef.is_empty() else [] as Array[String], maxi(round_no, 1), bdef)
	m.tint = Color.html(str(d.tn))
	m.set_size(float(d.sc))
	if bdef.is_empty():   # same hit size as on the host (big slimes, Giant / Tiny mutations)
		m.radius = float(m.kind.r) * float(d.sc) / float(m.kind.scale)
	m.net_id = int(d.id)
	net.by_id[m.net_id] = m
	mobs.append(m)
	_puff(m.center(), Color(0.7, 0.4, 1.0), 1.0)


# Guest: a monster died on the host.
func copy_died(m: SurvivalMob, coins: int) -> void:
	mobs.erase(m)
	_puff(m.center(), m.tint if m.tint != Color.WHITE else Color(0.9, 0.9, 0.9), m.scale_k)
	sfx.play("kill" if not m.is_boss else "boom", 0.1)
	if coins > 0:
		drop_coins(m.position, coins)
	if m == boss:
		boss = null
		_boss_panel.visible = false
	m.queue_free()


# Guest: round state from the host (2x a second, and on every change).
func apply_state(d: Dictionary) -> void:
	var new_round := int(d.get("r", round_no))
	var new_state := str(d.get("s", state))
	if new_round > round_no:
		round_no = new_round
		local_ready = false
		_revive()
	if new_state == "upgrade" and state != "upgrade":
		state = new_state
		for s in shots.duplicate():
			if s.hostile:
				shots.erase(s); s.queue_free()
		get_tree().create_timer(1.6, false).timeout.connect(_show_upgrades)
	elif new_state != "over":
		state = new_state
	to_spawn = int(d.get("ts", 0))
	score = int(d.get("sc", score))
	kills = int(d.get("k", kills))
	var day := float(d.get("d", _day_t))
	if absf(day - _day_t) > 3.0 and absf(day - _day_t) < DAY_LEN - 3.0:
		_day_t = day
	var bid := int(d.get("b", 0))
	if bid != 0 and net.by_id.has(bid):
		var b: SurvivalMob = net.by_id[bid]
		if b != boss:
			boss = b
			_boss_name.text = "💀 %s" % str(b.boss.get("name", "Boss"))
			_boss_panel.visible = true
			sfx.play("boss", 0.0)
	elif bid == 0 and boss:
		boss = null
		_boss_panel.visible = false


# Everyone is down: end the run for the whole room.
func game_over_mp(broadcast := true) -> void:
	if state == "over":
		return
	if broadcast and net and net.is_host:
		net.send({"t": "over"})
	state = "over"
	var best_round := int(Global.stats.get("survival_best_round", 0))
	Global.stats["survival_best_round"] = maxi(best_round, round_no)
	Global.stats["survival_best_score"] = maxi(int(Global.stats.get("survival_best_score", 0)), score)
	Global.save_game()
	var buttons := []
	if net and net.is_host:
		buttons.append(["Play again", func():
			Net.host_start_round("", 1, "survival")
			get_tree().change_scene_to_file(Net.round_scene())])
	buttons.append(["Leave", func():
		Net.leave()
		get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn")])
	RoundCard.show_card(self, "The team fell in round %d" % round_no,
		"Score %d   ·   Kills %d%s" % [score, kills, "" if (net and net.is_host) else "\nThe host can start a new run"], buttons, false)


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
	_coin_lbl = PixelUI.label("", 22, PixelUI.GOLD, false)
	col.add_child(_coin_lbl)
	var dash_bg := ColorRect.new()
	dash_bg.color = Color(0.1, 0.12, 0.2)
	dash_bg.custom_minimum_size = Vector2(160, 6)
	col.add_child(dash_bg)
	_dash_fill = ColorRect.new()
	_dash_fill.color = Color(0.45, 0.9, 1.0)
	_dash_fill.size = Vector2(160, 6)
	dash_bg.add_child(_dash_fill)

	# radar: where the monsters (red), the boss (big), coins-rich friends (their colour) are
	var radar := _Radar.new()
	radar.game = self
	radar.position = Vector2(16, 170)
	radar.custom_minimum_size = Vector2(92, 92)
	radar.size = Vector2(92, 92)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(radar)

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

	var keys := PixelUI.label("Aim: mouse (hold left to shoot)   ·   Weapon: Q / E / wheel   ·   Dash: right-click / K   ·   Esc pause", 18, Color(PixelUI.MUTED, 0.75))
	keys.visible = not Screen.is_touch
	keys.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	keys.offset_left = -560
	keys.offset_right = 560
	keys.offset_top = -30
	hud.add_child(keys)


func _update_hud() -> void:
	_round_lbl.text = "⚔ Round %d" % round_no
	var left := mobs.size() + to_spawn + portals_open
	_score_lbl.text = "Score %d · Kills %d%s" % [score, kills, ("   ·   %d left" % left) if state == "waves" else ""]
	var wid := weapon_id()
	var wd: Dictionary = SurvivalArsenal.WEAPONS[wid]
	_weapon_lbl.text = "%s %s Lv%d%s" % [wd.icon, wd.name, SurvivalArsenal.level(wid),
		("   (%d/%d)" % [weapon_i + 1, weapons.size()]) if weapons.size() > 1 else ""]
	_coin_lbl.text = "🪙 %d" % SurvivalArsenal.coins()
	_dash_fill.size.x = 160.0 * clampf(1.0 - _dash_t / stats.dash_cd, 0.0, 1.0)
	_dash_fill.color = Color(0.45, 0.9, 1.0) if _dash_t <= 0.0 else Color(0.3, 0.45, 0.6)
	if boss and is_instance_valid(boss):
		_boss_fill.size.x = 520.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0)
		_boss_fill.color = Color(1.0, 0.45, 0.15) if boss.enraged else Color(0.86, 0.18, 0.22)


func banner(text: String, col: Color, broadcast := true) -> void:
	if broadcast and net and net.is_host:
		net.send({"t": "bn", "tx": text, "c": col.to_html()})
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
	var color := Color(1.0, 0.6, 0.2)
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.35:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := _t / 0.35
		draw_circle(Vector2.ZERO, radius * k, Color(color, 0.45 * (1.0 - k)))
		draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 32, Color(color.lightened(0.5), 1.0 - k), 2.0)


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


# Lightning bolt between points (Storm Rod).
class _Zap extends Node2D:
	var points: Array[Vector2] = []
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.18:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var a := 1.0 - _t / 0.18
		for i in points.size() - 1:
			var p0: Vector2 = points[i]
			var p1: Vector2 = points[i + 1]
			var prev := p0
			for k in range(1, 6):
				var q := p0.lerp(p1, k / 5.0)
				if k < 5:
					q += (p1 - p0).orthogonal().normalized() * randf_range(-5.0, 5.0)
				draw_line(prev, q, Color(0.6, 0.8, 1.0, a), 3.0)
				draw_line(prev, q, Color(1, 1, 1, a), 1.2)
				prev = q
			draw_circle(p1, 5.0 * a, Color(0.8, 0.9, 1.0, a * 0.8))


# Aim marker in front of the player (where shots go).
class _Reticle extends Node2D:
	var game: Node
	func _process(_delta: float) -> void:
		var show: bool = game.state in ["waves", "boss_wait", "boss"] and (Screen.is_touch or game.aim_dir != Vector2.ZERO)
		visible = show and not Screen.is_touch or (show and game._aim_touch != -1)
		if visible:
			position = game.ppos() + game.aim_dir * 34.0
			rotation = game.aim_dir.angle()
		queue_redraw()
	func _draw() -> void:
		var c := Color(1.0, 0.9, 0.45, 0.85)
		draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, c, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(9, 0), Vector2(5, -3), Vector2(5, 3)]), c)
		# cooldown ring
		var k: float = clampf(1.0 - game._fire_t / maxf(game._fire_t_max, 0.01), 0.0, 1.0)
		if k < 1.0:
			draw_arc(Vector2.ZERO, 7.5, -PI / 2.0, -PI / 2.0 + TAU * k, 16, Color(1, 1, 1, 0.6), 1.0)


# Phones: the right-hand aim stick (drawn where the thumb went down).
class _AimStickView extends Control:
	var game: Node
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if game._aim_touch == -1:
			# a faint hint where to put the thumb
			var vp := get_viewport_rect().size
			draw_arc(Vector2(vp.x * 0.78, vp.y * 0.52), 46.0, 0.0, TAU, 32, Color(1, 1, 1, 0.12), 2.0)
			return
		var o: Vector2 = game._aim_origin
		draw_circle(o, 70.0, Color(0.05, 0.08, 0.16, 0.25))
		draw_arc(o, 70.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.35, 0.55), 2.0)
		var k: Vector2 = game._aim_vec.limit_length(70.0)
		draw_circle(o + k, 26.0, Color(1.0, 0.82, 0.35, 0.55))


# Coins dropped by monsters: drift to the player when close.
class _Coin extends Node2D:
	var game: Node
	var value := 1
	var vel := Vector2.ZERO
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		var to: Vector2 = game.ppos() + Vector2(0, 6) - position
		var d := to.length()
		if _t > 0.35 and d < float(game.stats.magnet):
			vel = vel.move_toward(to.normalized() * 260.0, 900.0 * delta)
		else:
			vel = vel.move_toward(Vector2.ZERO, 300.0 * delta)
		position += vel * delta
		if d < 8.0 and _t > 0.2:
			game.collect_coin(value, position)
			queue_free()
		elif _t > 25.0:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var squash := absf(cos(_t * 5.0)) * 0.7 + 0.3   # spinning
		var r := 2.6 if value < 5 else 3.6
		draw_set_transform(Vector2(0, -2.0 - absf(sin(_t * 4.0)) * 1.5), 0.0, Vector2(squash, 1.0))
		draw_circle(Vector2.ZERO, r + 0.8, Color(0.35, 0.2, 0.05))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.8, 0.2))
		draw_circle(Vector2(-0.8, -0.8), r * 0.4, Color(1.0, 0.97, 0.7))


# Danger zone shown before a boss lands / charges, so attacks are fair to dodge.
class _Warn extends Node2D:
	var radius := 30.0
	var line := Vector2.ZERO   # for charges: the dash vector
	var time := 0.8
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t >= time:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := clampf(_t / time, 0.0, 1.0)
		var c := Color(1.0, 0.2, 0.15, 0.22 + 0.2 * k)
		if line != Vector2.ZERO:
			var n := line.orthogonal().normalized() * 9.0
			draw_colored_polygon(PackedVector2Array([n, line + n, line - n, -n]), c)
			draw_line(Vector2.ZERO, line * k, Color(1.0, 0.4, 0.3, 0.7), 2.0)
		else:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, radius, c)
			draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 32, Color(1.0, 0.45, 0.35, 0.8), 2.0)


# Mini radar: monsters around you (red dots, boss = big dot), friends in their colour.
# Things further away than the radar range sit on its rim, so you always know which way to go.
class _Radar extends Control:
	const RANGE := 420.0
	var game: Node
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.1:   # 10 fps is plenty
			_t = 0.0
			queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c, r, Color(0.04, 0.06, 0.12, 0.55))
		draw_arc(c, r, 0.0, TAU, 32, Color(1.0, 0.82, 0.35, 0.6), 1.5)
		if game.state in ["intro", "over"]:
			return
		var me: Vector2 = game.player.position
		for m in game.mobs:
			if not is_instance_valid(m) or m.dead:
				continue
			var d: Vector2 = (m.position - me) / RANGE
			var p := c + d.limit_length(1.0) * (r - 4.0)
			if m.is_boss:
				draw_circle(p, 5.0, Color(1.0, 0.35, 0.2))
				draw_arc(p, 6.5, 0.0, TAU, 12, Color(1, 1, 1, 0.8), 1.0)
			else:
				draw_circle(p, 2.0, Color(1.0, 0.3, 0.3, 0.9))
		if game.net:
			for id in game.net.players:
				var pl: Dictionary = game.net.players[id]
				if pl.root.visible:
					var d2: Vector2 = (pl.root.position - me) / RANGE
					draw_circle(c + d2.limit_length(1.0) * (r - 4.0), 3.0, Net.color_of(id))
		draw_circle(c, 2.5, Color(1, 1, 1))
