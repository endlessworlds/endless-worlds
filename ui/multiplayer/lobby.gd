extends CanvasLayer
class_name Lobby

# "Play together" screen: create a room (you host) or join with a 5-letter code.
# Room view shows the code as big letter tiles and a 10-slot player grid.
# The host presses Start and everyone loads the same seeded world.

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")
const FRAME := preload("res://assets/ui/pixel/frame_normal.png")
const FRAME_HOVER := preload("res://assets/ui/pixel/frame_hover.png")
const FRAME_ACTIVE := preload("res://assets/ui/pixel/frame_active.png")
const GOLD := Color(1.0, 0.8, 0.28)
const CREAM := Color(0.96, 0.92, 0.82)
const MUTED := Color(0.66, 0.7, 0.82)

var get_topic: Callable
var mode := "island"          # "island" (riddle rounds) or "survival" (co-op waves)
var on_close: Callable        # optional: called after the lobby closes without starting
var _panel: PanelContainer
var _intro: Array[Control] = []   # subtitle + name row, hidden inside a room
var _name: LineEdit
var _code: LineEdit
var _status: Label
var _choose: VBoxContainer
var _room: VBoxContainer
var _code_tiles: HBoxContainer
var _grid: GridContainer
var _start: Button
var _waiting: Label
var _topic: LineEdit          # room topic: host edits, guests see it live
var _topic_chips: HBoxContainer
var _topic_row: HBoxContainer
var _share_note: Label
var _t := 0.0


static func open(parent: Node, topic_getter: Callable, p_mode := "island", p_on_close := Callable()) -> Lobby:
	var l := Lobby.new()
	l.layer = 70
	l.get_topic = topic_getter
	l.mode = p_mode
	l.on_close = p_on_close
	parent.add_child(l)
	return l


# Invite links (…/?room=CODE): open the lobby and join straight away.
func join_code(code: String) -> void:
	_code.text = code
	_on_join()


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
	_panel.add_theme_stylebox_override("panel", _box(FRAME, 30, 22))
	center.add_child(_panel)
	ScreenFit.attach(center, _panel)   # phones: shrink to fit (also while the keyboard is up)
	add_to_group("modal")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)

	# header: title + close
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _label("💀 Co-op Survival" if mode == "survival" else "🌐 Play Together", 54, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_shadow_color", Color(0.45, 0.2, 0.0, 0.9))
	title.add_theme_constant_override("shadow_offset_y", 3)
	head.add_child(title)
	var close := _button("✕", _on_close, FRAME, FRAME_HOVER)
	close.custom_minimum_size = Vector2(48, 48)
	close.tooltip_text = "Close"
	head.add_child(close)
	var sub := _label("Fight the waves together · up to 10 players" if mode == "survival" else "Same island · same riddle · up to 10 explorers", 24, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(sub)
	_intro.append(sub)

	# name
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	v.add_child(name_row)
	_intro.append(name_row)
	var nl := _label("Name", 26, CREAM)
	nl.custom_minimum_size = Vector2(70, 0)
	name_row.add_child(nl)
	_name = _field("Your name", 16)
	# Never picked a name (or still the old default "Explorer"): a random one, so players differ.
	var saved := Global.player_name.strip_edges()
	_name.text = saved if not saved in ["", "Explorer"] else Global.random_player_name()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name)

	# choose: two cards
	_choose = VBoxContainer.new()
	v.add_child(_choose)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	_choose.add_child(cards)

	var host_card := _card()
	cards.add_child(host_card)
	var hv: VBoxContainer = host_card.get_child(0)
	hv.add_child(_label("✨ Host", 32, GOLD))
	hv.add_child(_label("Start a room and share\nthe code with friends", 20, MUTED))
	hv.add_child(_button("Create room", _on_create, FRAME_ACTIVE, FRAME_HOVER))

	var join_card := _card()
	cards.add_child(join_card)
	var jv: VBoxContainer = join_card.get_child(0)
	jv.add_child(_label("🔍 Join", 32, GOLD))
	_code = _field("CODE", 5)
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.add_theme_font_size_override("font_size", 34)
	_code.text_changed.connect(func(t: String):
		var up := t.to_upper()
		if up != t:
			var caret := _code.caret_column
			_code.text = up
			_code.caret_column = caret)
	_code.text_submitted.connect(func(_t): _on_join())
	jv.add_child(_code)
	jv.add_child(_button("Join", _on_join, FRAME, FRAME_HOVER))

	# room view
	_room = VBoxContainer.new()
	_room.visible = false
	_room.add_theme_constant_override("separation", 12)
	v.add_child(_room)
	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", 14)
	_room.add_child(code_row)
	code_row.add_child(_label("Room code", 26, MUTED))
	_code_tiles = HBoxContainer.new()
	_code_tiles.add_theme_constant_override("separation", 6)
	code_row.add_child(_code_tiles)
	var share_row := HBoxContainer.new()
	share_row.alignment = BoxContainer.ALIGNMENT_CENTER
	share_row.add_theme_constant_override("separation", 10)
	_room.add_child(share_row)
	var share := _button("🔗 Share invite link", _share_link, FRAME_HOVER, FRAME_ACTIVE)
	share.add_theme_font_size_override("font_size", 24)
	share_row.add_child(share)
	_share_note = _label("Friends who open the link join this room", 20, MUTED)
	_room.add_child(_share_note)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	_room.add_child(_grid)
	var topic_row := HBoxContainer.new()
	topic_row.add_theme_constant_override("separation", 12)
	_room.add_child(topic_row)
	_topic_row = topic_row
	var tl := _label("Topic", 26, CREAM)
	tl.custom_minimum_size = Vector2(70, 0)
	topic_row.add_child(tl)
	_topic = _field("Any topic, e.g. Space", 40)
	_topic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topic.text_changed.connect(func(t: String): if Net.is_host(): Net.set_topic(t))
	topic_row.add_child(_topic)
	_topic_chips = HBoxContainer.new()
	_topic_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_topic_chips.add_theme_constant_override("separation", 8)
	_room.add_child(_topic_chips)
	for t in ["Python", "Space", "Biology", "History", "Math"]:
		var chip := _button(t, func():
			_topic.text = t
			Net.set_topic(t), FRAME, FRAME_HOVER)
		chip.add_theme_font_size_override("font_size", 22)
		chip.custom_minimum_size = Vector2(0, 40)
		_topic_chips.add_child(chip)
	_start = _button("Start game", _on_start, FRAME_ACTIVE, FRAME_HOVER)
	_start.add_theme_font_size_override("font_size", 34)
	_start.custom_minimum_size = Vector2(0, 60)
	_room.add_child(_start)
	_waiting = _label("", 26, CREAM)
	_room.add_child(_waiting)

	_status = _label("", 22, Color(1, 0.62, 0.5))
	v.add_child(_status)

	Net.connected.connect(_on_connected)
	Net.peer_joined.connect(func(_i, _n): _refresh())
	Net.peer_left.connect(func(_i): _refresh())
	Net.disconnected.connect(_on_disconnected)
	Net.message.connect(_on_message)
	Net.message.connect(func(_f, d): if str(d.get("t", "")) == "hello": _refresh())
	if Net.active:
		_on_connected(Net.my_id)

	# pop in
	_panel.pivot_offset = Vector2(310, 220)
	_panel.scale = Vector2(0.9, 0.9)
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)


func _process(delta: float) -> void:
	_t += delta
	if _room.visible and _start.visible:
		_start.pivot_offset = _start.size * 0.5
		_start.scale = Vector2.ONE * (1.0 + sin(_t * 4.0) * 0.02)
	if _room.visible and _waiting.visible:
		_waiting.text = "Waiting for the host" + ".".repeat(int(_t * 2.0) % 4)


# ------------------------------------------------------------------ widgets
func _box(tex: Texture2D, pad_x: int, pad_y: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(12)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _field(placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 52)
	e.add_theme_font_override("font", FONT)
	e.add_theme_font_size_override("font_size", 28)
	e.add_theme_color_override("font_color", CREAM)
	e.add_theme_color_override("font_placeholder_color", Color(MUTED, 0.6))
	e.add_theme_stylebox_override("normal", _box(FRAME, 16, 4))
	e.add_theme_stylebox_override("focus", _box(FRAME_HOVER, 16, 4))
	return e


func _button(t: String, cb: Callable, tex: Texture2D, hover: Texture2D) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 28)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, CREAM)
	b.add_theme_stylebox_override("normal", _box(tex, 18, 4))
	b.add_theme_stylebox_override("hover", _box(hover, 18, 4))
	b.add_theme_stylebox_override("pressed", _box(FRAME_ACTIVE, 18, 4))
	b.pressed.connect(cb)
	return b


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 190)
	p.add_theme_stylebox_override("panel", _box(FRAME, 18, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return p


func _slot(id: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 52)
	p.add_theme_stylebox_override("panel", _box(FRAME, 12, 2))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var av := TextureRect.new()
	av.texture = Characters.front(int(Net.peer_chars.get(id, 0)))
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av.custom_minimum_size = Vector2(30, 40)
	h.add_child(av)
	if id == 0:
		av.modulate = Color(1, 1, 1, 0.15)
		p.modulate.a = 0.45
		h.add_child(_label("open", 24, MUTED))
		return p
	var col := Net.color_of(id)
	var pname := _label(str(Net.peers[id]), 26, col)
	pname.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pname.clip_text = true
	h.add_child(pname)
	if id == 1:
		h.add_child(_label("★ host", 20, GOLD))
	elif id == Net.my_id:
		h.add_child(_label("you", 20, MUTED))
	return p


# ------------------------------------------------------------------ flow
func _remember_name() -> String:
	Global.player_name = _name.text.strip_edges() if not _name.text.strip_edges().is_empty() else Global.random_player_name()
	Global.save_game()
	return Global.player_name


func _on_create() -> void:
	_status.text = "Connecting…"
	Net.host_room(_remember_name())


func _on_join() -> void:
	if _code.text.strip_edges().length() < 4:
		_status.text = "Enter the 5-letter code"
		return
	_status.text = "Joining…"
	Net.join_room(_code.text, _remember_name())


func _on_connected(_id: int) -> void:
	_status.text = ""
	_choose.visible = false
	for c in _intro: c.visible = false
	_room.visible = true
	for c in _code_tiles.get_children():
		c.queue_free()
	for ch in Net.room_code:
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(46, 56)
		tile.add_theme_stylebox_override("panel", _box(FRAME_HOVER, 6, 0))
		tile.add_child(_label(ch, 40, GOLD))
		_code_tiles.add_child(tile)
	DisplayServer.clipboard_set(Net.invite_link())
	_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var ids: Array = Net.peers.keys()
	ids.sort()
	for i in Net.MAX_PLAYERS:
		_grid.add_child(_slot(ids[i] if i < ids.size() else 0))
	_start.visible = Net.is_host()
	_start.text = "Start game  (%d/%d)" % [Net.peers.size(), Net.MAX_PLAYERS]
	_waiting.visible = not Net.is_host()
	_topic.editable = Net.is_host()
	_topic_chips.visible = Net.is_host() and mode != "survival"
	_topic_row.visible = mode != "survival"
	if Net.is_host() and _topic.text.is_empty():
		var t: String = get_topic.call()
		_topic.text = t if not t.is_empty() else (Net.room_topic if not Net.room_topic.is_empty() else "")
		Net.set_topic(_topic.text)
	elif not Net.is_host():
		_topic.text = Net.room_topic
		_topic.placeholder_text = "The host picks the topic"


# Phones: the system share sheet (WhatsApp, Messages…); elsewhere copy the link.
func _share_link() -> void:
	var link := Net.invite_link()
	DisplayServer.clipboard_set(link)
	_share_note.text = "Link copied:  " + link
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""(function (u) {
			if (navigator.share) { navigator.share({title: 'Endless Worlds', text: 'Join my game!', url: u}).catch(function () {}); }
		})(%s)""" % JSON.stringify(link), true)


func _on_start() -> void:
	var topic: String = _topic.text.strip_edges()
	Net.host_start_round(topic if not topic.is_empty() else "programming", 1, mode)
	get_tree().change_scene_to_file(Net.round_scene())


func _on_message(_from: int, d: Dictionary) -> void:
	match str(d.get("t", "")):
		"start":
			get_tree().change_scene_to_file(Net.round_scene())
		"topic":
			if not Net.is_host():
				_topic.text = Net.room_topic


func _on_disconnected(reason: String) -> void:
	_choose.visible = true
	for c in _intro: c.visible = true
	_room.visible = false
	_status.text = reason


func _on_close() -> void:
	if Net.active:
		Net.leave()
	queue_free()
	if on_close.is_valid():
		on_close.call()
