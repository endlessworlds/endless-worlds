extends Node
class_name MultiplayerSync

# Runs inside the map while Net.active. Mirrors every other player as a coloured
# "puppet", shares hint pickups, shows chat bubbles and a live scoreboard.
# The host's game decides rounds; everyone else just follows "start" messages.

const SEND_HZ := 12.0
const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")
const BUBBLE_FRAME := preload("res://assets/ui/pixel/frame_normal.png")
static var UNSHADED := _unshaded()

static func _unshaded() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m

var map: Node2D
var player: Node2D
var _sprite: AnimatedSprite2D
var _puppets := {}           # id -> {root, spr, tag, bubble, target, score}
var _scores := {}            # id -> score
var _send_t := 0.0
var _last_sent := {}
var _since_sent := 0.0
var _board: VBoxContainer
var _banner: Label
var _chat_input: LineEdit
var round_over := false
var _local_deco := {}


func setup(map_node: Node2D, local_player: Node2D) -> void:
	map = map_node
	player = local_player
	_sprite = player.get_node("AnimatedSprite2D")
	_local_deco = _decorate(player, Net.my_id, Net.player_name, true)
	_build_ui()
	Net.message.connect(_on_message)
	Net.peer_joined.connect(func(id, n): _banner_say("%s joined" % n, Net.color_of(id)); _refresh_board())
	Net.peer_left.connect(_on_peer_left)
	Net.disconnected.connect(_on_disconnected)
	for id in Net.peers:
		if id != Net.my_id:
			_ensure_puppet(id)
	_refresh_board()


# ---------------------------------------------------------------- visuals
# Coloured ring at the feet + a low-opacity name tag above the head.
func _decorate(body: Node2D, id: int, pname: String, is_local: bool) -> Dictionary:
	var col := Net.color_of(id)
	var ring := _Ring.new()
	ring.color = col
	ring.z_index = -1
	ring.position = Vector2(0, 14)
	body.add_child(ring)

	var tag := Label.new()
	tag.text = pname + (" (you)" if is_local else "")
	tag.add_theme_font_override("font", FONT)
	tag.add_theme_font_size_override("font_size", 20)
	tag.add_theme_color_override("font_color", col)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	tag.add_theme_constant_override("outline_size", 4)
	tag.modulate.a = 0.6
	tag.material = UNSHADED  # readable at night: not darkened by the day/night tint
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(160, 22)
	tag.position = Vector2(-40, -46)
	tag.scale = Vector2(0.5, 0.5)       # map is scaled 2x; keep text crisp-small
	tag.z_index = 10
	body.add_child(tag)

	var bubble := Label.new()
	bubble.add_theme_font_override("font", FONT)
	bubble.add_theme_font_size_override("font_size", 22)
	bubble.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	var sb := StyleBoxTexture.new()  # same pixel frame as Bolt's bubble and icons
	sb.texture = BUBBLE_FRAME
	sb.set_texture_margin_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("normal", sb)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.scale = Vector2(0.5, 0.5)
	bubble.z_index = 11
	bubble.material = UNSHADED
	bubble.visible = false
	body.add_child(bubble)
	return {"tag": tag, "bubble": bubble}


func _ensure_puppet(id: int) -> Dictionary:
	if _puppets.has(id):
		return _puppets[id]
	var root := Node2D.new()
	root.add_to_group("actors")  # wildlife flees from teammates too
	var shadow = player.get_node_or_null("Shadow")
	if shadow:
		root.add_child(shadow.duplicate())
	var spr: AnimatedSprite2D = _sprite.duplicate()
	spr.modulate = Color.WHITE.lerp(Net.color_of(id), 0.28)
	spr.stop()
	root.add_child(spr)
	root.position = player.position
	root.visible = false  # until the first position arrives
	map.add_child(root)
	var deco := _decorate(root, id, str(Net.peers.get(id, "Player")), false)
	var torch := HandTorch.new(spr)
	if map.atmosphere:
		torch.max_energy = map.atmosphere.torch.max_energy
	root.add_child(torch)
	var p := {"root": root, "spr": spr, "tag": deco.tag, "bubble": deco.bubble, "target": root.position, "torch": torch}
	_puppets[id] = p
	return p


func _on_peer_left(id: int) -> void:
	var name := ""
	if _puppets.has(id):
		name = _puppets[id].tag.text
		_puppets[id].root.queue_free()
		_puppets.erase(id)
	_scores.erase(id)
	if name != "":
		_banner_say("%s left" % name, Color(0.8, 0.8, 0.8))
	_refresh_board()


# ---------------------------------------------------------------- network
func _process(delta: float) -> void:
	# Smoothly chase the last known position (12 Hz updates -> 60 fps motion).
	for p in _puppets.values():
		p.root.position = p.root.position.lerp(p.target, clampf(delta * 14.0, 0.0, 1.0))
		p.root.z_index = int((p.root.global_position.y + 32.0) / 4.0)
	_send_t -= delta
	_since_sent += delta
	if _send_t > 0.0:
		return
	_send_t = 1.0 / SEND_HZ
	var msg := {"t": "pos", "x": snappedf(player.position.x, 0.1), "y": snappedf(player.position.y, 0.1),
		"a": str(_sprite.animation), "f": _sprite.frame, "h": _sprite.flip_h, "s": Global.score,
		"tc": map.atmosphere != null and map.atmosphere.torch.lit, "z": snappedf(player.jump_h, 0.5)}
	if msg == _last_sent and _since_sent < 1.0:
		return  # idle: only a 1 Hz heartbeat
	_since_sent = 0.0
	_last_sent = msg.duplicate()
	Net.send(msg)
	_scores[Net.my_id] = Global.score


func _on_message(from: int, d: Dictionary) -> void:
	match str(d.get("t", "")):
		"pos":
			var p := _ensure_puppet(from)
			p.target = Vector2(float(d.x), float(d.y))
			if not p.root.visible:
				p.root.position = p.target
				p.root.visible = true
			if p.spr.sprite_frames.has_animation(str(d.a)):
				p.spr.animation = str(d.a)
				p.spr.frame = int(d.f)
			p.spr.flip_h = bool(d.get("h", false))
			p.spr.position.y = player.base_sprite_pos.y - float(d.get("z", 0.0))
			p.torch.set_lit(bool(d.get("tc", false)))
			if int(d.get("s", 0)) != int(_scores.get(from, -1)):
				_scores[from] = int(d.get("s", 0))
				_refresh_board()
		"chat":
			var p := _ensure_puppet(from)
			_show_bubble(p.bubble, str(d.get("text", "")).left(120))
		"hint":
			map.tasks.remove_hint(int(d.idx))
			_banner_say("%s found a hint!" % Net.peers.get(from, "Someone"), Net.color_of(from))
		"riddle":
			map.apply_remote_riddle(d.get("data", {}))
		"won":
			_round_won_by(from, str(d.get("name", "Someone")), str(d.get("answer", "")))
		"start":
			get_tree().change_scene_to_file("res://map_components/map.tscn")


func broadcast_hint(idx: int) -> void:
	Net.round_hints.append(idx)
	Net.send({"t": "hint", "idx": idx})


func local_won(answer: String) -> void:
	Net.send({"t": "won", "name": Net.player_name, "answer": answer})
	_round_won_by(Net.my_id, Net.player_name, answer)


func _round_won_by(id: int, pname: String, answer: String) -> void:
	if round_over:
		return
	round_over = true
	var who := "You" if id == Net.my_id else pname
	_banner_say("%s solved it!  %s\nNext round…" % [who, answer.to_upper()], Net.color_of(id), 6.0)
	if map.answer_popup.visible:
		map.answer_popup.close()
	if Net.is_host():
		await get_tree().create_timer(5.0).timeout
		if Net.active:
			Net.host_start_round(Global.selected_topic, int(Net.round_data.get("round", 1)) + 1)
			get_tree().change_scene_to_file("res://map_components/map.tscn")


func _on_disconnected(reason: String) -> void:
	_banner_say(reason, Color(1, 0.5, 0.4), 4.0)
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn")


# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.62)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = 76
	panel.offset_right = -20
	layer.add_child(panel)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 2)
	panel.add_child(_board)

	_banner = Label.new()
	_banner.add_theme_font_override("font", FONT)
	_banner.add_theme_font_size_override("font_size", 32)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 90
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_banner)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Say something…"
	_chat_input.max_length = 120
	_chat_input.add_theme_font_override("font", FONT)
	_chat_input.add_theme_font_size_override("font_size", 24)
	_chat_input.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_chat_input.offset_left = -260
	_chat_input.offset_right = 260
	_chat_input.offset_top = -120
	_chat_input.offset_bottom = -78
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_send_chat)
	layer.add_child(_chat_input)



func _refresh_board() -> void:
	if _board == null:
		return
	for c in _board.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "ROOM %s  ·  %d/%d" % [Net.room_code, Net.peers.size(), Net.MAX_PLAYERS]
	head.add_theme_font_override("font", FONT)
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_board.add_child(head)
	var ids: Array = Net.peers.keys()
	ids.sort_custom(func(a, b): return int(_scores.get(a, 0)) > int(_scores.get(b, 0)))
	for id in ids:
		var l := Label.new()
		l.text = "● %s%s   %d" % [Net.peers[id], " ★" if id == 1 else "", int(_scores.get(id, 0))]
		l.add_theme_font_override("font", FONT)
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Net.color_of(id))
		_board.add_child(l)


func _banner_say(text: String, col: Color, hold: float = 2.5) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _show_bubble(bubble: Label, text: String) -> void:
	if text.is_empty():
		return
	bubble.text = text
	# short lines stay on one line; long ones wrap at a fixed width
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text.length() > 26 else TextServer.AUTOWRAP_OFF
	bubble.custom_minimum_size = Vector2(300, 0) if text.length() > 26 else Vector2.ZERO
	bubble.size = Vector2.ZERO
	bubble.reset_size()
	# centered above the head (the label is drawn at half scale)
	bubble.position = Vector2(-bubble.size.x * 0.25, -52.0 - bubble.size.y * 0.5)
	bubble.visible = true
	bubble.modulate.a = 1.0
	var tw := bubble.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): bubble.visible = false)


func _open_chat() -> void:
	Global.input_locked = true
	_chat_input.visible = true
	_chat_input.text = ""
	_chat_input.grab_focus()


func _send_chat(text: String) -> void:
	Global.input_locked = false
	_chat_input.visible = false
	_chat_input.release_focus()
	text = text.strip_edges()
	if text.is_empty():
		return
	Net.send({"t": "chat", "text": text})
	_show_bubble(_local_deco.bubble, text)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T and not _chat_input.visible and not map.answer_popup.visible:
			_open_chat()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _chat_input.visible:
			Global.input_locked = false
			_chat_input.visible = false
			_chat_input.release_focus()
			get_viewport().set_input_as_handled()


func is_typing() -> bool:
	return _chat_input != null and _chat_input.visible


class _Ring extends Node2D:
	var color := Color.WHITE
	func _ready() -> void:
		scale = Vector2(1.0, 0.45)
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 32, Color(color, 0.85), 2.0, true)
		draw_circle(Vector2.ZERO, 10.0, Color(color, 0.18))
