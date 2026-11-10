extends CanvasLayer
class_name CodingPopup

const PISTON_EXECUTE_URL = "https://emkc.org/api/v2/piston/execute"
const FONT_PATH = "res://assets/fonts/Jersey10-Regular.ttf"
const BG_COLOR = Color(0.08, 0.08, 0.08, 0.95)
const PANEL_BG = Color(0.15, 0.15, 0.15, 1.0)
const BORDER_COLOR = Color(0.3, 0.3, 0.3, 1.0)
const TEXT_COLOR = Color(0.9, 0.9, 0.9, 1.0)
const ACCENT_COLOR = Color(0.3, 0.9, 0.9, 1.0) # diamond cyan
const SUCCESS = Color(0.3, 1.0, 0.3, 1.0)
const DANGER = Color(1.0, 0.3, 0.3, 1.0)

var _font: Font
var _http: HTTPRequest
var _title_lbl: Label
var _icon_lbl: Label
var _desc_lbl: RichTextLabel
var _editor: TextEdit
var _output: RichTextLabel
var _run_btn: Button
var _close_btn: Button

var _current_q: Dictionary
var _is_running: bool = false

var _hearts: Node

func open(hearts: Node = null) -> void:
	_hearts = hearts
	_font = load(FONT_PATH)
	layer = 50
	_build_ui()
	_load_random_question()
	
	for child in get_children():
		if child is Control:
			child.modulate.a = 0.0
			var tw = create_tween()
			tw.tween_property(child, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)

func close() -> void:
	var tw = create_tween()
	var any_control = false
	for child in get_children():
		if child is Control:
			tw.parallel().tween_property(child, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
			any_control = true
	
	if any_control:
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	hbox.offset_left = 20
	hbox.offset_top = 20
	hbox.offset_right = -20
	hbox.offset_bottom = -20
	add_child(hbox)

	# --- LEFT COLUMN (Quest info) ---
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	left_vbox.add_theme_constant_override("separation", 12)
	hbox.add_child(left_vbox)

	var header_panel = _make_panel()
	header_panel.custom_minimum_size = Vector2(0, 60)
	var hh = HBoxContainer.new()
	hh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hh.add_theme_constant_override("separation", 10)
	header_panel.add_child(hh)
	
	_icon_lbl = Label.new()
	_icon_lbl.add_theme_font_override("font", _font)
	_icon_lbl.add_theme_font_size_override("font_size", 40)
	_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hh.add_child(_icon_lbl)
	
	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", _font)
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", ACCENT_COLOR)
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hh.add_child(_title_lbl)
	
	left_vbox.add_child(header_panel)

	var quest_panel = _make_panel()
	quest_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(quest_panel)
	
	_desc_lbl = RichTextLabel.new()
	_desc_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desc_lbl.offset_left = 12
	_desc_lbl.offset_top = 12
	_desc_lbl.offset_right = -12
	_desc_lbl.offset_bottom = -12
	_desc_lbl.add_theme_font_override("normal_font", _font)
	_desc_lbl.add_theme_font_size_override("normal_font_size", 22)
	_desc_lbl.bbcode_enabled = true
	quest_panel.add_child(_desc_lbl)

	# --- RIGHT COLUMN (Editor & Terminal) ---
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.2
	right_vbox.add_theme_constant_override("separation", 12)
	hbox.add_child(right_vbox)

	var editor_panel = _make_panel()
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_panel.size_flags_stretch_ratio = 1.5
	right_vbox.add_child(editor_panel)
	
	_editor = TextEdit.new()
	_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_editor.offset_left = 8
	_editor.offset_top = 8
	_editor.offset_right = -8
	_editor.offset_bottom = -8
	_editor.add_theme_font_override("font", _font)
	_editor.add_theme_font_size_override("font_size", 24)
	_editor.add_theme_color_override("font_color", SUCCESS)
	_editor.add_theme_color_override("background_color", Color(0.05, 0.05, 0.05, 1.0))
	_editor.caret_blink = true
	editor_panel.add_child(_editor)

	var terminal_panel = _make_panel()
	terminal_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(terminal_panel)
	
	var term_top = HBoxContainer.new()
	term_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	term_top.offset_left = 8
	term_top.offset_top = 8
	term_top.offset_right = -8
	term_top.custom_minimum_size = Vector2(0, 40)
	terminal_panel.add_child(term_top)
	
	var term_lbl = Label.new()
	term_lbl.text = "TERMINAL"
	term_lbl.add_theme_font_override("font", _font)
	term_lbl.add_theme_font_size_override("font_size", 20)
	term_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	term_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	term_top.add_child(term_lbl)
	
	_run_btn = Button.new()
	_run_btn.text = " RUN CODE "
	_run_btn.add_theme_font_override("font", _font)
	_run_btn.add_theme_font_size_override("font_size", 24)
	_run_btn.add_theme_color_override("font_color", Color.BLACK)
	var run_sb = StyleBoxFlat.new()
	run_sb.bg_color = ACCENT_COLOR
	run_sb.corner_radius_top_left = 4
	run_sb.corner_radius_top_right = 4
	run_sb.corner_radius_bottom_left = 4
	run_sb.corner_radius_bottom_right = 4
	_run_btn.add_theme_stylebox_override("normal", run_sb)
	_run_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_run_btn.pressed.connect(_on_run_pressed)
	term_top.add_child(_run_btn)
	
	_output = RichTextLabel.new()
	_output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_output.offset_left = 8
	_output.offset_top = 50
	_output.offset_right = -8
	_output.offset_bottom = -8
	_output.add_theme_font_override("normal_font", _font)
	_output.add_theme_font_size_override("normal_font_size", 20)
	_output.bbcode_enabled = true
	_output.text = "[color=#777]> Ready.[/color]"
	terminal_panel.add_child(_output)

	# Close button absolute positioned
	_close_btn = Button.new()
	_close_btn.text = " ✕ "
	_close_btn.add_theme_font_override("font", _font)
	_close_btn.add_theme_font_size_override("font_size", 30)
	_close_btn.add_theme_color_override("font_color", DANGER)
	_close_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_close_btn.position = Vector2(bg.size.x - 50, 10)
	_close_btn.pressed.connect(close)
	add_child(_close_btn)
	
	# Handle resize
	get_tree().root.size_changed.connect(func(): _close_btn.position = Vector2(get_viewport().get_visible_rect().size.x - 50, 10))

	_http = HTTPRequest.new()
	_http.timeout = 30.0
	_http.request_completed.connect(_on_http_completed)
	add_child(_http)

func _make_panel() -> Panel:
	var p = Panel.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = BORDER_COLOR
	p.add_theme_stylebox_override("panel", sb)
	return p

func _load_random_question() -> void:
	if not Global.current_coding_question.is_empty():
		_current_q = Global.current_coding_question
	else:
		var f = FileAccess.open("res://data/coding_questions.json", FileAccess.READ)
		if f:
			var arr = JSON.parse_string(f.get_as_text())
			if typeof(arr) == TYPE_ARRAY and not arr.is_empty():
				_current_q = arr[randi() % arr.size()]
	
	if _current_q.is_empty():
		_output.text = "[color=red]Error: Could not load coding question[/color]"
		return
		
	_icon_lbl.text = " " + _current_q.get("icon", "💻")
	_title_lbl.text = "QUEST: " + _current_q.get("title", "Unknown")
	
	var desc: String = _current_q.get("desc", "")
	
	var bbc := "[color=#fff]" + desc + "[/color]\n\n"
	bbc += "[color=#9aa]Expected results:[/color]\n"
	for tc in _current_q.get("testCases", []):
		bbc += "- input: " + str(tc["input"]) + " -> expected: " + str(tc["expected"]) + "\n"
	
	_desc_lbl.text = bbc
	
	_editor.text = _current_q.get("startingCode", "")

func _on_run_pressed() -> void:
	if _is_running: return
	_is_running = true
	_run_btn.text = " RUNNING... "
	_output.text = "[color=#777]> Evaluating with LLM Compiler...[/color]"
	
	var user_code = _editor.text
	var title = _current_q.get("title", "")
	var desc = _current_q.get("desc", "")
	var tcs = str(_current_q.get("testCases", []))
	
	var payload := {
		"question_title": title,
		"question_desc": desc,
		"expected_output": tcs,
		"user_code": user_code
	}
	
	var headers = PackedStringArray(["Content-Type: application/json"])
	var err = _http.request(Global.api_url("/api/evaluate_code"), headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_output.text = "[color=red]❌ Request failed.[/color]"
		_finish_run()

func _on_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code < 200 or response_code >= 300:
		var err_txt = body.get_string_from_utf8()
		_output.text = "[color=red]❌ LLM Execution failed (HTTP %d).[/color]\nServer says: %s" % [response_code, err_txt.replace("[", "[lb]")]
		_finish_run()
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY:
		_output.text = "[color=red]❌ Invalid response from LLM.[/color]"
		_finish_run()
		return
		
	var passed = json.get("passed", false)
	var feedback = json.get("feedback", "")
	
	if passed:
		_output.text = "[color=#55ff55]ALL TESTS PASSED! +100 XP[/color]\n\n"
		_output.text += "[color=#55ff55]Compiler Note:[/color] " + feedback + "\n\n"
		_output.text += "[color=#777]> Loading next quest in 2s...[/color]"
		# Update stats
		Global.add_score(100)
		Global.stats.total_games += 1
		Global.stats.total_wins += 1
		Global.save_game()
		
		await get_tree().create_timer(2.0).timeout
		
		# Close popup if in game
		if Global.is_coding_mode:
			Global.current_coding_question = {}
			close()
	else:
		_output.text = "[color=red]Test Failure:[/color]\n" + feedback
		if _hearts and _hearts.has_method("damage"):
			_hearts.damage(1)
			if "current_hearts" in _hearts and _hearts.current_hearts <= 0:
				close()
			
	_finish_run()

func _finish_run() -> void:
	_is_running = false
	_run_btn.text = " RUN CODE "
