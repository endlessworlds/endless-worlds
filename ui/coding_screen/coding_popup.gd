extends CanvasLayer
class_name CodingPopup

# Full-screen coding quest: illustrated mission card on the left, a Python editor with
# syntax highlighting + output terminal on the right. Light / dark theme toggle in the
# top bar (saved). Code is checked by the AI server (/api/evaluate_code).

const FONT_PATH = "res://assets/fonts/Jersey10-Regular.ttf"
const XP_REWARD := 100

const DARK := {
	"bg": Color("#0b0f1d"), "surface": Color("#151b30"), "surface2": Color("#1c2340"),
	"editor": Color("#0f1426"), "gutter": Color("#0c1020"), "border": Color("#2a3358"),
	"text": Color("#ece6d4"), "muted": Color("#8c95b6"), "accent": Color("#ffcc47"),
	"accent_text": Color("#1a1405"), "cyan": Color("#4fe0e0"), "success": Color("#5ee08a"),
	"danger": Color("#ff6b6b"), "warn": Color("#ffb347"), "line": Color(1, 1, 1, 0.05),
	"select": Color(0.31, 0.88, 0.88, 0.22), "chip": Color("#232b4d"),
	"kw": Color("#c792ea"), "str": Color("#c3e88d"), "num": Color("#f78c6c"),
	"comment": Color("#5c678c"), "fn": Color("#82aaff"), "sym": Color("#89ddff"), "code": Color("#e6e1cf"),
}
const LIGHT := {
	"bg": Color("#e7e0cd"), "surface": Color("#fbf8ef"), "surface2": Color("#f2ebd9"),
	"editor": Color("#fffdf6"), "gutter": Color("#f4efe1"), "border": Color("#d2c6a6"),
	"text": Color("#2a2438"), "muted": Color("#6f6a80"), "accent": Color("#d98f00"),
	"accent_text": Color("#fffaf0"), "cyan": Color("#0f8a8a"), "success": Color("#1f9d55"),
	"danger": Color("#d43c3c"), "warn": Color("#c06a00"), "line": Color(0, 0, 0, 0.045),
	"select": Color(0.06, 0.54, 0.54, 0.18), "chip": Color("#ece3cc"),
	"kw": Color("#8a3ab9"), "str": Color("#2f7d32"), "num": Color("#c25400"),
	"comment": Color("#9a9488"), "fn": Color("#1f5fbf"), "sym": Color("#0f6f8f"), "code": Color("#2a2438"),
}
const PY_KEYWORDS := ["def", "return", "if", "elif", "else", "for", "while", "in", "and", "or",
	"not", "is", "pass", "break", "continue", "import", "from", "as", "class", "lambda", "None",
	"True", "False", "try", "except", "finally", "with", "global", "print", "range", "len"]
const CATEGORY := {
	"craft": ["CRAFTING", "Add the two ingredient counts with + and return the total."],
	"brew": ["POTION BREWING", "Add water and magic together with + and return the result."],
	"mine": ["MINING", "Each ore gives the same number of gems — multiply ores by that number with *."],
	"detect": ["MOB DETECTION", "Use if / else: when distance < the limit return 'Danger', otherwise return 'Safe'. Strings need quotes!"],
	"generic": ["CODING", "Read the test cases: they show exactly what the function must return."],
}

var _font: Font
var _mono: Font
var _c: Dictionary = DARK
var _http: HTTPRequest
var _root: Control
var _margin: MarginContainer     # outer margin: grows at the bottom while the on-screen keyboard is up
var _body: BoxContainer          # quest + editor: row on wide screens, column in portrait
var _hearts: Node
var _current_q: Dictionary
var _category := "generic"
var _is_running := false

# state that survives a theme rebuild
var _code := ""
var _caret := Vector2i.ZERO
var _out_kind := "ready"       # what the terminal shows; re-rendered in the active palette
var _out_data := {}
var _status := "ready"          # ready | running | passed | failed | error
var _hint_open := false
var _solved := false
var _hero_tex: Texture2D        # main item of the quest (header tile / success card)
var _success_feedback := ""
var _quest_no := 1

# live nodes (recreated on rebuild)
var _editor: CodeEdit
var _output: RichTextLabel
var _run_btn: Button
var _status_pill: Label
var _status_dot: Panel
var _hearts_box: HBoxContainer
var _xp_chip: PanelContainer
var _editor_card: Control
var _test_dots: Array = []
var _hint_body: Label
var _hint_btn: Button
var _spin_t := 0.0


func open(hearts: Node = null) -> void:
	_hearts = hearts
	_font = load(FONT_PATH)
	_mono = _make_mono()
	layer = 50
	_c = LIGHT if Global.coding_theme == "light" else DARK
	Global.input_locked = true          # typing WASD in the editor must not walk the player
	_load_question()

	_http = HTTPRequest.new()
	_http.timeout = 30.0
	_http.request_completed.connect(_on_http_completed)
	add_child(_http)

	_build()
	_root.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_root, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	_focus_editor.call_deferred()


func close() -> void:
	_save_draft()
	Global.input_locked = false
	if _root == null:
		queue_free()
		return
	set_process(false)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _exit_tree() -> void:
	Global.input_locked = false


func _process(delta: float) -> void:
	if _is_running and _output:
		_spin_t += delta
		var dots := ".".repeat(1 + int(_spin_t * 3.0) % 3)
		_output.text = "[color=%s]> Evaluating your code with the AI compiler%s[/color]" % [_hex("muted"), dots]


# ------------------------------------------------------------------ question
func _load_question() -> void:
	if Global.current_coding_question.is_empty():
		Global.current_coding_question = Global.next_coding_question()
	_current_q = Global.current_coding_question
	_category = QuestArt.category_of(_current_q)
	_code = Global.coding_drafts.get(_current_q.get("title", ""), _current_q.get("startingCode", ""))
	_caret = Vector2i.ZERO
	_quest_no = Global.coding_solved_session + 1
	_solved = false
	_status = "ready"
	_out_kind = "ready"
	_out_data = {}
	_hint_open = false


func _save_draft() -> void:
	if _editor and not _current_q.is_empty() and not _solved:
		Global.coding_drafts[_current_q.get("title", "")] = _editor.text


# Swap the whole screen over to the quest in Global.current_coding_question.
func _show_current_quest() -> void:
	var old := _root
	_load_question()
	_build()
	_focus_editor()
	if old:
		old.queue_free()
	_root.modulate.a = 0.0
	_root.position.x = 40
	var tw := create_tween().set_parallel()
	tw.tween_property(_root, "modulate:a", 1.0, 0.25)
	tw.tween_property(_root, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _skip_quest() -> void:
	if _is_running:
		return
	_save_draft()
	Global.current_coding_question = Global.next_coding_question()
	_show_current_quest()


func _next_quest() -> void:
	_show_current_quest()


# ------------------------------------------------------------------ theme
func _is_dark() -> bool:
	return Global.coding_theme != "light"


func _hex(key: String) -> String:
	return "#" + (_c[key] as Color).to_html(false)


func _toggle_theme(to_light: bool) -> void:
	if (Global.coding_theme == "light") == to_light:
		return
	Global.coding_theme = "light" if to_light else "dark"
	Global.save_game()
	_c = LIGHT if to_light else DARK
	_capture_state()
	_root.queue_free()
	_build()
	if _solved:
		_show_success(_success_feedback)   # keep the "quest complete" card up
		return
	_focus_editor()
	_editor.set_caret_line(_caret.y)
	_editor.set_caret_column(_caret.x)


func _capture_state() -> void:
	if _editor:
		_code = _editor.text
		_caret = Vector2i(_editor.get_caret_column(), _editor.get_caret_line())


func _make_mono() -> Font:
	# Browsers expose no system fonts to the web build: ship our own monospace there.
	if OS.has_feature("web"):
		return load("res://assets/fonts/DejaVuSansMono-Code.ttf")
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "JetBrains Mono", "Menlo", "DejaVu Sans Mono", "Courier New", "monospace"])
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return sf


func _on_keyboard_changed(h: float) -> void:
	if is_instance_valid(_margin):
		_margin.add_theme_constant_override("margin_bottom", 16 + int(h))


func _on_layout_changed() -> void:
	if is_instance_valid(_body):
		_body.vertical = Screen.is_portrait()


# Phones: don't pop the on-screen keyboard over the quest before the player taps the editor.
func _focus_editor() -> void:
	if _editor and not Screen.is_touch:
		_editor.grab_focus()


func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), radius := 10, bw := 0, pad := Vector4(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.anti_aliasing = true
	return sb


func _card(pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _sb(_c.surface, _c.border, 12, 2, Vector4(pad, pad, pad, pad))
	sb.shadow_color = Color(0, 0, 0, 0.28 if _is_dark() else 0.08)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(t: String, size := 22, col_key := "text", font: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", _c[col_key])
	return l


func _chip(t: String, fg_key := "muted", bg_key := "chip", font: Font = null, size := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(_c[bg_key], Color(0, 0, 0, 0), 8, 0, Vector4(10, 3, 10, 3)))
	var l := _label(t, size, fg_key, font)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _section(t: String) -> Label:
	var l := _label(t, 20, "muted")
	l.add_theme_constant_override("outline_size", 0)
	return l


# A flat button with a vector icon drawn on top (crisp at any scale, no font glyphs).
func _icon_button(icon: String, tip: String, cb: Callable, active := false, sz := 40) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg: Color = _c.accent if active else _c.surface
	var hover_bg: Color = _c.accent if active else _c.chip
	b.add_theme_stylebox_override("normal", _sb(bg, _c.border, 9, 0 if active else 2))
	b.add_theme_stylebox_override("hover", _sb(hover_bg, _c.accent, 9, 2))
	b.add_theme_stylebox_override("pressed", _sb(hover_bg, _c.accent, 9, 2))
	b.pressed.connect(cb)
	var fg: Color = _c.accent_text if active else _c.text
	b.draw.connect(func():
		var col: Color = _c.danger if (icon == "close" and b.is_hovered()) else fg
		_draw_icon(b, icon, col, hover_bg if b.is_hovered() else bg))
	return b


func _draw_icon(b: Control, icon: String, col: Color, bg: Color) -> void:
	var c := b.size * 0.5
	var r := minf(b.size.x, b.size.y) * 0.22
	match icon:
		"close":
			b.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, 3.0, true)
			b.draw_line(c + Vector2(r, -r), c + Vector2(-r, r), col, 3.0, true)
		"sun":
			b.draw_circle(c, r * 0.62, col)
			for i in 8:
				var d := Vector2.RIGHT.rotated(i * TAU / 8)
				b.draw_line(c + d * r * 0.95, c + d * r * 1.35, col, 2.0, true)
		"moon":
			b.draw_circle(c, r * 1.05, col)
			b.draw_circle(c + Vector2(r * 0.55, -r * 0.45), r * 0.9, bg)
		"play":
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r), c + Vector2(r, 0), c + Vector2(-r * 0.7, r)]), col)
		"skip":
			for k in 2:
				var o := Vector2(-r * 1.0 + k * r * 0.9, 0)
				b.draw_colored_polygon(PackedVector2Array([c + o + Vector2(0, -r * 0.8), c + o + Vector2(r * 0.9, 0), c + o + Vector2(0, r * 0.8)]), col)
			b.draw_rect(Rect2(c + Vector2(r * 0.85, -r * 0.8), Vector2(2.5, r * 1.6)), col)
		"reset":
			b.draw_arc(c, r, -PI * 0.15, PI * 1.45, 24, col, 2.5, true)
			var tip := c + Vector2.RIGHT.rotated(-PI * 0.15) * r
			b.draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, -6), tip + Vector2(5, -3), tip + Vector2(-1, 5)]), col)


# ------------------------------------------------------------------ layout
func _build() -> void:
	_test_dots.clear()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = Theme.new()
	_root.theme.default_font = _font
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = _c.bg
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_margin = margin
	_on_keyboard_changed(Screen.keyboard_cover())
	if not Screen.keyboard_changed.is_connected(_on_keyboard_changed):
		Screen.keyboard_changed.connect(_on_keyboard_changed)
	_root.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var art := QuestArt.new()
	art.setup(_current_q, _is_dark())
	col.add_child(_build_top_bar(art))

	# Side by side on wide screens; stacked (quest above editor) on a portrait phone.
	var body := BoxContainer.new()
	body.vertical = Screen.is_portrait()
	_body = body
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)
	body.add_child(_build_left(art))
	body.add_child(_build_right())
	for side in body.get_children():
		(side as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not Screen.layout_changed.is_connected(_on_layout_changed):
		Screen.layout_changed.connect(_on_layout_changed)

	_set_status(_status)
	_refresh_hearts()


func _build_top_bar(art: QuestArt) -> Control:
	var bar := PanelContainer.new()
	var sb := _sb(_c.surface2, _c.border, 12, 2, Vector4(12, 8, 10, 8))
	sb.border_width_bottom = 4
	sb.border_color = _c.border
	bar.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	bar.add_child(h)

	# icon tile with the quest's main item
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(52, 52)
	tile.add_theme_stylebox_override("panel", _sb(_c.chip, _c.accent, 10, 2, Vector4(6, 6, 6, 6)))
	var tex := art.hero_texture()
	_hero_tex = tex
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.add_child(tr)
	else:
		var il := _label(str(_current_q.get("icon", "💻")), 34)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_child(il)
	h.add_child(tile)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_child(_label("QUEST %d  ·  %s" % [_quest_no, CATEGORY[_category][0]], 18, "muted"))
	var t := _label(str(_current_q.get("title", "Unknown quest")), 34, "accent")
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(t)
	h.add_child(titles)

	_hearts_box = HBoxContainer.new()
	_hearts_box.add_theme_constant_override("separation", 3)
	_hearts_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hearts_box.tooltip_text = "Lives — a failed run costs one heart"
	h.add_child(_hearts_box)

	_xp_chip = _chip("+%d XP" % XP_REWARD, "accent_text", "accent", null, 22)
	_xp_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_chip.tooltip_text = "Reward for passing all tests"
	h.add_child(_xp_chip)

	# light / dark segmented toggle
	var seg := PanelContainer.new()
	seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seg.add_theme_stylebox_override("panel", _sb(_c.chip, _c.border, 11, 2, Vector4(3, 3, 3, 3)))
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 2)
	seg.add_child(sh)
	var is_light := Global.coding_theme == "light"
	sh.add_child(_icon_button("sun", "Light mode", _toggle_theme.bind(true), is_light, 36))
	sh.add_child(_icon_button("moon", "Dark mode", _toggle_theme.bind(false), not is_light, 36))
	h.add_child(seg)

	var sep := VSeparator.new()
	sep.add_theme_stylebox_override("separator", _sb(_c.border, Color(0, 0, 0, 0), 0))
	sep.custom_minimum_size = Vector2(2, 0)
	h.add_child(sep)

	var close_btn := _icon_button("close", "Close (Esc) — your code is kept", close, false, 44)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.shortcut = Shortcut.new()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	close_btn.shortcut.events = [esc]
	close_btn.shortcut_in_tooltip = false
	h.add_child(close_btn)
	return bar


func _build_left(art: QuestArt) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = 1.0
	v.add_theme_constant_override("separation", 12)

	var art_card := _card(6)
	art_card.add_child(art)
	v.add_child(art_card)

	var card := _card(16)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 8)
	scroll.add_child(c)

	c.add_child(_section("YOUR MISSION"))
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.add_theme_font_override("normal_font", _font)
	desc.add_theme_font_override("bold_font", _font)
	desc.add_theme_font_size_override("normal_font_size", 26)
	desc.add_theme_font_size_override("bold_font_size", 26)
	desc.add_theme_color_override("default_color", _c.text)
	desc.text = _highlight_numbers(str(_current_q.get("desc", "")))
	c.add_child(desc)

	# function signature
	var sig_line := str(_current_q.get("startingCode", "")).get_slice("\n", 0).trim_suffix(":")
	var sig := PanelContainer.new()
	sig.add_theme_stylebox_override("panel", _sb(_c.editor, _c.border, 8, 1, Vector4(12, 6, 12, 6)))
	var sig_l := RichTextLabel.new()
	sig_l.bbcode_enabled = true
	sig_l.fit_content = true
	sig_l.scroll_active = false
	sig_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	sig_l.add_theme_font_override("normal_font", _mono)
	sig_l.add_theme_font_size_override("normal_font_size", 17)
	sig_l.text = _color_signature(sig_line)
	sig.add_child(sig_l)
	c.add_child(sig)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	c.add_child(gap)
	c.add_child(_section("TEST CASES"))
	var fn := str(_current_q.get("funcName", "f"))
	for tc in _current_q.get("testCases", []):
		c.add_child(_test_row(fn, tc))

	# hint (collapsed by default)
	_hint_btn = Button.new()
	_hint_btn.flat = true
	_hint_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_btn.focus_mode = Control.FOCUS_NONE
	_hint_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hint_btn.add_theme_font_override("font", _font)
	_hint_btn.add_theme_font_size_override("font_size", 22)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_hint_btn.add_theme_color_override(k, _c.cyan)
	_hint_btn.pressed.connect(_toggle_hint)
	c.add_child(_hint_btn)
	_hint_body = _label("💡 " + CATEGORY[_category][1], 22, "text")
	_hint_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _sb(_c.chip, _c.cyan, 8, 0, Vector4(12, 8, 12, 8)))
	(hint_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left = 4
	hint_panel.add_child(_hint_body)
	c.add_child(hint_panel)
	_hint_body.set_meta("panel", hint_panel)
	_apply_hint()
	return v


func _test_row(fn: String, tc: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _sb(_c.surface2, _c.border, 8, 1, Vector4(10, 6, 12, 6)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	_test_dots.append(dot)
	var args := []
	for a in tc.get("input", []):
		args.append(_py_repr(a))
	var call_l := _label("%s(%s)" % [fn, ", ".join(args)], 17, "code", _mono)
	call_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(call_l)
	h.add_child(_label("→", 24, "muted"))
	var expected := _chip(_py_repr(tc.get("expected")), "accent", "chip", _mono, 17)
	expected.custom_minimum_size = Vector2(96, 0)
	(expected.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(expected)
	return row


func _build_right() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = 1.3
	v.add_theme_constant_override("separation", 12)

	# ---- editor card
	var ed_card := _card(0)
	ed_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ed_card.size_flags_stretch_ratio = 1.8
	_editor_card = ed_card
	v.add_child(ed_card)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 0)
	ed_card.add_child(ev)

	var tabs := PanelContainer.new()
	var tsb := _sb(_c.surface2, Color(0, 0, 0, 0), 12, 0, Vector4(12, 6, 8, 6))
	tsb.corner_radius_bottom_left = 0
	tsb.corner_radius_bottom_right = 0
	tabs.add_theme_stylebox_override("panel", tsb)
	ev.add_child(tabs)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 8)
	tabs.add_child(th)
	var tab := _chip("● main.py", "text", "editor", _mono, 15)
	(tab.get_theme_stylebox("panel") as StyleBoxFlat).border_color = _c.accent
	(tab.get_theme_stylebox("panel") as StyleBoxFlat).border_width_top = 3
	th.add_child(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(spacer)
	th.add_child(_chip("PYTHON 3", "cyan", "chip", null, 18))
	th.add_child(_icon_button("reset", "Reset to starter code", _reset_code, false, 34))
	th.add_child(_icon_button("skip", "Skip to another quest", _skip_quest, false, 34))

	_editor = CodeEdit.new()
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.text = _code
	_editor.gutters_draw_line_numbers = true
	_editor.gutters_zero_pad_line_numbers = false
	_editor.indent_automatic = true
	_editor.indent_use_spaces = true
	_editor.indent_size = 4
	_editor.auto_brace_completion_enabled = true
	_editor.auto_brace_completion_highlight_matching = true
	_editor.highlight_current_line = true
	_editor.highlight_all_occurrences = true
	_editor.caret_blink = true
	_editor.caret_type = TextEdit.CARET_TYPE_LINE
	_editor.scroll_smooth = true
	_editor.add_theme_constant_override("line_spacing", 8)
	_editor.add_theme_font_override("font", _mono)
	_editor.add_theme_font_size_override("font_size", 19)
	var esb := _sb(_c.editor, Color(0, 0, 0, 0), 0, 0, Vector4(10, 10, 10, 10))
	_editor.add_theme_stylebox_override("normal", esb)
	_editor.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	_editor.add_theme_color_override("background_color", _c.editor)
	_editor.add_theme_color_override("font_color", _c.code)
	_editor.add_theme_color_override("current_line_color", _c.line)
	_editor.add_theme_color_override("line_number_color", _c.muted)
	_editor.add_theme_color_override("caret_color", _c.accent)
	_editor.add_theme_color_override("selection_color", _c.select)
	_editor.add_theme_color_override("word_highlighted_color", _c.select)
	_editor.add_theme_color_override("brace_mismatch_color", _c.danger)
	_editor.add_theme_color_override("font_placeholder_color", _c.muted)
	_editor.placeholder_text = "# write your Python solution here"
	_editor.syntax_highlighter = _make_highlighter()
	_editor.gui_input.connect(_on_editor_input)
	_editor.text_changed.connect(func():
		if _status in ["passed", "failed", "error"]:
			_set_status("ready"))
	ev.add_child(_editor)

	# footer with run button
	var foot := PanelContainer.new()
	var fsb := _sb(_c.surface2, Color(0, 0, 0, 0), 12, 0, Vector4(14, 8, 8, 8))
	fsb.corner_radius_top_left = 0
	fsb.corner_radius_top_right = 0
	foot.add_theme_stylebox_override("panel", fsb)
	ev.add_child(foot)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 10)
	foot.add_child(fh)
	var keys := _label("Tap RUN CODE to test" if Screen.is_touch else "Ctrl + Enter  to run     ·     Esc  to close", 19, "muted")
	keys.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	keys.clip_text = true
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fh.add_child(keys)
	_run_btn = Button.new()
	_run_btn.text = "     RUN CODE"
	_run_btn.custom_minimum_size = Vector2(170, 44)
	_run_btn.focus_mode = Control.FOCUS_NONE
	_run_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_run_btn.add_theme_font_override("font", _font)
	_run_btn.add_theme_font_size_override("font_size", 28)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_run_btn.add_theme_color_override(k, _c.accent_text)
	_run_btn.add_theme_stylebox_override("normal", _sb(_c.accent, Color(0, 0, 0, 0.25), 10, 0))
	var hov := _sb((_c.accent as Color).lightened(0.12), Color(0, 0, 0, 0), 10, 0)
	_run_btn.add_theme_stylebox_override("hover", hov)
	_run_btn.add_theme_stylebox_override("pressed", _sb((_c.accent as Color).darkened(0.12), Color(0, 0, 0, 0), 10, 0))
	_run_btn.add_theme_stylebox_override("disabled", _sb((_c.accent as Color).darkened(0.3), Color(0, 0, 0, 0), 10, 0))
	_run_btn.pressed.connect(_on_run_pressed)
	_run_btn.draw.connect(func():
		if not _is_running:
			_draw_icon_at(_run_btn, Vector2(26, _run_btn.size.y * 0.5), _c.accent_text))
	fh.add_child(_run_btn)

	# ---- terminal card
	var term := _card(0)
	term.size_flags_vertical = Control.SIZE_EXPAND_FILL
	term.size_flags_stretch_ratio = 1.0
	v.add_child(term)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	term.add_child(tv)
	var thead := PanelContainer.new()
	var hsb := _sb(_c.surface2, Color(0, 0, 0, 0), 12, 0, Vector4(14, 6, 12, 6))
	hsb.corner_radius_bottom_left = 0
	hsb.corner_radius_bottom_right = 0
	thead.add_theme_stylebox_override("panel", hsb)
	tv.add_child(thead)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	thead.add_child(hh)
	_status_dot = Panel.new()
	_status_dot.custom_minimum_size = Vector2(12, 12)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(_status_dot)
	var tl := _label("OUTPUT", 22, "muted")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(tl)
	_status_pill = _label("READY", 20, "muted")
	hh.add_child(_status_pill)

	var out_bg := PanelContainer.new()
	out_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var osb := _sb(_c.editor, Color(0, 0, 0, 0), 12, 0, Vector4(14, 10, 14, 10))
	osb.corner_radius_top_left = 0
	osb.corner_radius_top_right = 0
	out_bg.add_theme_stylebox_override("panel", osb)
	tv.add_child(out_bg)
	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.add_theme_font_override("normal_font", _mono)
	_output.add_theme_font_override("bold_font", _mono)
	_output.add_theme_font_size_override("normal_font_size", 16)
	_output.add_theme_font_size_override("bold_font_size", 16)
	_output.add_theme_color_override("default_color", _c.code)
	_output.text = _render_out()
	out_bg.add_child(_output)
	return v


func _draw_icon_at(b: Control, c: Vector2, col: Color) -> void:
	var r := 8.0
	b.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r), c + Vector2(r, 0), c + Vector2(-r * 0.7, r)]), col)


func _make_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = _c.num
	h.symbol_color = _c.sym
	h.function_color = _c.fn
	h.member_variable_color = _c.code
	for kw in PY_KEYWORDS:
		h.add_keyword_color(kw, _c.kw)
	h.add_color_region("#", "", _c.comment, true)
	h.add_color_region("\"", "\"", _c["str"])
	h.add_color_region("'", "'", _c["str"])
	return h


# ------------------------------------------------------------------ text helpers
func _py_repr(v) -> String:
	if typeof(v) == TYPE_STRING:
		return "'%s'" % v
	if typeof(v) == TYPE_FLOAT and v == floor(v):
		return str(int(v))
	if typeof(v) == TYPE_BOOL:
		return "True" if v else "False"
	return str(v)


func _highlight_numbers(s: String) -> String:
	s = s.replace("[", "[lb]")
	if not s.is_empty():
		s = s[0].to_upper() + s.substr(1)   # some quest texts start lowercase ("creeper are near!")
	var re := RegEx.create_from_string("(\\d+|'[^']*')")
	return re.sub(s, "[color=%s]$1[/color]" % _hex("accent"), true)


func _color_signature(line: String) -> String:
	var m := RegEx.create_from_string("^def\\s+(\\w+)\\s*\\((.*)\\)").search(line)
	if not m:
		return "[color=%s]%s[/color]" % [_hex("code"), line]
	return "[color=%s]def[/color] [color=%s]%s[/color][color=%s]([/color][color=%s]%s[/color][color=%s])[/color]" % [
		_hex("kw"), _hex("fn"), m.get_string(1), _hex("sym"), _hex("code"), m.get_string(2), _hex("sym")]


# ------------------------------------------------------------------ interactions
func _toggle_hint() -> void:
	_hint_open = not _hint_open
	_apply_hint()
	if _hint_open:   # bring the hint into view once the container has re-laid out
		var panel: Control = _hint_body.get_meta("panel")
		await get_tree().process_frame
		if is_instance_valid(panel):
			var sc := panel.get_parent().get_parent() as ScrollContainer
			if sc:
				sc.ensure_control_visible(panel)


func _apply_hint() -> void:
	_hint_btn.text = ("▾  Hide hint" if _hint_open else "▸  Need a hint?")
	(_hint_body.get_meta("panel") as Control).visible = _hint_open


func _reset_code() -> void:
	_editor.text = str(_current_q.get("startingCode", ""))
	_editor.set_caret_line(_editor.get_line_count() - 1)
	_editor.set_caret_column(_editor.get_line(_editor.get_line_count() - 1).length())
	_focus_editor()


func _on_editor_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER] and (event.ctrl_pressed or event.meta_pressed):
		_editor.accept_event()
		_on_run_pressed()


func _set_status(s: String) -> void:
	_status = s
	if _status_pill == null:
		return
	var map := {
		"ready": ["READY", "muted"], "running": ["RUNNING…", "warn"], "passed": ["ALL TESTS PASSED", "success"],
		"failed": ["TESTS FAILED", "danger"], "error": ["ERROR", "danger"],
	}
	var e: Array = map.get(s, map.ready)
	_status_pill.text = e[0]
	_status_pill.add_theme_color_override("font_color", _c[e[1]])
	_status_dot.add_theme_stylebox_override("panel", _sb(_c[e[1]], Color(0, 0, 0, 0), 6))
	for d in _test_dots:
		var key := "success" if s == "passed" else ("danger" if s == "failed" else "border")
		(d as Panel).add_theme_stylebox_override("panel", _sb(_c[key], Color(0, 0, 0, 0), 6))
	if _run_btn:
		_run_btn.disabled = s == "running"
		_run_btn.text = "  RUNNING…" if s == "running" else "     RUN CODE"


func _refresh_hearts() -> void:
	if _hearts_box == null:
		return
	for ch in _hearts_box.get_children():
		ch.queue_free()
	if _hearts == null or not ("current_hearts" in _hearts):
		_hearts_box.visible = false
		return
	var full: Texture2D = load("res://assets/ui/heart_full.png")
	var empty: Texture2D = load("res://assets/ui/heart_empty.png")
	var mx: int = _hearts.max_hearts if "max_hearts" in _hearts else 5
	for i in mx:
		var tr := TextureRect.new()
		tr.texture = full if i < _hearts.current_hearts else empty
		tr.custom_minimum_size = Vector2(26, 26)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hearts_box.add_child(tr)


func _shake(n: Control) -> void:
	var p := n.position
	var tw := create_tween()
	for i in 6:
		tw.tween_property(n, "position:x", p.x + (8.0 if i % 2 == 0 else -8.0) * (1.0 - i / 6.0), 0.04)
	tw.tween_property(n, "position:x", p.x, 0.04)


func _pulse(n: Control) -> void:
	n.pivot_offset = n.size * 0.5
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector2.ONE, 0.25)


func _write(kind: String, data := {}) -> void:
	_out_kind = kind
	_out_data = data
	_output.text = _render_out()


func _render_out() -> String:
	var fb := str(_out_data.get("feedback", "")).replace("[", "[lb]")
	match _out_kind:
		"passed":
			return "[color=%s][b]✓ ALL TESTS PASSED!  +%d XP[/b][/color]\n\n[color=%s]Compiler note:[/color] %s\n\n[color=%s]> Quest complete — the next one is ready.[/color]" % [
				_hex("success"), XP_REWARD, _hex("cyan"), fb, _hex("muted")]
		"failed":
			return "[color=%s][b]✗ Not quite yet.[/b][/color]\n\n%s\n\n[color=%s]Tip: open the hint on the left if you're stuck.[/color]" % [
				_hex("danger"), fb, _hex("muted")]
		"request_error":
			return "[color=%s]✗ Could not reach the code checker (request error %d).[/color]" % [_hex("danger"), _out_data.get("code", 0)]
		"http_error":
			return "[color=%s]✗ Code checker failed (HTTP %d).[/color]\n[color=%s]%s[/color]" % [
				_hex("danger"), _out_data.get("code", 0), _hex("muted"), fb if fb != "" else "Is the AI server running?"]
		"invalid":
			return "[color=%s]✗ Invalid response from the code checker.[/color]" % _hex("danger")
	return "[color=%s]> Ready. Write your solution, then press RUN (Ctrl+Enter).[/color]" % _hex("muted")


# ------------------------------------------------------------------ run / evaluate
func _on_run_pressed() -> void:
	if _is_running or _current_q.is_empty():
		return
	_is_running = true
	_spin_t = 0.0
	_set_status("running")
	_save_draft()

	var payload := {
		"question_title": _current_q.get("title", ""),
		"question_desc": _current_q.get("desc", ""),
		"expected_output": str(_current_q.get("testCases", [])),
		"user_code": _editor.text,
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(Global.api_url("/api/evaluate_code"), headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_finish_run()
		_set_status("error")
		_write("request_error", {"code": err})


func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_finish_run()
	if response_code < 200 or response_code >= 300:
		_set_status("error")
		_write("http_error", {"code": response_code, "feedback": body.get_string_from_utf8()})
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY:
		_set_status("error")
		_write("invalid")
		return

	var feedback := str(json.get("feedback", ""))
	if json.get("passed", false):
		_set_status("passed")
		_write("passed", {"feedback": feedback})
		_pulse(_xp_chip)
		_solved = true
		Global.coding_drafts.erase(_current_q.get("title", ""))
		Global.add_score(XP_REWARD)
		Global.stats.total_games += 1
		Global.stats.total_wins += 1
		Global.save_game()
		Global.coding_solved_session += 1
		# deal the next quest now, so it is also waiting at any terminal if the player leaves
		Global.current_coding_question = Global.next_coding_question()
		_show_success(feedback)
	else:
		_set_status("failed")
		_write("failed", {"feedback": feedback})
		_shake(_editor_card)
		if _hearts and _hearts.has_method("damage"):
			_hearts.damage(1)
			_refresh_hearts()
			if "current_hearts" in _hearts and _hearts.current_hearts <= 0:
				close()


# "Quest complete" card over the screen: reward, compiler note, a preview of the next
# quest and two ways on — straight into it (Enter) or back out to the world (Esc).
func _show_success(feedback: String) -> void:
	_success_feedback = feedback
	if _editor:
		_editor.release_focus()
		_editor.editable = false
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(_c.bg as Color, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)

	var card := _card(28)
	card.custom_minimum_size = Vector2(580, 0)
	(card.get_theme_stylebox("panel") as StyleBoxFlat).border_color = _c.accent
	(card.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(3)
	center.add_child(card)
	ScreenFit.attach(center, card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	if _hero_tex:
		var tile_c := CenterContainer.new()
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(104, 104)
		tile.add_theme_stylebox_override("panel", _sb(_c.chip, _c.accent, 16, 3, Vector4(14, 14, 14, 14)))
		var tr := TextureRect.new()
		tr.texture = _hero_tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.add_child(tr)
		tile_c.add_child(tile)
		v.add_child(tile_c)

	var title := _label("QUEST COMPLETE!", 56, "accent")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var n := Global.coding_solved_session
	var sub := _label("+%d XP   ·   Score %d   ·   %d quest%s solved" % [XP_REWARD, Global.score, n, "" if n == 1 else "s"], 24, "success")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if feedback != "":
		var note := _label(feedback, 21, "muted")
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(520, 0)
		note.max_lines_visible = 3
		v.add_child(note)

	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _sb(_c.border, Color(0, 0, 0, 0), 0))
	sep.add_theme_constant_override("separation", 14)
	v.add_child(sep)

	# up next preview
	var nq: Dictionary = Global.current_coding_question
	if not nq.is_empty():
		var up := _label("UP NEXT", 20, "muted")
		up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(up)
		var row_c := CenterContainer.new()
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _sb(_c.surface2, _c.border, 10, 2, Vector4(12, 8, 18, 8)))
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 12)
		row.add_child(rh)
		var peek := QuestArt.new()
		peek.setup(nq, _is_dark())
		var ntex := peek.hero_texture()
		peek.free()
		if ntex:
			var nt := TextureRect.new()
			nt.texture = ntex
			nt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			nt.custom_minimum_size = Vector2(44, 44)
			nt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			nt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rh.add_child(nt)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", -4)
		nv.add_child(_label(CATEGORY[QuestArt.category_of(nq)][0], 17, "muted"))
		nv.add_child(_label(str(nq.get("title", "")), 30, "text"))
		rh.add_child(nv)
		row_c.add_child(row)
		v.add_child(row_c)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	v.add_child(btns)
	btns.add_child(_text_button("Explore world", close, false))
	var next_btn := _text_button("Next quest  ▸", _next_quest, true)
	btns.add_child(next_btn)
	var keys := _label("Enter  next quest     ·     Esc  back to the world", 18, "muted")
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(keys)

	# pop in
	card.pivot_offset = card.get_combined_minimum_size() * 0.5
	card.scale = Vector2(0.9, 0.9)
	ov.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(ov, "modulate:a", 1.0, 0.2)
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	next_btn.grab_focus.call_deferred()


func _text_button(t: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(200, 50)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 28)
	var fg: Color = _c.accent_text if primary else _c.text
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	var base: Color = _c.accent if primary else _c.surface2
	b.add_theme_stylebox_override("normal", _sb(base, _c.border, 10, 0 if primary else 2))
	b.add_theme_stylebox_override("hover", _sb(base.lightened(0.1), _c.accent, 10, 2))
	b.add_theme_stylebox_override("pressed", _sb(base.darkened(0.1), _c.accent, 10, 2))
	b.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), _c.cyan if primary else Color(0, 0, 0, 0), 12, 2 if primary else 0))
	b.pressed.connect(cb)
	return b


func _finish_run() -> void:
	_is_running = false
	if _status == "running":
		_set_status("ready")
