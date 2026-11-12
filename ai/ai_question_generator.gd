extends Node
class_name AiQuestionGenerator

var resolved_search_topic: String = ""

# ================= SCRAPING CONFIG =================
const DEBUG_FILE: String = "user://debug_scrape.txt"

# Offline bank: used when the AI server is unreachable, so the game always plays.
const OFFLINE_BANK_PATH := "res://data/riddles.json"
const SCRAPE_TIMEOUT := 25.0
const RIDDLE_TIMEOUT := 30.0

@onready var http_server: HTTPRequest = HTTPRequest.new()
@onready var http_scrape: HTTPRequest = HTTPRequest.new()

# ================= STORED DATA =================
var riddle_data: Dictionary = {
	"riddle": "",
	"options": [],
	"solution": "",
	"hints": [],
	"fact_reference": "",
	"source": ""
}

var current_topic: String = ""
var current_difficulty: String = ""

var _log_timer: Timer
@onready var log_label: Label = get_node_or_null("../RiddleUI/Log")

signal riddle_generated(data: Dictionary)

# ================= LOG & LOADING STATE =================
var log_history: Array = []
const LOG_KEEP := 7
var _loading_bar: ColorRect = null
var _loading_bg: ColorRect = null
var _is_loading: bool = false
var _loading_progress: float = 0.0
var _loading_target: float = 0.0

# =================================================
func _ready() -> void:
	# 1. SETUP TIMER
	_log_timer = Timer.new()
	_log_timer.wait_time = 14.0
	_log_timer.one_shot = true
	_log_timer.timeout.connect(_on_log_timer_timeout)
	add_child(_log_timer)
	if log_label:
		_style_log()
		log_label.hide()

	# 2. LOG
	print("[AiQuestionGenerator] Initializing...")
	add_log("Initializing...")

	# 3. HTTP NODES
	http_server.timeout = RIDDLE_TIMEOUT
	http_scrape.timeout = SCRAPE_TIMEOUT
	add_child(http_server)
	http_server.request_completed.connect(_on_server_response)
	
	add_child(http_scrape)
	http_scrape.request_completed.connect(_on_scrape_response)

	# 4. CREATE LOADING BAR
	_create_loading_bar()

# =================================================
func generate_riddle() -> void:
	# Fetching difficulty and topic from your existing Global/Map logic
	current_difficulty = Global.get_difficulty()
	current_topic = Global.selected_topic
	
	print("[AiQuestionGenerator] Requesting Riddle. Topic: %s | Difficulty: %s" % [current_topic, current_difficulty])
	log_history.clear()
	add_log("🎯 Difficulty AI picked: %s" % current_difficulty.capitalize())
	add_log("🔍 Searching Web for: %s..." % current_topic)
	
	start_loading()
	_set_loading_target(50.0)  # 0→50%: Web Scraping phase
	_request_scrape(current_topic)

func _request_scrape(topic: String) -> void:
	var body := {
		"topic": topic
	}
	
	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]
	
	var err := http_scrape.request(
		Global.api_url("/api/scrape"),
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if err != OK:
		push_error("[AiQuestionGenerator] Failed to start request to python scrape server.")
		_use_fallback()

func _on_scrape_response(result, code, _headers, body) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		# Server unreachable / timed out: don't wait on a second request.
		add_log("📴 AI server offline — using offline questions")
		_use_fallback()
		return
	if code == 200:
		var text: String = body.get_string_from_utf8()
		var data: Variant = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY and data.has("url"):
			var chunks = data.get("chunks_stored", 0)
			add_log("🌐 Read %s" % str(data["url"]).get_slice("//", 1).get_slice("/", 0))
			add_log("📄 Scraped %d chunks" % chunks)
			print("[AiQuestionGenerator] Scraped and stored %d chunks from %s" % [chunks, data["url"]])
		else:
			add_log("📄 Web search finished")
		_set_loading_target(70.0)  # 50→70%: Scraped data received
	else:
		push_warning("[AiQuestionGenerator] Scrape server returned code %d. Proceeding anyway." % code)
		add_log("⚠️ Scrape failed, using internal knowledge...")
		_set_loading_target(65.0)  # Still advance past scraping phase
		
	# Now that scraping is done, we generate the riddle
	add_log("🧠 Generating Riddle...")
	_set_loading_target(90.0)  # 70→90%: Generating question
	_request_riddle_from_server(current_topic, current_difficulty)

func _request_riddle_from_server(topic: String, difficulty: String) -> void:
	var body := {
		"topic": topic,
		"difficulty": difficulty
	}
	
	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]
	
	var err := http_server.request(
		Global.api_url("/api/generate_riddle"),
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if err != OK:
		push_error("[AiQuestionGenerator] Failed to start request to python server.")
		_use_fallback()

# =================================================
func _on_server_response(_result, code, _headers, body) -> void:
	if code != 200:
		push_warning("[AiQuestionGenerator] Server returned code %d" % code)
		_use_fallback()
		return
		
	var text: String = body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	
	if typeof(data) == TYPE_DICTIONARY and data.has("riddle"):
		riddle_data = data
		print("Riddle generated via %s." % riddle_data.get("source", "unknown"))
		add_log("🤖 Written by: %s" % str(riddle_data.get("source", "AI")))
		add_log("✅ Question Ready!")
		_log_hints(riddle_data)
		_set_loading_target(100.0)  # 90→100%: Question generated
		stop_loading()
		_log_riddle_details(riddle_data)
		emit_signal("riddle_generated", riddle_data)
	else:
		push_error("[AiQuestionGenerator] Invalid format from python server")
		_use_fallback()

# =================================================
func _use_fallback() -> void:
	print("[AiQuestionGenerator] ⚠️ ACTIVATING FALLBACK.")
	riddle_data = pick_offline_riddle(current_topic)
	add_log("📚 Searching the offline question bank...")
	add_log("🧩 Picked a riddle about %s" % current_topic)
	add_log("✅ Question Ready!")
	_log_hints(riddle_data)
	_set_loading_target(100.0)  # Complete the bar
	stop_loading()
	_log_riddle_details(riddle_data)
	emit_signal("riddle_generated", riddle_data)

func _log_hints(data: Dictionary) -> void:
	var n: int = (data.get("hints", []) as Array).size()
	if n > 0:
		add_log("💡 %d hint bulbs hidden on the island" % n)

# =================================================
func _log_riddle_details(data: Dictionary) -> void:
	print("------------------------------------------")
	print("[AiQuestionGenerator] DATA SOURCE: ", data.get("source", "unknown"))
	print("QUESTION: ", data.get("riddle", "N/A"))
	print("OPTIONS: ", data.get("options", []))
	print("ANSWER: ", data.get("solution", "N/A"))
	print("FACT: ", data.get("fact_reference", "N/A"))
	print("------------------------------------------")

# ================= LOADING BAR =================
const VISTA_SHIMMER_SHADER := """
shader_type canvas_item;

void fragment() {
	// Subtle top-to-bottom gradient for glassy Vista depth
	float depth = 1.0 + UV.y * 0.15 - step(0.45, UV.y) * 0.3;

	// Flowing shimmer sweep (Vista-style glowing highlight)
	float shimmer_pos = fract(TIME * 0.35);
	float shimmer_width = 0.22;
	float shimmer = smoothstep(shimmer_width, 0.0, abs(UV.x - shimmer_pos));
	// Second, fainter trailing shimmer for extra flow
	float shimmer2_pos = fract(TIME * 0.35 - 0.35);
	float shimmer2 = smoothstep(shimmer_width * 0.6, 0.0, abs(UV.x - shimmer2_pos)) * 0.35;

	COLOR.rgb *= depth;
	COLOR.rgb += vec3(shimmer * 0.45 + shimmer2 * 0.2);
}
"""

func _create_loading_bar() -> void:
	# Create a separate CanvasLayer for the loading bar so it's always on top
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "LoadingBarLayer"
	add_child(canvas)

	# Background bar (dark, slightly taller for Vista look)
	_loading_bg = ColorRect.new()
	_loading_bg.color = Color(0.08, 0.08, 0.12, 0.7)
	_loading_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_loading_bg.offset_bottom = 8
	_loading_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_bg.hide()
	canvas.add_child(_loading_bg)

	# Green fill bar with Vista shimmer shader
	_loading_bar = ColorRect.new()
	_loading_bar.color = Color(0.18, 0.82, 0.35, 1.0)
	_loading_bar.position = Vector2.ZERO
	_loading_bar.size = Vector2(0, 8)
	_loading_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_bar.hide()
	# Apply Vista shimmer shader
	var shader = Shader.new()
	shader.code = VISTA_SHIMMER_SHADER
	var mat = ShaderMaterial.new()
	mat.shader = shader
	_loading_bar.material = mat
	canvas.add_child(_loading_bar)

func _set_loading_target(target: float) -> void:
	_loading_target = clampf(target, _loading_progress, 100.0)

func start_loading() -> void:
	_loading_progress = 0.0
	_loading_target = 0.0
	_is_loading = true
	if _loading_bg: _loading_bg.show()
	if _loading_bar:
		_loading_bar.size.x = 0
		_loading_bar.show()

func stop_loading() -> void:
	_is_loading = false
	_loading_target = 100.0
	if _loading_bar:
		var screen_w = get_viewport().get_visible_rect().size.x
		# Smoothly animate to 100% then fade out
		var tween = create_tween()
		tween.tween_property(_loading_bar, "size:x", screen_w, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_interval(0.4)
		tween.tween_property(_loading_bar, "modulate:a", 0.0, 0.5)
		if _loading_bg:
			tween.tween_property(_loading_bg, "modulate:a", 0.0, 0.3)
		tween.tween_callback(_hide_loading)

func _hide_loading() -> void:
	if _loading_bar:
		_loading_bar.hide()
		_loading_bar.modulate.a = 1.0
	if _loading_bg:
		_loading_bg.hide()
		_loading_bg.modulate.a = 1.0

func _process(delta: float) -> void:
	if _is_loading and _loading_bar:
		var screen_w = get_viewport().get_visible_rect().size.x
		# Smooth lerp toward the milestone target — very slow crawl for long phases
		_loading_progress = lerp(_loading_progress, _loading_target, delta * 0.08)
		# Clamp tiny overshoots
		if abs(_loading_progress - _loading_target) < 0.05:
			_loading_progress = _loading_target
		_loading_bar.size.x = (screen_w * _loading_progress) / 100.0

# ================= LOG SYSTEM =================
# Everything the AI does ("Searching Web for…", "Generating Riddle…", "Question Ready!") as a
# feed in the pixel frame, top-left under the score; on narrow screens it sits below the
# objective pill that takes the top centre. Each step is one line (long ones end in "…"),
# newest at the bottom, and only as many lines as fit above the hint bulbs are shown.
# The feed fades out after a quiet spell.
func _style_log() -> void:
	var sb := StyleBoxTexture.new()
	sb.texture = preload("res://assets/ui/pixel/frame_normal.png")
	sb.set_texture_margin_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	log_label.add_theme_stylebox_override("normal", sb)
	log_label.add_theme_font_size_override("font_size", 20)
	log_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	log_label.add_theme_constant_override("shadow_offset_x", 0)
	log_label.add_theme_constant_override("shadow_offset_y", 0)
	log_label.add_theme_constant_override("line_spacing", 0)
	log_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	log_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_log(message: String) -> void:
	print("[AI log] ", message)
	log_history.append(message)
	if log_history.size() > LOG_KEEP:
		log_history.pop_front()
	if not log_label or Global.is_coding_mode:
		return
	var vp := get_viewport().get_visible_rect().size
	var font := log_label.get_theme_font("font")
	var fs := log_label.get_theme_font_size("font_size")
	var top := 76.0 if vp.x >= 900.0 else 140.0
	# lines that fit between the top and the hint bulbs (at least 2)
	var room := vp.y * 0.5 - 170.0
	var col := get_node_or_null("../RiddleUI/Panel/HintsColumn") as Control
	if col and col.size.y > 0.0:
		room = col.global_position.y
	var line_h := font.get_height(fs)
	var fit := clampi(int((room - 8.0 - top - 14.0) / line_h), 2, LOG_KEEP)
	var shown := log_history.slice(maxi(0, log_history.size() - fit))
	var w := 0.0
	for l in shown:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	log_label.text = "
".join(shown)
	log_label.position = Vector2(16, top)
	log_label.size = Vector2(minf(w + 32.0, minf(440.0, vp.x - 32.0)), 0)
	log_label.modulate.a = 1.0
	log_label.show()
	_log_timer.stop()
	_log_timer.start()

func _on_log_timer_timeout() -> void:
	if log_label:
		var tween = create_tween()
		tween.tween_property(log_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func():
			log_label.hide()
			log_history.clear())


# Topic-matched riddle from the offline bank (any riddle if nothing matches).
static func pick_offline_riddle(topic: String) -> Dictionary:
	var bank: Array = []
	var f := FileAccess.open(OFFLINE_BANK_PATH, FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			bank = parsed
	if bank.is_empty():
		return {"riddle": "I repeat code until a condition is false. What am I?", "options": ["Loop", "Array", "Class", "Stack"], "solution": "Loop", "hints": ["Repetition", "for / while", "Can run forever", "Control flow"], "fact_reference": "Loops repeat work.", "source": "offline"}
	var t := topic.to_lower().strip_edges()
	var matches: Array = bank.filter(func(r): return r.get("tags", []).any(func(tag): return t.contains(tag) or tag.contains(t)))
	var pick: Dictionary = (matches if not matches.is_empty() else bank).pick_random().duplicate(true)
	var opts: Array = pick["options"]
	opts.shuffle()
	return pick
