extends Node2D
class_name SurvivalMob

# A monster in Survival mode: one of 10 types (each with its own AI), optional random
# mutations, or a boss that cycles through attack patterns. Positions are arena-local
# (the arena node is drawn at 2x), the origin is at the feet.

const TYPES := {
	"zombie":   {"hp": 4.0, "speed": 36.0, "dmg": 1, "r": 7.0, "scale": 1.6, "ai": "chase", "pts": 10},
	"bat":      {"hp": 2.0, "speed": 82.0, "dmg": 1, "r": 6.0, "scale": 1.4, "ai": "erratic", "pts": 12},
	"slime":    {"hp": 5.0, "speed": 30.0, "dmg": 1, "r": 8.0, "scale": 1.6, "ai": "hop", "pts": 12},
	"skeleton": {"hp": 3.0, "speed": 34.0, "dmg": 1, "r": 7.0, "scale": 1.6, "ai": "archer", "pts": 15},
	"spider":   {"hp": 3.0, "speed": 44.0, "dmg": 1, "r": 7.0, "scale": 1.6, "ai": "lunge", "pts": 14},
	"wolf":     {"hp": 3.0, "speed": 70.0, "dmg": 1, "r": 7.0, "scale": 1.6, "ai": "wolf", "pts": 12},
	"ghost":    {"hp": 3.0, "speed": 48.0, "dmg": 1, "r": 7.0, "scale": 1.6, "ai": "phase", "pts": 16},
	"bomber":   {"hp": 3.0, "speed": 52.0, "dmg": 2, "r": 7.0, "scale": 1.6, "ai": "bomber", "pts": 15},
	"mage":     {"hp": 4.0, "speed": 30.0, "dmg": 1, "r": 7.0, "scale": 1.7, "ai": "mage", "pts": 20},
	"golem":    {"hp": 12.0, "speed": 22.0, "dmg": 2, "r": 11.0, "scale": 2.2, "ai": "chase", "pts": 30},
	"eye":      {"hp": 3.0, "speed": 58.0, "dmg": 1, "r": 7.0, "scale": 1.6, "ai": "eye", "pts": 14, "fly": true},
	"hornet":   {"hp": 2.5, "speed": 56.0, "dmg": 1, "r": 6.0, "scale": 1.5, "ai": "hornet", "pts": 16, "fly": true},
}
# Unlock order: round N spawns the first N + 2 types.
const ORDER := ["zombie", "slime", "bat", "eye", "skeleton", "spider", "hornet", "wolf", "ghost", "bomber", "mage", "golem"]
const FLYERS := ["bat", "ghost", "eye", "hornet"]   # cross water
# Slimes come in many colours (the sprite is pale and tinted per slime).
const SLIME_COLORS := [Color(0.45, 1.0, 0.5), Color(0.45, 0.7, 1.0), Color(1.0, 0.55, 0.8), Color(0.75, 0.5, 1.0),
	Color(1.0, 0.9, 0.35), Color(1.0, 0.45, 0.4), Color(0.4, 1.0, 0.95), Color(0.55, 0.55, 0.65)]
const MUTATIONS := ["Giant", "Swift", "Armored", "Vampiric", "Explosive", "Regenerating", "Splitting", "Phasing", "Burning", "Tiny"]
const MUT_COLOR := {
	"Giant": Color(1.0, 0.75, 0.45), "Swift": Color(1.0, 0.95, 0.4), "Armored": Color(0.75, 0.8, 0.9),
	"Vampiric": Color(1.0, 0.35, 0.4), "Explosive": Color(1.0, 0.55, 0.2), "Regenerating": Color(0.45, 1.0, 0.5),
	"Splitting": Color(0.6, 0.9, 1.0), "Phasing": Color(0.8, 0.7, 1.0), "Burning": Color(1.0, 0.45, 0.15),
	"Tiny": Color(0.9, 0.9, 0.9),
}
const SHADOW := preload("res://assets/wildlife/shadow_soft.png")
const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")

var game: Node                  # SurvivalGame
var type_name := ""
var kind: Dictionary
var hp := 1.0
var max_hp := 1.0
var speed := 30.0
var radius := 7.0
var dmg := 1
var scale_k := 1.6
var armor := 1.0                # damage multiplier taken
var regen := 0.0
var mutations: Array[String] = []
var tint := Color.WHITE
var is_boss := false
var is_clone := false
var boss: Dictionary = {}
var dead := false

var spr: Sprite2D
var _px := 1.0                  # sprite pixels -> world: 16 px art and 24 px art end up the same size
var tag: Label
var t := randf() * 10.0
var kb := Vector2.ZERO
var flash := 0.0
var state := ""
var state_t := 0.0
var cd := 1.0                   # attack / ability cooldown
var aim := Vector2.ZERO
var move_dir := Vector2.ZERO
var phased := false
var _fire_drop := 0.0
var _pattern_i := 0
var _spiral_a := 0.0
var _shots_left := 0
var _jump_from := Vector2.ZERO
var enraged := false
# co-op
var net_id := 0                 # id shared with the other players (0 = solo)
var remote := false             # guest-side copy of a monster the host simulates
var net_target := Vector2.ZERO
var _last_x := 0.0
var _stuck_t := 0.0             # walker blocked by water for this long...
var _wade_t := 0.0              # ...so it wades across for a while (no pathfinding needed)


func setup(g: Node, tname: String, muts: Array[String], round_no: int, boss_def: Dictionary = {}) -> void:
	game = g
	type_name = tname
	kind = TYPES[tname]
	hp = kind.hp * (1.0 + 0.12 * (round_no - 1))
	speed = kind.speed
	radius = kind.r
	dmg = kind.dmg
	scale_k = kind.scale
	if not boss_def.is_empty():
		is_boss = true
		boss = boss_def
		hp = float(boss_def.hp)
		scale_k = float(boss_def.scale)
		radius = 5.5 * scale_k
		speed = float(boss_def.speed)
		dmg = 1 if round_no <= 4 else 2
		tint = boss_def.tint
		cd = 2.0
	elif tname == "slime":
		tint = SLIME_COLORS.pick_random()
		if randf() < 0.3:   # some big slimes (they split when killed)
			scale_k *= 1.35; radius *= 1.35; hp *= 1.6
	for m in muts:
		_mutate(m)
	max_hp = hp

	var sh := Sprite2D.new()
	sh.texture = SHADOW
	sh.scale = Vector2(0.45, 0.4) * scale_k
	sh.position = Vector2(0, 1)
	add_child(sh)
	spr = Sprite2D.new()
	spr.texture = load("res://assets/survival/%s.png" % str(boss_def.get("sprite", tname)))
	spr.hframes = 2
	var fh := float(spr.texture.get_height())
	_px = 16.0 / fh
	spr.scale = Vector2.ONE * scale_k * _px
	spr.offset = Vector2(0, -fh * 0.5)
	spr.self_modulate = tint
	add_child(spr)
	if not mutations.is_empty():
		tag = Label.new()
		tag.text = " ".join(mutations)
		tag.add_theme_font_override("font", FONT)
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", MUT_COLOR[mutations[0]])
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		tag.add_theme_constant_override("outline_size", 4)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(120, 18)
		tag.scale = Vector2(0.5, 0.5)
		tag.position = Vector2(-30, -16 * scale_k - 12)
		add_child(tag)


# Resize (used by clones and split slimes).
func set_size(k: float) -> void:
	scale_k = k
	spr.scale = Vector2.ONE * k * _px


func is_flyer() -> bool:
	return type_name in FLYERS


func _mutate(m: String) -> void:
	mutations.append(m)
	match m:
		"Giant":
			scale_k *= 1.5; radius *= 1.5; hp *= 2.0; speed *= 0.8; dmg += 1
		"Swift":
			speed *= 1.6; tint = tint * Color(1.0, 1.0, 0.7)
		"Armored":
			armor = 0.5; tint = tint * Color(0.75, 0.8, 0.95)
		"Vampiric":
			tint = tint * Color(1.0, 0.6, 0.65)
		"Regenerating":
			regen = 0.5; tint = tint * Color(0.75, 1.0, 0.75)
		"Burning":
			tint = tint * Color(1.0, 0.75, 0.55)
		"Tiny":
			scale_k *= 0.7; radius *= 0.7; hp *= 0.6; speed *= 1.35
		"Phasing":
			tint = tint * Color(0.85, 0.8, 1.0)


func center() -> Vector2:
	return position + Vector2(0, -6.0 * scale_k)


func untouchable() -> bool:
	return dead or phased or state == "vanish"


func hit(amount: float, dir: Vector2, crit := false, from_net := false) -> void:
	if untouchable():
		return
	if remote:   # co-op guest: the host owns this monster's health
		game.report_hit(self, amount, dir, crit)
		flash = 0.09
		game.sfx.play("hit", 0.2)
		var t2 := str(snappedf(amount * armor, 0.1)).trim_suffix(".0")
		game.floater(center(), t2 + "!" if crit else t2, Color(1.0, 0.55, 0.2) if crit else Color(1, 0.95, 0.6))
		return
	var real := amount * armor
	hp -= real
	flash = 0.09
	game.sfx.play("hit", 0.2)
	if not is_boss and type_name != "golem":
		kb += dir * (130.0 if crit else 90.0)
	if not from_net:   # a guest's hit already showed its number on their screen
		var txt := str(snappedf(real, 0.1)).trim_suffix(".0")
		game.floater(center(), txt + "!" if crit else txt, Color(1.0, 0.55, 0.2) if crit else Color(1, 0.95, 0.6))
	if hp <= 0.0:
		dead = true
		game.mob_died(self)


# ------------------------------------------------------------------ per-frame AI
func tick(delta: float, ppos: Vector2) -> void:
	t += delta
	cd -= delta
	state_t -= delta
	flash -= delta
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)
	var to_p := ppos - position
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	move_dir = Vector2.ZERO
	var spd := speed

	if is_boss:
		_boss_tick(delta, ppos, dir, dist)
		spd = speed * (1.25 if enraged else 1.0)
	else:
		match kind.ai:
			"chase":
				move_dir = dir
			"erratic":
				move_dir = dir.rotated(sin(t * 6.0) * 1.2)
			"hop":
				if state == "hop" and state_t > 0.0:
					move_dir = aim; spd = speed * 3.2
				else:
					state = ""
					if cd <= 0.0:
						state = "hop"; state_t = 0.35; aim = dir; cd = 1.1
			"archer":
				move_dir = dir if dist > 150.0 else (-dir if dist < 100.0 else dir.orthogonal() * (1.0 if int(t / 3.0) % 2 == 0 else -1.0))
				if cd <= 0.0 and dist < 260.0:
					cd = 2.2
					game.shoot(center(), dir * 150.0, 1, Color(0.95, 0.92, 0.82))
			"lunge":
				_dash_ai(dir, dist, 120.0, 230.0, 2.5)
				if state == "": move_dir = dir
				elif state == "dash": move_dir = aim; spd = 230.0
			"wolf":
				_dash_ai(dir, dist, 110.0, 210.0, 3.0)
				if state == "":
					move_dir = (dir.orthogonal() + dir * (0.6 if dist > 90.0 else -0.4)).normalized()
				elif state == "dash":
					move_dir = aim; spd = 210.0
			"phase":
				move_dir = dir
				if cd <= 0.0:
					phased = not phased
					cd = 1.0 if phased else 2.2
				if phased: spd = speed * 1.5
			"bomber":
				if state == "fuse":
					if state_t <= 0.0:
						game.explode(position, 46.0, dmg, true, true, self)
						dead = true
						game.mob_died(self, false)
						return
				elif dist < 26.0:
					state = "fuse"; state_t = 0.8
				else:
					move_dir = dir
			"eye":   # circles you, then rams in after a short glare
				_dash_ai(dir, dist, 170.0, 250.0, 2.6)
				if state == "":
					move_dir = (dir.orthogonal() * 0.9 + dir * (0.7 if dist > 80.0 else -0.5)).normalized()
					move_dir = move_dir.rotated(sin(t * 3.0) * 0.4)
				elif state == "dash":
					move_dir = aim; spd = 250.0
			"hornet":   # keeps its distance and fires stingers
				move_dir = dir if dist > 140.0 else (-dir if dist < 90.0 else dir.orthogonal() * (1.0 if int(t / 2.0) % 2 == 0 else -1.0))
				move_dir = (move_dir + Vector2(0, sin(t * 7.0) * 0.4)).normalized()
				if cd <= 0.0 and dist < 240.0:
					cd = 2.4
					var sting: SurvivalShot = game.shoot(center(), dir * 165.0, 1, Color(1.0, 0.85, 0.2))
					sting.r = 2.5
			"mage":
				if state == "vanish":
					if state_t <= 0.0:
						position = game.near_player(110.0, 150.0)
						state = ""
						game.fan(center(), dir, 3, 0.25, 120.0, 1, Color(0.75, 0.45, 1.0))
				else:
					move_dir = dir.orthogonal() * (1.0 if int(t / 2.5) % 2 == 0 else -1.0) + (dir if dist > 150.0 else -dir * 0.5)
					move_dir = move_dir.normalized()
					if cd <= 0.0:
						state = "vanish"; state_t = 0.35; cd = 3.5
	if "Phasing" in mutations:
		phased = fmod(t, 3.0) > 2.0
	if "Burning" in mutations:
		_fire_drop -= delta
		if _fire_drop <= 0.0:
			_fire_drop = 0.6
			game.fire(position)

	# walkers slide along the shore; flyers and bosses may cross water
	var next := position + (move_dir * spd + kb) * delta
	_wade_t -= delta
	if is_flyer() or is_boss:
		position = game.clamp_box(next)
	elif _wade_t > 0.0:
		position = game.clamp_box(position + (move_dir * spd * 0.6 + kb) * delta)
	else:
		var before := position
		position = game.move_in(position, next)
		# barely moving although it wants to: a pond or bay is in the way
		if move_dir != Vector2.ZERO and position.distance_to(before) < spd * delta * 0.3:
			_stuck_t += delta
			if _stuck_t > 0.8:
				_stuck_t = 0.0
				_wade_t = 2.5
		else:
			_stuck_t = maxf(0.0, _stuck_t - delta)
	kb = kb.move_toward(Vector2.ZERO, 400.0 * delta)

	# look
	spr.frame = int(t * 5.0) % 2
	if absf(move_dir.x) > 0.05:
		spr.flip_h = move_dir.x < 0.0
	var a := 0.3 if (phased or state == "vanish") else 1.0
	var c := Color(3, 3, 3) if flash > 0.0 else tint
	if state in ["fuse", "tele_dash", "tele_charge"] and int(t * 12.0) % 2 == 0:
		c = Color(2.5, 0.6, 0.6)
	if enraged:
		c = c * Color(1.25, 0.8, 0.8)
	spr.self_modulate = Color(c, a)
	if state == "hop" or state == "slam":
		spr.position.y = -sin(clampf(1.0 - state_t / (0.9 if state == "slam" else 0.35), 0.0, 1.0) * PI) * (40.0 if state == "slam" else 6.0)
	elif is_flyer():
		spr.position.y = -4.0 + sin(t * 5.0) * 1.5   # hover
	else:
		spr.position.y = 0.0
	z_index = int(position.y * 2.0 / 4.0)
	if tag:   # mutation names only near the player, so big swarms stay readable
		tag.visible = dist < 140.0


# Co-op guests: glide to the host's position and animate locally (no AI here).
func puppet_tick(delta: float) -> void:
	t += delta
	flash -= delta
	position = position.lerp(net_target, clampf(delta * 12.0, 0.0, 1.0))
	var dx := position.x - _last_x
	_last_x = position.x
	if absf(dx) > 0.05:
		spr.flip_h = dx < 0.0
	spr.frame = int(t * 5.0) % 2
	var c := Color(3, 3, 3) if flash > 0.0 else tint
	if state == "tele_dash" and int(t * 12.0) % 2 == 0:
		c = Color(2.5, 0.6, 0.6)
	if enraged:
		c = c * Color(1.25, 0.8, 0.8)
	spr.self_modulate = Color(c, 0.3 if phased else 1.0)
	if is_flyer():
		spr.position.y = -4.0 + sin(t * 5.0) * 1.5
	z_index = int(position.y * 2.0 / 4.0)
	if tag:
		tag.visible = position.distance_to(game.ppos()) < 140.0


# telegraph, then dash at the player (spiders, wolves)
func _dash_ai(dir: Vector2, dist: float, rng: float, _spd: float, every: float) -> void:
	if state == "tele_dash":
		if state_t <= 0.0:
			state = "dash"; state_t = 0.4
	elif state == "dash":
		if state_t <= 0.0:
			state = ""
	elif cd <= 0.0 and dist < rng:
		state = "tele_dash"; state_t = 0.4; aim = dir; cd = every


# ------------------------------------------------------------------ bosses
func _boss_tick(delta: float, ppos: Vector2, dir: Vector2, dist: float) -> void:
	if not enraged and hp < max_hp * 0.5:
		enraged = true
		game.banner("%s is enraged!" % boss.name, Color(1.0, 0.45, 0.35))
		game.sfx.play("boss", 0.0)
		game.shake()
	match state:
		"":
			move_dir = dir if dist > 70.0 else dir.orthogonal()
			if cd <= 0.0:
				var patterns: Array = boss.patterns
				_start_pattern(str(patterns[_pattern_i % patterns.size()]), dir, ppos)
				_pattern_i += 1
		"spiral":
			if fmod(state_t, 0.13) < delta:
				for k in 2:
					game.shoot(center(), Vector2.RIGHT.rotated(_spiral_a + k * PI) * 90.0, 1, boss.shot)
				_spiral_a += 0.4
			if state_t <= 0.0: _end_pattern()
		"aimed":
			if _shots_left > 0 and fmod(state_t, 0.2) < delta:
				game.fan(center(), dir, 3, 0.16, 140.0, 1, boss.shot)
				_shots_left -= 1
			if state_t <= 0.0: _end_pattern()
		"tele_charge":
			if state_t <= 0.0:
				state = "charge"; state_t = 0.7
		"charge":
			move_dir = aim
			position = game.clamp_box(position + aim * 220.0 * delta)
			if state_t <= 0.0: _end_pattern()
		"slam":
			var k := clampf(1.0 - state_t / 0.9, 0.0, 1.0)
			position = _jump_from.lerp(aim, k)
			if state_t <= 0.0:
				game.ring(center(), 10, 85.0, 1, boss.shot)
				game.explode(position, 40.0, 1, true, false, self)
				game.shake()
				_end_pattern()
		"vanish":
			if state_t <= 0.0:
				position = game.near_player(100.0, 130.0)
				game.ring(center(), 8, 85.0, 1, boss.shot)
				_end_pattern()
		"trail":
			move_dir = dir
			position += dir * speed * 1.2 * delta
			if fmod(state_t, 0.15) < delta:
				game.fire(position)
			if state_t <= 0.0: _end_pattern()


func _start_pattern(p: String, dir: Vector2, ppos: Vector2) -> void:
	var c: Color = boss.shot
	match p:
		"ring":
			game.ring(center(), 10 + mini(game.round_no, 8) / 2, 85.0, 1, c); _end_pattern()
		"spread":
			game.fan(center(), dir, 5, 0.24, 120.0, 1, c); _end_pattern()
		"spiral":
			state = "spiral"; state_t = 1.4
		"aimed":
			state = "aimed"; state_t = 0.6; _shots_left = 3
		"charge":
			state = "tele_charge"; state_t = 0.85; aim = dir
			game.telegraph_line(position, dir, 180.0, 0.85)
		"slam":
			state = "slam"; state_t = 0.9; _jump_from = position; aim = game.clamp_arena(ppos)
			game.telegraph(aim, 40.0, 0.9)
		"summon":
			for k in 2:
				game.portal(boss.minion, game.near(position, 30.0, 60.0), [] as Array[String])
			_end_pattern()
		"teleport":
			state = "vanish"; state_t = 0.45
		"trail":
			state = "trail"; state_t = 3.0
		"web":
			for k in 3:
				var s: SurvivalShot = game.shoot(center(), dir.rotated((k - 1) * 0.3) * 90.0, 0, Color(0.92, 0.92, 1.0))
				s.slows = true; s.r = 5.0
			_end_pattern()
		"homing":
			for k in 3:
				var s: SurvivalShot = game.shoot(center(), dir.rotated((k - 1) * 0.8) * 80.0, 1, Color(0.6, 1.0, 0.6))
				s.homing = 2.2; s.life = 4.0; s.r = 4.0
			_end_pattern()
		"clones":
			for k in 2:
				game.clone_of(self)
			_end_pattern()
		_:
			_end_pattern()


func _end_pattern() -> void:
	state = ""
	cd = 2.2 if enraged else 3.0   # breathing room between attacks
