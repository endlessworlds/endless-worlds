extends CanvasLayer
class_name Lobby

# "Play together" overlay: create a room (you become host) or join with a 5-letter code.
# Up to 10 players; the host presses Start and everyone loads the same seeded world.

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")

var get_topic: Callable
var _name: LineEdit
var _code: LineEdit
var _status: Label
var _choose: VBoxContainer
var _room: VBoxContainer
var _room_title: Label
var _players: VBoxContainer
var _start: Button


static func open(parent: Node, topic_getter: Callable) -> Lobby:
	var l := Lobby.new()
	l.layer = 40
	l.get_topic = topic_getter
	parent.add_child(l)
	return l


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.16, 0.96)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(26)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.3, 0.8, 1.0, 0.7)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 26
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	v.add_child(_label("Play Together", 52, Color(0.45, 0.85, 1.0)))
	v.add_child(_label("Same world · same riddle · up to 10", 24, Color(0.8, 0.85, 0.95)))

	_name = _field("Your name", 16)
	_name.text = Global.player_name
	v.add_child(_name)

	_choose = VBoxContainer.new()
	_choose.add_theme_constant_override("separation", 10)
	v.add_child(_choose)
	_choose.add_child(_button("Create room", _on_create, Color(0.15, 0.6, 0.35)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_code = _field("Room code", 5)
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.text_submitted.connect(func(_t): _on_join())
	row.add_child(_code)
	row.add_child(_button("Join", _on_join, Color(0.2, 0.45, 0.85)))
	_choose.add_child(row)

	_room = VBoxContainer.new()
	_room.visible = false
	_room.add_theme_constant_override("separation", 8)
	v.add_child(_room)
	_room_title = _label("", 40, Color(1, 0.85, 0.35))
	_room.add_child(_room_title)
	_players = VBoxContainer.new()
	_room.add_child(_players)
	_start = _button("Start", _on_start, Color(0.85, 0.42, 0.05))
	_room.add_child(_start)

	_status = _label("", 22, Color(1, 0.6, 0.5))
	v.add_child(_status)
	v.add_child(_button("Close", _on_close, Color(0.25, 0.27, 0.35)))

	Net.connected.connect(_on_connected)
	Net.peer_joined.connect(func(_i, _n): _refresh())
	Net.peer_left.connect(func(_i): _refresh())
	Net.disconnected.connect(_on_disconnected)
	Net.message.connect(_on_message)
	if Net.active:
		_on_connected(Net.my_id)


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _field(placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 48)
	e.add_theme_font_override("font", FONT)
	e.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.18)
	e.add_theme_stylebox_override("normal", sb)
	return e


func _button(t: String, cb: Callable, col: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, 50)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 30)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.bg_color = col if st == "normal" else col.lightened(0.15) if st == "hover" else col.darkened(0.2)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b


func _remember_name() -> String:
	Global.player_name = _name.text.strip_edges() if not _name.text.strip_edges().is_empty() else "Explorer"
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
	_name.editable = false
	_room.visible = true
	_room_title.text = "Code: %s" % Net.room_code
	DisplayServer.clipboard_set(Net.room_code)
	_refresh()


func _refresh() -> void:
	for c in _players.get_children():
		c.queue_free()
	var ids: Array = Net.peers.keys()
	ids.sort()
	for id in ids:
		var tag := " (host)" if id == 1 else ""
		tag += " — you" if id == Net.my_id else ""
		_players.add_child(_label("● %s%s" % [Net.peers[id], tag], 28, Net.color_of(id)))
	_start.visible = Net.is_host()
	if not Net.is_host():
		_status.text = "Waiting for host…"
	else:
		_status.text = "Code copied  ·  %d/%d" % [Net.peers.size(), Net.MAX_PLAYERS]
		_status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))


func _on_start() -> void:
	var topic: String = get_topic.call()
	Net.host_start_round(topic if not topic.is_empty() else "programming", 1)
	get_tree().change_scene_to_file("res://map_components/map.tscn")


func _on_message(_from: int, d: Dictionary) -> void:
	if str(d.get("t", "")) == "start":
		get_tree().change_scene_to_file("res://map_components/map.tscn")


func _on_disconnected(reason: String) -> void:
	_choose.visible = true
	_room.visible = false
	_name.editable = true
	_status.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	_status.text = reason


func _on_close() -> void:
	if Net.active:
		Net.leave()
	queue_free()
