extends CanvasLayer
class_name GameKeyboard

# The game's own on-screen keyboard for phones and tablets, used instead of the phone's
# keyboard (which covers half the screen, autocorrects code and behaves differently on
# every phone). It slides up whenever a text box or the code editor has focus and types
# into it by sending normal key events, so every field works exactly as with a real
# keyboard: Enter submits a LineEdit, adds a new line (with indent) in the code editor,
# Tab indents, ⌫ repeats while held.
#
# Created by the Screen autoload on touch devices. Fields can opt out with
#   control.set_meta("no_game_keyboard", true)   (e.g. answers that have their own keyboard)

signal height_changed(px: float)   # logical px covered at the bottom (0 when hidden)

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")

const LETTERS := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
const NUMS := [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
	[".", ",", "?", "!", "'", "_"]]
const SYMS := [["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
	["\\", "|", "~", "<", ">", "€", "£", "¥", "•", "`"],
	[".", ",", "?", "!", "'", "_"]]
const EMOJI := [["😀", "😂", "😅", "😍", "😎", "🤔", "😢", "😭", "😡", "🥳"],
	["👍", "👎", "👏", "🙏", "💪", "🙌", "🤝", "👀", "🤯", "💯"],
	["🎉", "🔥", "⭐", "❤", "✨", "✅", "❌", "💡", "🎯", "🏆"],
	["🤖", "🐍", "🌍", "🚀", "📚", "🎮", "💻", "🧠", "🐛", "🍕"]]
# Quick row shown above the letters while editing code.
const CODE_ROW := ["⇥", "(", ")", "[", "]", "{", "}", ":", "=", "\"", "'", "#", "←", "→"]

var target: Control            # the LineEdit / TextEdit being typed into
var _mode := "abc"             # abc | ABC | 123 | sym | emoji
var _caps_lock := false
var _panel: PanelContainer
var _rows: VBoxContainer
var _repeat: Timer
var _repeat_key := ""
var _shown := false
var _height := 0.0


func _ready() -> void:
	layer = 128   # above every page, popup and the coding screen
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.11, 0.97)
	sb.border_color = Color(1.0, 0.8, 0.28, 0.6)
	sb.border_width_top = 2
	sb.set_content_margin_all(6)
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_panel.add_child(_rows)

	_repeat = Timer.new()
	_repeat.one_shot = false
	_repeat.timeout.connect(func():
		_repeat.wait_time = 0.055
		if _repeat_key != "":
			_press(_repeat_key))
	add_child(_repeat)
	get_viewport().size_changed.connect(_rebuild)


func is_open() -> bool:
	return _shown


func covered_height() -> float:
	return _height if _shown else 0.0


# Called every frame by Screen: follow whichever text field has focus.
func _process(_delta: float) -> void:
	var f := get_viewport().gui_get_focus_owner()
	var want := f != null and _accepts(f)
	if want and f != target:
		target = f
		_mode = "abc"
		_rebuild()
	if want != _shown:
		_set_shown(want)


func _accepts(c: Control) -> bool:
	if not (c is LineEdit or c is TextEdit) or not c.is_visible_in_tree():
		return false
	if c.has_meta("no_game_keyboard"):
		return false
	if not c.editable:
		return false
	c.virtual_keyboard_enabled = false   # never pop the phone keyboard as well
	return true


func _set_shown(on: bool) -> void:
	_shown = on
	if not on:
		_stop_repeat()
		target = null
	_panel.visible = on
	_rebuild()
	if on:
		_panel.position.y = get_viewport().get_visible_rect().size.y
		create_tween().tween_property(_panel, "position:y", get_viewport().get_visible_rect().size.y - _height, 0.15) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_changed.emit(covered_height())


# ------------------------------------------------------------------ layout
func _key_h() -> float:
	var vp := get_viewport().get_visible_rect().size
	return clampf(vp.y * (0.06 if vp.y > vp.x else 0.08), 36.0, 60.0)


func _rebuild() -> void:
	if not _shown:
		_height = 0.0
		return
	for r in _rows.get_children():
		r.queue_free()
	var vp := get_viewport().get_visible_rect().size
	var h := _key_h()
	if target is TextEdit and _mode != "emoji":
		_row(CODE_ROW, h * 0.85, true)
	match _mode:
		"abc", "ABC":
			for i in LETTERS.size():
				var keys: Array = []
				for ch in LETTERS[i]:
					keys.append(ch.to_upper() if _mode == "ABC" else ch)
				if i == 2:
					keys.push_front("⇧")
					keys.append("⌫")
				_row(keys, h)
		"123", "sym":
			var src: Array = NUMS if _mode == "123" else SYMS
			_row(src[0], h)
			_row(src[1], h)
			var last: Array = ["#+=" if _mode == "123" else "123"]
			last.append_array(src[2])
			last.append("⌫")
			_row(last, h)
		"emoji":
			for r in EMOJI:
				_row(r, h)
	var bottom: Array = ["abc" if _mode in ["123", "sym", "emoji"] else "123",
		"😀" if _mode != "emoji" else "⌫", "space", "⏎", "⌄"]
	if _mode != "emoji":
		bottom.insert(2, ",")
		bottom.insert(4, ".")
	_row(bottom, h)
	var rows := _rows.get_child_count() - _count_freed()
	_height = rows * h + (rows - 1) * 6.0 + 18.0
	_panel.size = Vector2(vp.x, _height)
	_panel.position = Vector2(0, vp.y - _height)
	height_changed.emit(covered_height())


func _count_freed() -> int:
	var n := 0
	for r in _rows.get_children():
		if r.is_queued_for_deletion():
			n += 1
	return n


func _row(keys: Array, h: float, small := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_rows.add_child(row)
	for k in keys:
		var key: String = k
		var b := Button.new()
		b.text = _label_for(key)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, h)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = _width_for(key)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", int(h * (0.5 if small or key.length() > 1 else 0.62)))
		var special := key.length() > 1 or key in ["⇧", "⌫", "⏎", "⌄", "⇥", "←", "→"]
		var active := (key == "⇧" and _mode == "ABC")
		for st in ["normal", "hover", "pressed", "disabled"]:
			var s := StyleBoxFlat.new()
			s.set_corner_radius_all(7)
			s.content_margin_left = 2
			s.content_margin_right = 2
			var base := Color(0.2, 0.23, 0.33) if special else Color(0.32, 0.35, 0.47)
			if key == "⏎":
				base = Color(0.85, 0.42, 0.08)
			if active:
				base = Color(0.95, 0.7, 0.2)
			s.bg_color = base.lightened(0.25) if st == "pressed" else base
			s.border_width_bottom = 3
			s.border_color = base.darkened(0.45)
			b.add_theme_stylebox_override(st, s)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color(1, 0.97, 0.9))
		b.button_down.connect(_on_down.bind(key))
		b.button_up.connect(_stop_repeat)
		row.add_child(b)


func _label_for(key: String) -> String:
	match key:
		"space": return "space"
		"⇧": return "⇧" if not _caps_lock else "⇪"
	return key


func _width_for(key: String) -> float:
	match key:
		"space": return 4.0
		"⇧", "⌫", "abc", "123", "#+=": return 1.5
		"⏎": return 1.7
	return 1.0


# ------------------------------------------------------------------ typing
func _on_down(key: String) -> void:
	match key:
		"⇧":
			_mode = "abc" if _mode == "ABC" else "ABC"
			_rebuild()
		"123", "abc", "#+=", "😀":
			_mode = {"123": "123", "abc": "abc", "#+=": "sym", "😀": "emoji"}[key]
			_rebuild()
		"⌄":
			if target:
				target.release_focus()
		"⌫", "←", "→":
			_press(key)
			_repeat_key = key
			_repeat.wait_time = 0.4
			_repeat.start()
		_:
			_press(key)
			if _mode == "ABC" and key.length() == 1:
				_mode = "abc"   # one capital, like a phone
				_rebuild()


func _stop_repeat() -> void:
	_repeat_key = ""
	_repeat.stop()


func _press(key: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	match key:
		"⌫": _send_key(KEY_BACKSPACE)
		"⏎": _send_key(KEY_ENTER)
		"⇥": _send_key(KEY_TAB)
		"←": _send_key(KEY_LEFT)
		"→": _send_key(KEY_RIGHT)
		"space": _send_char(" ")
		_:
			for ch in key:
				_send_char(ch)


func _send_key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)


func _send_char(ch: String) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.unicode = ch.unicode_at(0)
		e.pressed = down
		Input.parse_input_event(e)
