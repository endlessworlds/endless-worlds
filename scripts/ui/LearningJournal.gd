# LearningJournal.gd
# Animated book-style popup that shows the player's accumulated learning.
# Built entirely in code — no .tscn file required.
# Sections: Solved Riddles | Learned Concepts | Fun Facts

extends CanvasLayer
class_name LearningJournal

# ── visuals ──────────────────────────────────────────────────────────────────
const FONT_PATH        := "res://Jersey10-Regular.ttf"
const JOURNAL_LAYER    := 30   # above all game UI (death overlay=20, AgenticBot=20)
const BOOK_BG          := Color(0.96, 0.91, 0.78, 1.0)   # parchment
const COVER_COLOR      := Color(0.42, 0.22, 0.08, 1.0)   # dark brown cover
const SPINE_COLOR      := Color(0.30, 0.14, 0.05, 1.0)   # darker brown spine
const HEADER_COLOR     := Color(0.20, 0.08, 0.02, 1.0)   # header text
const BODY_COLOR       := Color(0.15, 0.10, 0.05, 1.0)   # body text
const ACCENT_COLOR     := Color(0.72, 0.40, 0.10, 1.0)   # gold-ish accent
const TAB_ACTIVE       := Color(0.42, 0.22, 0.08, 1.0)
const TAB_INACTIVE     := Color(0.64, 0.44, 0.22, 1.0)
const LINE_COLOR       := Color(0.80, 0.72, 0.55, 1.0)

const POPUP_W          := 820.0
const POPUP_H          := 560.0
const SPINE_W          := 38.0

# ── nodes ─────────────────────────────────────────────────────────────────────
var _overlay: ColorRect
var _book_root: Control        # animated container
var _spine: Panel
var _page_container: Panel     # right side white page area
var _tab_buttons: Array = []
var _content_scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _close_btn: Button
var _title_label: Label

var _current_tab: int = 0      # 0=Riddles 1=Concepts 2=Facts

const TAB_NAMES := ["📖 Solved Riddles", "💡 Concepts", "✨ Fun Facts"]

# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════
func open() -> void:
	await _build_ui()
	_show_tab(0)
	_animate_open()


func close() -> void:
	_animate_close()


# ═══════════════════════════════════════════════════════════════════════════════
# Build UI
# ═══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	layer = JOURNAL_LAYER

	# dim overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# book root – centred in viewport
	_book_root = Control.new()
	_book_root.custom_minimum_size = Vector2(POPUP_W, POPUP_H)
	_book_root.size = Vector2(POPUP_W, POPUP_H)
	_book_root.pivot_offset = Vector2(POPUP_W * 0.5, POPUP_H * 0.5)
	_book_root.scale = Vector2(0.05, 0.05)
	_book_root.modulate.a = 0.0
	add_child(_book_root)

	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	_book_root.position = Vector2(
		(vp.x - POPUP_W) * 0.5,
		(vp.y - POPUP_H) * 0.5
	)

	# ── full book background (parchment) ──────────────────────────────────────
	var book_bg := _make_panel(BOOK_BG, 16)
	book_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book_root.add_child(book_bg)

	# ── spine (left strip) ────────────────────────────────────────────────────
	_spine = _make_panel(SPINE_COLOR, 0)
	_spine.custom_minimum_size = Vector2(SPINE_W, POPUP_H)
	_spine.size = Vector2(SPINE_W, POPUP_H)
	_spine.position = Vector2(0, 0)
	_book_root.add_child(_spine)

	# spine decorative lines
	for i in range(6):
		var ln := ColorRect.new()
		ln.color = ACCENT_COLOR
		ln.size = Vector2(SPINE_W - 8, 3)
		ln.position = Vector2(4, 50 + i * 70)
		_spine.add_child(ln)

	# spine title (rotated text drawn via Label inside a rotated sub-container)
	var spine_lbl := Label.new()
	spine_lbl.text = "JOURNAL"
	spine_lbl.add_theme_font_override("font", load(FONT_PATH))
	spine_lbl.add_theme_font_size_override("font_size", 20)
	spine_lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	spine_lbl.rotation_degrees = -90
	spine_lbl.position = Vector2(SPINE_W - 4, POPUP_H * 0.5 + 50)
	_spine.add_child(spine_lbl)

	# ── cover decoration (top strip) ─────────────────────────────────────────
	var cover_strip := _make_panel(COVER_COLOR, 0)
	cover_strip.custom_minimum_size = Vector2(POPUP_W - SPINE_W, 52)
	cover_strip.size = Vector2(POPUP_W - SPINE_W, 52)
	cover_strip.position = Vector2(SPINE_W, 0)
	_book_root.add_child(cover_strip)

	# journal title on cover strip
	_title_label = Label.new()
	_title_label.text = "📚 Learning Journal  —  " + Global.selected_topic.capitalize()
	_title_label.add_theme_font_override("font", load(FONT_PATH))
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_title_label.position = Vector2(12, 10)
	cover_strip.add_child(_title_label)

	# ── close button ──────────────────────────────────────────────────────────
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.add_theme_font_override("font", load(FONT_PATH))
	_close_btn.add_theme_font_size_override("font_size", 26)
	_close_btn.add_theme_color_override("font_color", ACCENT_COLOR)
	_close_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0, 0, 0, 0), 0))
	_close_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(1, 1, 1, 0.15), 4))
	_close_btn.add_theme_stylebox_override("pressed", _make_stylebox(Color(1, 1, 1, 0.25), 4))
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.custom_minimum_size = Vector2(40, 40)
	_close_btn.position = Vector2(POPUP_W - 48, 6)
	_close_btn.pressed.connect(close)
	cover_strip.add_child(_close_btn)

	# ── tabs row ─────────────────────────────────────────────────────────────
	var tab_y := 52.0
	var tab_w := (POPUP_W - SPINE_W) / TAB_NAMES.size()
	_tab_buttons.clear()
	for i in range(TAB_NAMES.size()):
		var tb := Button.new()
		tb.text = TAB_NAMES[i]
		tb.add_theme_font_override("font", load(FONT_PATH))
		tb.add_theme_font_size_override("font_size", 18)
		tb.add_theme_color_override("font_color", Color(1, 1, 1))
		tb.add_theme_stylebox_override("normal", _make_stylebox(TAB_INACTIVE, 0))
		tb.add_theme_stylebox_override("hover", _make_stylebox(TAB_ACTIVE.lightened(0.1), 0))
		tb.add_theme_stylebox_override("pressed", _make_stylebox(TAB_ACTIVE, 0))
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(tab_w, 36)
		tb.size = Vector2(tab_w, 36)
		tb.position = Vector2(SPINE_W + i * tab_w, tab_y)
		var idx := i
		tb.pressed.connect(func(): _show_tab(idx))
		_book_root.add_child(tb)
		_tab_buttons.append(tb)

	# ── page area (below tabs) ────────────────────────────────────────────────
	var page_y := tab_y + 36.0
	_page_container = _make_panel(BOOK_BG, 0)
	_page_container.custom_minimum_size = Vector2(POPUP_W - SPINE_W, POPUP_H - page_y)
	_page_container.size = Vector2(POPUP_W - SPINE_W, POPUP_H - page_y)
	_page_container.position = Vector2(SPINE_W, page_y)
	_book_root.add_child(_page_container)

	# scroll container for content — fills the page area
	_content_scroll = ScrollContainer.new()
	_content_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_scroll.offset_left = 16
	_content_scroll.offset_top = 12
	_content_scroll.offset_right = -16
	_content_scroll.offset_bottom = -12
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_container.add_child(_content_scroll)

	# VBox holds all entries and scrolls with the scroll container.
	# Ruled lines are added as separator ColorRects between entries (see _add_entry),
	# so the "paper lines" scroll together with the text content.
	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 10)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(_content_vbox)


# ═══════════════════════════════════════════════════════════════════════════════
# Tab Content
# ═══════════════════════════════════════════════════════════════════════════════
func _show_tab(idx: int) -> void:
	_current_tab = idx

	# Update tab button styles
	for i in range(_tab_buttons.size()):
		var tb: Button = _tab_buttons[i]
		if i == idx:
			tb.add_theme_stylebox_override("normal", _make_stylebox(TAB_ACTIVE, 0))
			tb.add_theme_color_override("font_color", ACCENT_COLOR)
		else:
			tb.add_theme_stylebox_override("normal", _make_stylebox(TAB_INACTIVE, 0))
			tb.add_theme_color_override("font_color", Color(1, 1, 1))

	# Clear existing content immediately (free() avoids needing await)
	if _content_vbox == null:
		return
	for child in _content_vbox.get_children():
		child.free()

	match idx:
		0: _populate_riddles()
		1: _populate_concepts()
		2: _populate_facts()


func _populate_riddles() -> void:
	var riddles: Array = Global.learning_journal.get("solved_riddles", [])
	if riddles.is_empty():
		_add_empty_message("No solved riddles yet.\nGo answer some questions to fill this page! 🏆")
		return

	for entry in riddles:
		var q: String = entry.get("question", "?")
		var a: String = entry.get("answer", "?")
		var t: String = entry.get("topic", "").capitalize()
		_add_entry("✅ " + q, "Answer: " + a.capitalize() + ("   [" + t + "]" if not t.is_empty() else ""))


func _populate_concepts() -> void:
	var concepts: Array = Global.learning_journal.get("concepts", [])
	if concepts.is_empty():
		_add_empty_message("No concepts learned yet.\nConcepts are captured automatically when\nquestions load. Play a round to fill this page! 💡")
		return

	for entry in concepts:
		var name_str: String = entry.get("name", "")
		var def_str: String  = entry.get("definition", name_str)
		var topic: String    = entry.get("topic", "").capitalize()
		_add_entry("💡 " + name_str + ("   [" + topic + "]" if not topic.is_empty() else ""), def_str)


func _populate_facts() -> void:
	var facts: Array = Global.learning_journal.get("fun_facts", [])
	if facts.is_empty():
		_add_empty_message("No fun facts collected yet.\nThe AI companion shares a fact every 2 minutes\nduring gameplay. Keep playing! ✨")
		return

	for entry in facts:
		var text: String  = entry.get("text", "")
		var topic: String = entry.get("topic", "").capitalize()
		_add_entry("✨ Fun Fact" + ("   [" + topic + "]" if not topic.is_empty() else ""), text)


# ═══════════════════════════════════════════════════════════════════════════════
# Entry Widgets
# ═══════════════════════════════════════════════════════════════════════════════
func _add_entry(heading: String, body: String) -> void:
	# PanelContainer auto-sizes to its content height, preventing overlapping cards.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(1.0, 0.97, 0.88, 0.9)
	card_sb.corner_radius_top_left     = 8
	card_sb.corner_radius_top_right    = 8
	card_sb.corner_radius_bottom_left  = 8
	card_sb.corner_radius_bottom_right = 8
	card_sb.content_margin_left   = 10
	card_sb.content_margin_top    = 6
	card_sb.content_margin_right  = 10
	card_sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", card_sb)
	_content_vbox.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var h_lbl := Label.new()
	h_lbl.text = heading
	h_lbl.add_theme_font_override("font", load(FONT_PATH))
	h_lbl.add_theme_font_size_override("font_size", 20)
	h_lbl.add_theme_color_override("font_color", HEADER_COLOR)
	h_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(h_lbl)

	if body != "" and body != heading:
		var b_lbl := Label.new()
		b_lbl.text = body
		b_lbl.add_theme_font_override("font", load(FONT_PATH))
		b_lbl.add_theme_font_size_override("font_size", 16)
		b_lbl.add_theme_color_override("font_color", BODY_COLOR)
		b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(b_lbl)

	# Divider line below card — scrolls with the content as a "ruled paper" line
	var sep := ColorRect.new()
	sep.color = LINE_COLOR
	sep.custom_minimum_size = Vector2(0, 2)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(sep)


func _add_empty_message(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_override("font", load(FONT_PATH))
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", BODY_COLOR)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.modulate.a = 0.6
	_content_vbox.add_child(lbl)


# ═══════════════════════════════════════════════════════════════════════════════
# Animations
# ═══════════════════════════════════════════════════════════════════════════════
func _animate_open() -> void:
	_book_root.scale = Vector2(0.05, 0.05)
	_book_root.rotation_degrees = -6.0
	_book_root.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_book_root, "scale", Vector2(1.0, 1.0), 0.45)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_book_root, "rotation_degrees", 0.0, 0.45)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_book_root, "modulate:a", 1.0, 0.35)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(_overlay, "color:a", 0.55, 0.35)


func _animate_close() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_book_root, "scale", Vector2(0.05, 0.05), 0.30)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_book_root, "modulate:a", 0.0, 0.25)\
		.set_ease(Tween.EASE_IN)
	tw.tween_property(_overlay, "color:a", 0.0, 0.25)
	tw.chain().tween_callback(_remove_self)


func _remove_self() -> void:
	queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════
func _make_panel(bg: Color, corner: int) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left     = corner
	sb.corner_radius_top_right    = corner
	sb.corner_radius_bottom_left  = corner
	sb.corner_radius_bottom_right = corner
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_stylebox(bg: Color, corner: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left     = corner
	sb.corner_radius_top_right    = corner
	sb.corner_radius_bottom_left  = corner
	sb.corner_radius_bottom_right = corner
	return sb
