extends Node
class_name SurvivalNet

# Co-op Survival over the same relay as the riddle rooms.
#
# The host runs the real game: spawning, monster AI, bosses, round flow. It streams
#   ms  monster spawned {id, ty, x, y, tn, sc, mu, bn, bs}    mm  positions + hp, 10 Hz
#   hsb this frame's monster shots, batched
#   md  monster died {id, x, y, c}   mc  all minions gone     st  round state, 2 Hz
#   hx  explosion   hf  fire patch   hw/hl  danger telegraphs
#   bn  banner text    over  everyone is down
# Every player (host too) streams pp (position, look, down) at 15 Hz and simulates the
# monsters' shots locally against their own hero, so dodging feels instant. Guests'
# own shots hit the monster copies on their screen and report "hit" to the host,
# who applies the damage. Coins, weapons and perks are per player.

const SEND_HZ := 15.0
const SNAP_HZ := 10.0
const STATE_HZ := 2.0
const INTERP := 0.12
const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")

var game: Node                      # SurvivalGame
var is_host := false
var players := {}                   # id -> {root, spr, snaps, down, ch, anim}
var by_id := {}                     # net id -> SurvivalMob (guests: copies; host: real)
var ready_ids := {}                 # host: who finished picking perks this break
var _send_t := 0.0
var _snap_t := 0.0
var _state_t := 0.0
var _next_id := 1
var _last_pp := {}


func setup(g: Node) -> void:
	game = g
	is_host = Net.is_host()
	Net.message.connect(_on_message)
	Net.peer_left.connect(_on_left)
	if is_host:
		Net.peer_joined.connect(func(id, _n): _catch_up(id))
	Net.disconnected.connect(func(reason):
		game.banner(reason, Color(1, 0.5, 0.4))
		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn"))


func send(d: Dictionary, to := 0) -> void:
	Net.send(d, to)


# ------------------------------------------------------------------ players
func alive_targets() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not game.down:
		out.append(game.player.position)
	for p in players.values():
		if p.root.visible and not p.down:
			out.append(p.root.position)
	return out


func everyone_down() -> bool:
	if not game.down:
		return false
	for p in players.values():
		if not p.down:
			return false
	return true


func _puppet(id: int) -> Dictionary:
	if players.has(id):
		return players[id]
	var root := Node2D.new()
	root.visible = false
	game.add_child(root)
	var src: AnimatedSprite2D = game.player.get_node("AnimatedSprite2D")
	var spr: AnimatedSprite2D = src.duplicate()
	spr.stop()
	root.add_child(spr)
	var tag := Label.new()
	tag.text = str(Net.peers.get(id, "Player"))
	tag.add_theme_font_override("font", FONT)
	tag.add_theme_font_size_override("font_size", 20)
	tag.add_theme_color_override("font_color", Net.color_of(id))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	tag.add_theme_constant_override("outline_size", 4)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(160, 22)
	tag.position = Vector2(-40, -46)
	tag.scale = Vector2(0.5, 0.5)
	tag.material = SurvivalGame.UNSHADED
	root.add_child(tag)
	var p := {"root": root, "spr": spr, "snaps": [], "down": false, "ch": -1, "anim": ""}
	players[id] = p
	return p


func _on_left(id: int) -> void:
	if players.has(id):
		players[id].root.queue_free()
		players.erase(id)
	ready_ids.erase(id)
	if is_host:
		check_ready()


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var rt := now - INTERP
	for p in players.values():
		var snaps: Array = p.snaps
		if snaps.is_empty():
			continue
		while snaps.size() > 2 and snaps[1][0] <= rt:
			snaps.pop_front()
		var pos: Vector2 = snaps[0][1]
		if snaps.size() >= 2 and rt >= snaps[0][0]:
			pos = (snaps[0][1] as Vector2).lerp(snaps[1][1], clampf((rt - snaps[0][0]) / maxf(snaps[1][0] - snaps[0][0], 0.001), 0.0, 1.0))
		p.root.position = pos
		p.root.z_index = int(pos.y * 2.0 / 4.0)
		p.spr.modulate.a = 0.35 if p.down else 1.0
	# guests: monster copies glide to the host's positions
	if not is_host:
		for m in by_id.values():
			if is_instance_valid(m):
				m.puppet_tick(delta)

	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = 1.0 / SEND_HZ
		var sp: AnimatedSprite2D = game.player.get_node("AnimatedSprite2D")
		var msg := {"t": "pp", "x": snappedf(game.player.position.x, 0.1), "y": snappedf(game.player.position.y, 0.1),
			"a": str(sp.animation), "h": sp.flip_h, "c": Global.character, "dn": game.down}
		if msg != _last_pp:
			_last_pp = msg
			send(msg)
	if is_host:
		_snap_t -= delta
		if _snap_t <= 0.0:
			_snap_t = 1.0 / SNAP_HZ
			_send_snapshot()
		_state_t -= delta
		if _state_t <= 0.0:
			_state_t = 1.0 / STATE_HZ
			send_state()


# ------------------------------------------------------------------ host -> guests
func register(m: Node) -> void:
	m.net_id = _next_id
	_next_id += 1
	by_id[m.net_id] = m
	send(_spawn_msg(m))


func _spawn_msg(m: Node) -> Dictionary:
	var d := {"t": "ms", "id": m.net_id, "ty": m.type_name, "x": snappedf(m.position.x, 0.1), "y": snappedf(m.position.y, 0.1),
		"tn": m.tint.to_html(), "sc": snappedf(m.scale_k, 0.01), "mu": m.mutations}
	if m.is_boss:
		d["bn"] = str(m.boss.name)
		d["bs"] = str(m.boss.get("sprite", m.type_name))
	return d


# Host: someone joined mid-run; show them every monster that's already out.
func _catch_up(id: int) -> void:
	await get_tree().create_timer(1.5).timeout   # let their scene load first
	for m in game.mobs:
		if is_instance_valid(m) and not m.dead and m.net_id != 0:
			send(_spawn_msg(m), id)
	send_state()


func _send_snapshot() -> void:
	var list := []
	for m in game.mobs:
		if not is_instance_valid(m) or m.dead or m.net_id == 0:
			continue
		var fl := (1 if m.phased or m.state == "vanish" else 0) | (2 if m.flash > 0.0 else 0) | (4 if m.enraged else 0) \
			| (8 if m.state in ["fuse", "tele_dash", "tele_charge"] else 0)
		list.append([m.net_id, snappedf(m.position.x, 0.1), snappedf(m.position.y, 0.1), int(100.0 * m.hp / maxf(m.max_hp, 0.01)), fl])
	send({"t": "mm", "m": list})


func send_state() -> void:
	send({"t": "st", "s": game.state, "r": game.round_no, "ts": game.to_spawn + game.portals_open,
		"sc": game.score, "k": game.kills, "d": snappedf(game._day_t, 0.1),
		"b": game.boss.net_id if game.boss and is_instance_valid(game.boss) else 0})


func died(m: Node, coins: int) -> void:
	by_id.erase(m.net_id)
	send({"t": "md", "id": m.net_id, "x": snappedf(m.position.x, 0.1), "y": snappedf(m.position.y, 0.1), "c": coins})


# Host: has everyone picked their perk? Then the next round starts.
func check_ready() -> void:
	if game.state != "upgrade" or not game.local_ready:
		return
	for id in Net.peers:
		if id != Net.my_id and not ready_ids.has(id) and players.has(id):
			return
	ready_ids.clear()
	game.start_next_round_mp()


# ------------------------------------------------------------------ messages
func _on_message(from: int, d: Dictionary) -> void:
	var t := str(d.get("t", ""))
	match t:
		"pp":
			var p := _puppet(from)
			var at := Vector2(float(d.x), float(d.y))
			var now := Time.get_ticks_msec() / 1000.0
			var snaps: Array = p.snaps
			if not p.root.visible or snaps.is_empty() or (snaps.back()[1] as Vector2).distance_to(at) > 200.0:
				snaps.clear()
				snaps.append([now - INTERP, at])
				p.root.visible = true
			elif now - float(snaps.back()[0]) > 2.5 / SEND_HZ:
				snaps.append([now - 1.0 / SEND_HZ, snaps.back()[1]])
			snaps.append([now, at])
			if snaps.size() > 12:
				snaps.pop_front()
			if int(d.get("c", 0)) != int(p.ch):
				p.ch = int(d.get("c", 0))
				Characters.apply(p.spr, p.ch)
				p.anim = ""
			var anim := str(d.get("a", ""))
			if anim != p.anim and p.spr.sprite_frames.has_animation(anim):
				p.anim = anim
				p.spr.play(anim)
			p.spr.flip_h = bool(d.get("h", false))
			var was_down: bool = p.down
			p.down = bool(d.get("dn", false))
			if p.down and not was_down:
				game.banner_small("%s is down!" % Net.peers.get(from, "A friend"))
				if is_host and everyone_down():
					game.game_over_mp()
		"hit":
			if is_host:
				var m = by_id.get(int(d.get("id", 0)))
				if m and is_instance_valid(m) and not m.dead:
					m.hit(float(d.get("d", 1.0)), Vector2(float(d.get("dx", 0)), float(d.get("dy", 0))), bool(d.get("cr", false)), true)
		"rdy":
			if is_host:
				ready_ids[from] = true
				check_ready()
		_:
			if from == 1 and not is_host:
				_from_host(t, d)


func _from_host(t: String, d: Dictionary) -> void:
	match t:
		"ms":
			game.spawn_copy(d)
		"mm":
			for row in d.get("m", []):
				var m = by_id.get(int(row[0]))
				if m and is_instance_valid(m):
					m.net_target = Vector2(float(row[1]), float(row[2]))
					m.hp = float(row[3])
					m.max_hp = 100.0
					var fl := int(row[4])
					m.phased = (fl & 1) != 0
					if (fl & 2) != 0:
						m.flash = 0.09
					m.enraged = (fl & 4) != 0
					m.state = "tele_dash" if (fl & 8) != 0 else ""
		"md":
			var m = by_id.get(int(d.id))
			by_id.erase(int(d.id))
			if m and is_instance_valid(m):
				m.position = Vector2(float(d.x), float(d.y))
				game.copy_died(m, int(d.get("c", 0)))
		"mc":
			for m in by_id.values():
				if is_instance_valid(m):
					game.copy_died(m, 0)
			by_id.clear()
		"hsb":
			for r in d.get("l", []):
				var sh: SurvivalShot = game.shoot(Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])),
					float(r[4]), Color.html(str(r[5])), true, false)
				sh.r = float(r[6])
				sh.slows = int(r[7]) == 1
				sh.homing = float(r[8])
				sh.life = float(r[9])
		"hx":
			game.explode(Vector2(float(d.x), float(d.y)), float(d.r), int(d.dm), true, false, null, 2.0, false)
		"hf":
			game.fire(Vector2(float(d.x), float(d.y)), false)
		"hw":
			game.telegraph(Vector2(float(d.x), float(d.y)), float(d.r), float(d.tm), false)
		"hl":
			game.telegraph_line(Vector2(float(d.x), float(d.y)), Vector2(float(d.dx), float(d.dy)), float(d.ln), float(d.tm), false)
		"bn":
			game.banner(str(d.get("tx", "")), Color.html(str(d.get("c", "ffd166"))), false)
		"st":
			game.apply_state(d)
		"over":
			game.game_over_mp(false)
		"start":   # the host started a new run
			get_tree().change_scene_to_file(Net.round_scene())
