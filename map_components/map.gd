extends Node2D

@onready var world := $WorldGenerator
@onready var time := $TimeSystem
@onready var rain := $RainController
@onready var rain_system := $RainSystem

@onready var lighting := $LightingSystem
@onready var spawner := $PlayerSpawner
@onready var flower_spawner := $FlowerSpawner
@onready var joystick := $JoyStickUI/VirtualJoystick
@onready var tree_spawner := $TreeSpawner

@onready var answer_popup: AnswerPopup = $AnswerPopup
@onready var player := $Player
@onready var player_shape: CollisionShape2D = $Player/CollisionShape2D
@onready var tilemap: TileMapLayer = $TileMap
@onready var hearts: HeartSystem = $HeartSystem
@onready var gemini: AiQuestionGenerator = $AiQuestionGenerator
@onready var riddle_ui: RiddleUI = $RiddleUI
@onready var tasks: Tasks = $Tasks

var agentic_bot: AgenticBot
var mp: MultiplayerSync          # only while in an online room
var wildlife: Wildlife
var water: Water
var atmosphere: Atmosphere
var _round_ended := false
var _coding_popup: CanvasLayer   # open coding quest screen (coding mode only)
var touch: TouchControls         # on-screen pause / jump / answer buttons

var current_solution: String = ""
var current_options: Array = []   # ✅ ADD THIS
var current_question: String = ""


# ==================================================
# 🔧 GAME SETTINGS
# ==================================================
@export var enable_rain: bool = true
@export var TILE_SOURCE_ID: int = 2

# ==================================================
# UI / DEATH
# ==================================================
var score_label: Label

# ================= TILE & COORDINATE INFO =================
const TILE_NAMES := {
	Vector2i(0, 0): "Grass",
	Vector2i(1, 0): "Dirt",
	Vector2i(2, 0): "Clay",
	Vector2i(3, 0): "Mud",
	Vector2i(0, 1): "Sand",
	Vector2i(1, 1): "Lava",
	Vector2i(2, 1): "Magma",
	Vector2i(3, 1): "Water",
}

const WATER_TILE := Vector2i(3, 1)
const LAVA_TILE := Vector2i(1, 1)
const MAGMA_TILE := Vector2i(2, 1)

var tile_info_label: Label
var coords_label: Label # New label for coordinates

# ================= WATER BREATHING =================
const MAX_BUBBLES := 5
var bubbles_left := MAX_BUBBLES
var in_water := false

var bubble_container: HBoxContainer
var bubble_timer: Timer

# ================= DAMAGE =================
const DAMAGE_INTERVAL := 2.0
var can_take_tile_damage := true
var drown_damage_timer: Timer
var tile_damage_timer: Timer

# ==================================================
func _ready():
	Global.start_game()
	if Net.active and not Net.round_data.is_empty():
		# Online: every player builds the same world from the host's seed.
		Global.is_coding_mode = false
		Global.selected_topic = str(Net.round_data.topic)
		Global.current_question_type = int(Net.round_data.qtype)
		seed(int(Net.round_data.seed))
	elif Global.is_coding_mode:
		Global.current_question_type = Global.QuestionType.CODING
	else:
		var question_pool := [
			Global.QuestionType.MCQ,
			Global.QuestionType.FILL_BLANK,
			Global.QuestionType.WORDLE,
			Global.QuestionType.WHACK,
			Global.QuestionType.WORD_LOCK,
			Global.QuestionType.KBC
		]
		Global.current_question_type = question_pool.pick_random()
	#Global.current_question_type=Global.QuestionType.KBC
	# 🔧 APPLY SETTINGS
	rain.rain_enabled = enable_rain
	world.SRC = randi() % 4
	for arg in OS.get_cmdline_user_args():  # dev: godot ... -- --biome=0..3
		if arg.begins_with("--biome="):
			world.SRC = int(arg.get_slice("=", 1))
	
	if(world.SRC == 1):
		rain_system.is_snow = true
	else:
		rain_system.is_snow = false
		
	if(world.SRC == 3):
		rain.rain_enabled = false
	else:
		rain.rain_enabled = true
		
	# 🌍 WORLD SETUP
	world.generate_world()
	if "--lava-test" in OS.get_cmdline_user_args():  # dev: a lava pool beside spawn, for lighting checks
		var c := Vector2i(world.total_width / 2, world.total_height / 2)
		for x in range(8, 17):
			for y in range(-3, 4):
				if Vector2(x - 12, y * 1.4).length() < 4.5:
					tilemap.set_cell(c + Vector2i(x, y), world.SRC, Vector2i(1, 1))
	world.spawn_wells(self)
	if Global.is_coding_mode:
		_turn_wells_into_terminals()
	
	spawner.spawn_player_at_center()  # before lights/decor so the safe zone has no lava glow
	flower_spawner.spawn_flowers()
	tree_spawner.spawn_trees()
	lighting.spawn_lava_lights()
	time.init_time()
	player.add_to_group("actors")
	if Net.active:
		player.position += Vector2(((Net.my_id - 1) % 5) * 40 - 80, ((Net.my_id - 1) / 5) * 30)  # room for name tags

	# 🌊 animated water + depth (shallow wading vs deep swimming)
	water = Water.new()
	add_child(water)
	water.setup(tilemap, world.total_width, world.total_height)

	# 🦋 living world + 💡 lighting / post-processing
	wildlife = Wildlife.new()
	add_child(wildlife)
	wildlife.setup(tilemap, world.SRC == 1)
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup(self, player, time, world.SRC == 1)
	ShaderWarmup.run(self)   # no shader-compile freezes later in play

	# 🖥 UI + SYSTEMS
	create_tile_info_ui()
	create_bubble_ui()
	create_bubble_timer()
	create_drown_damage_timer()
	create_tile_damage_timer()
	create_score_ui()

	hearts.connect("player_died", _on_player_died)

	if not Global.is_coding_mode:
		# 🧩 Riddle: solo players and the host generate it; guests receive the host's.
		gemini.riddle_generated.connect(_on_riddle_generated)
		if not Net.active or Net.is_host():
			gemini.generate_riddle()
		elif not Net.round_riddle.is_empty():
			_on_riddle_generated.call_deferred(Net.round_riddle)
		tasks.hint_taken.connect(func(idx):
			if mp: mp.broadcast_hint(idx))

		tasks.hint_collected.connect(func():
			riddle_ui.unlock_next_hint()
			# Tell the bot to speak the newly unlocked hint
			var hint_idx := riddle_ui.unlocked_count - 1
			if agentic_bot != null and hint_idx < riddle_ui.hints.size():
				agentic_bot.speak(riddle_ui.hints[hint_idx])
		)
	else:
		riddle_ui.visible = false
		if gemini:
			gemini.set_process(false)

	# bonus treasure chests (score + coins for the Survival armory)
	Treasure.scatter(self, tilemap, player, 4)

	# 🤖 AGENTIC BOT
	agentic_bot = AgenticBot.new()
	add_child(agentic_bot)

	joystick.visible = Screen.is_touch   # keyboard / mouse players move with WASD
	_create_touch_controls()

	# 🧭 objective + compass
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	var guide := GuideHud.new()
	hud_layer.add_child(guide)
	guide.setup(player, tasks, riddle_ui)

	if Net.active:
		mp = MultiplayerSync.new()
		add_child(mp)
		mp.setup(self, player)
	_dev_simulation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle_debug_info()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not answer_popup.visible and not Global.input_locked:
		get_viewport().set_input_as_handled()
		_open_pause()


func _open_pause() -> void:
	var leave_text := "Leave room" if Net.active else "Home"
	var hint := Screen.controls_hint()
	if Net.active and not Screen.is_touch:
		hint = hint.replace("Torch: F", "Torch: F   Chat: T")
	var buttons := [["Resume", func(): pass]]
	if not Net.active and not Global.is_coding_mode:
		buttons.append(["New riddle", func(): get_tree().reload_current_scene()])
	buttons.append(["Settings", func(): SettingsPage.open(self)])
	if Net.is_host():
		buttons.append(["Topic", _open_topic_picker])
	buttons.append([leave_text, _go_home])
	RoundCard.show_card(self, "Paused", hint, buttons, not Net.active)


# Host only: pick a new topic and start a fresh round for everyone. Without the AI
# server the riddle comes from the offline bank, like solo play.
func _open_topic_picker() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	Global.input_locked = true   # typing must not walk the player
	var v := PixelUI.page(layer, "Change topic", 560, func():
		Global.input_locked = false
		layer.queue_free())
	var sub := PixelUI.label("Starts a new round with this topic for everyone.", 22, PixelUI.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var field := LineEdit.new()
	field.text = Global.selected_topic if Global.selected_topic != "programming" else ""
	field.placeholder_text = "Any topic, e.g. Volcanoes"
	field.max_length = 40
	field.custom_minimum_size = Vector2(0, 56)
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_override("font", PixelUI.FONT)
	field.add_theme_font_size_override("font_size", 30)
	v.add_child(field)
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 8)
	v.add_child(chips)
	for t in ["Python", "Space", "Biology", "History", "Math", "Geography"]:
		var c := PixelUI.button(t, func(): field.text = t)
		c.add_theme_font_size_override("font_size", 22)
		c.custom_minimum_size = Vector2(0, 42)
		chips.add_child(c)
	var go := PixelUI.button("Start new round", func():
		var topic := field.text.strip_edges()
		if topic.is_empty():
			topic = "programming"
		Global.selected_topic = topic
		Global.input_locked = false
		Net.set_topic(topic)
		Net.host_start_round(topic, int(Net.round_data.get("round", 1)) + 1)
		get_tree().change_scene_to_file(Net.round_scene()), true)
	go.custom_minimum_size = Vector2(0, 56)
	field.text_submitted.connect(func(_t): go.pressed.emit())
	v.add_child(go)


# ------------------------------------------------------------------ touch
# Phones have no Esc / Space / E: pause (also shown on desktop), jump and a context
# "Answer" button that appears while standing at a well or terminal.
func _create_touch_controls() -> void:
	touch = TouchControls.new()
	add_child(touch)
	touch.show_when = func() -> bool:
		return not answer_popup.visible and not Global.input_locked and not _round_ended \
			and get_tree().get_nodes_in_group("modal").is_empty() \
			and not (is_instance_valid(_coding_popup) and not _coding_popup.is_queued_for_deletion())
	touch.add("pause", "II", Vector2(0, 0), Vector2(14, 14), 60, "", func():
		if not answer_popup.visible and not get_tree().paused:
			_open_pause(), false)
	touch.add("jump", "icon:jump", Vector2(1, 1), Vector2(-22, -100), 100, "jump")
	touch.add("answer", "Use terminal" if Global.is_coding_mode else "Answer", Vector2(0.5, 1), Vector2(0, -170), 64,
		"", func():
			var w := _well_nearby()
			if w:
				w.emit_signal("interact"), true, 2.8)
	touch.set_visible_button("answer", false)


func _well_nearby() -> Node:
	for w in get_tree().get_nodes_in_group("wells"):
		if w.get("player_inside"):
			return w
	return null


func _go_home() -> void:
	if Net.active:
		Net.leave()
	get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn")


# Called by AnswerPopup after a correct answer (score/level/journal already recorded).
func on_round_won() -> void:
	if _round_ended:
		return
	_round_ended = true
	if mp:
		mp.local_won(current_solution)
		return
	var fact := ""
	if not Global.learning_journal.concepts.is_empty():
		fact = str(Global.learning_journal.concepts.back().get("definition", ""))
	var streak := "   ·   Streak x%d" % Global.win_streak if Global.win_streak > 1 else ""
	RoundCard.show_card(self, "Level %d cleared!" % (Global.level - 1),
		"[color=#ffd166]%s[/color]\n%s\n\nScore %d%s" % [current_solution.to_upper(), fact, Global.score, streak],
		[["Next level", func(): get_tree().reload_current_scene()],
		 ["Home", func():
			Global.show_journal_on_home = true
			get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn")]])


# Guests: the host's riddle arrived over the network.
func apply_remote_riddle(data: Dictionary) -> void:
	if current_question.is_empty() and not data.is_empty():
		_on_riddle_generated(data)


# Coding mode: answer points are retro CRT terminals (assets/terminal.png, 3-frame strip
# made by tools/make_terminal.py) with a blinking screen and a soft green glow.
func _turn_wells_into_terminals() -> void:
	var tex: Texture2D = load("res://assets/terminal.png")
	var screens: Array[Sprite2D] = []
	for well in get_tree().get_nodes_in_group("wells"):
		var spr: Sprite2D = well.get_node_or_null("Sprite2D")
		if spr == null:
			continue
		spr.texture = tex
		spr.hframes = 3
		spr.frame = randi() % 3
		screens.append(spr)
		if "prompt_text" in well:
			well.prompt_text = "Use terminal"
		var glow := PointLight2D.new()
		glow.texture = preload("res://assets/wildlife/light_soft.png")
		glow.color = Color(0.4, 1.0, 0.6)
		glow.energy = 0.55
		glow.texture_scale = 0.45
		glow.position = Vector2(0, -12)   # centred on the screen
		glow.range_z_min = -4096
		glow.range_z_max = 4096
		well.add_child(glow)
	var blink := Timer.new()
	blink.wait_time = 0.45
	blink.autostart = true
	add_child(blink)
	blink.timeout.connect(func():
		for s in screens:
			if is_instance_valid(s) and randf() < 0.7:
				s.frame = (s.frame + 1) % 3)


func _on_well_interacted():
	if _round_ended:
		return
	if Global.is_coding_mode:
		if is_instance_valid(_coding_popup) and not _coding_popup.is_queued_for_deletion():
			return   # already open
		if Global.current_coding_question.is_empty():
			Global.current_coding_question = Global.next_coding_question()
		var CodingPopupScript = load("res://ui/coding_screen/coding_popup.gd")
		_coding_popup = CanvasLayer.new()
		_coding_popup.set_script(CodingPopupScript)
		add_child(_coding_popup)
		_coding_popup.open(hearts)
		return

	if answer_popup.visible:
		return
	if current_options.is_empty():
		push_error("❌ No MCQ options available")
		return

	answer_popup.open(
		current_solution,   # String
		current_options,    # Array ✅ FROM GEMINI
		hearts,             # HeartSystem
		self,
		current_question    # Question text
	)

func _on_riddle_generated(data: Dictionary) -> void:
	if Net.is_host():
		Net.round_riddle = data
		Net.send({"t": "riddle", "data": data})
	current_solution = str(data["solution"]).strip_edges().to_lower()
	current_options = data.get("options", []).duplicate()
	current_question = str(data.get("riddle", ""))

	# ── Store concept/fact in Learning Journal ──────────────────────────────
	var fact_ref: String = str(data.get("fact_reference", "")).strip_edges()
	if not fact_ref.is_empty():
		Global.add_concept_to_journal(fact_ref)

	riddle_ui.setup_riddle(data)

	if Net.active:
		seed(int(Net.round_data.seed) + 1)  # identical hint spots for everyone
	tasks.spawn_hints(
		data["hints"].size(), 
		tilemap, 
		world.water_border, 
		world.total_width, 
		world.total_height
	)
	if Net.active:
		randomize()
		for idx in Net.round_hints:
			tasks.remove_hint(idx)

func _process(_delta):
	update_player_tile_info()
	update_score_label()
	if touch:
		touch.set_visible_button("answer", _well_nearby() != null)

# ==================================================
# TILE & COORDS INFO UI
# ==================================================
var _debug_panel: PanelContainer

# Tile + coordinates readout, bottom-left. Visible by default; F3 toggles it.
func create_tile_info_ui():
	var ui := CanvasLayer.new()
	ui.layer = 3
	add_child(ui)

	_debug_panel = PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = preload("res://assets/ui/pixel/frame_normal.png")
	sb.set_texture_margin_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_debug_panel.add_theme_stylebox_override("panel", sb)
	_debug_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_debug_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_debug_panel.offset_left = 16
	_debug_panel.offset_bottom = -12
	_debug_panel.modulate.a = 0.85
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.visible = not Screen.is_touch   # phones: the joystick lives in that corner
	ui.add_child(_debug_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_debug_panel.add_child(box)
	var font := preload("res://assets/fonts/Jersey10-Regular.ttf")
	tile_info_label = Label.new()
	coords_label = Label.new()
	for l in [tile_info_label, coords_label]:
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
		box.add_child(l)
	tile_info_label.text = "Tile: Grass"
	coords_label.text = "Coords: (0, 0)"


func toggle_debug_info() -> void:
	_debug_panel.visible = not _debug_panel.visible


# ==================================================
# TILE & POSITION CHECKING
# ==================================================
func update_player_tile_info():
	# Convert world position to tilemap coordinates
	var cell := tilemap.local_to_map(
		tilemap.to_local(player_shape.global_position - Vector2(0, 16))
	)

	# Update Coordinate Label
	if coords_label:
		coords_label.text = "Coords: (%d, %d)" % [cell.x, cell.y]

	# Tile info
	var atlas := tilemap.get_cell_atlas_coords(cell)
	var tile_name :Variant= TILE_NAMES.get(atlas, "Dirt")
	tile_info_label.text = "Tile: " + tile_name

	# Mid-jump you're above the ground: no lava burn, no splash.
	if player.airborne:
		return

	# Water logic: next to the shore you wade (slower, no air loss);
	# further out you swim (drift, bob, air bubbles count down).
	var depth := water.depth_at(cell) if atlas == WATER_TILE else 0
	player.wading = depth == 1
	if depth >= 2:
		if not in_water:
			enter_water()
	elif in_water:
		exit_water()

	# Damage logic
	if atlas == LAVA_TILE or atlas == MAGMA_TILE:
		if can_take_tile_damage:
			hearts.damage(1)
			can_take_tile_damage = false
			tile_damage_timer.start()

	# 🔊 FOOTSTEP TILE TYPE
	match tile_name:
		"Water":
			player.current_tile_type = "Water"
		"Sand", "Lava", "Magma":
			player.current_tile_type = "Gravel"
		_:
			player.current_tile_type = "Dirt"

# ==================================================
# WATER BUBBLES UI
# ==================================================
func create_bubble_ui():
	bubble_container = HBoxContainer.new()
	hearts.add_child(bubble_container)
	bubble_container.modulate.a = 0.8
	bubble_container.visible = false
	bubble_container.add_theme_constant_override("separation", 6)

	for i in range(MAX_BUBBLES):
		var bubble := TextureRect.new()
		bubble.texture = preload("res://assets/ui/bubble.png")
		bubble.custom_minimum_size = Vector2(40, 40)
		bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		bubble_container.add_child(bubble)

	get_viewport().size_changed.connect(func(): position_bubbles.call_deferred())
	await get_tree().process_frame
	position_bubbles()

func position_bubbles():
	var hearts_container := hearts.hearts_container
	if hearts_container == null:
		return
	bubble_container.position = hearts_container.position + Vector2(0, hearts.heart_size + 8)

# ==================================================
# TIMERS
# ==================================================
func create_bubble_timer():
	bubble_timer = Timer.new()
	bubble_timer.wait_time = 1.0
	bubble_timer.timeout.connect(_on_bubble_tick)
	add_child(bubble_timer)

func create_drown_damage_timer():
	drown_damage_timer = Timer.new()
	drown_damage_timer.wait_time = DAMAGE_INTERVAL
	drown_damage_timer.timeout.connect(func():
		if in_water and bubbles_left <= 0:
			hearts.damage(1)
	)
	add_child(drown_damage_timer)

func create_tile_damage_timer():
	tile_damage_timer = Timer.new()
	tile_damage_timer.wait_time = DAMAGE_INTERVAL
	tile_damage_timer.one_shot = true
	tile_damage_timer.timeout.connect(func():
		can_take_tile_damage = true
	)
	add_child(tile_damage_timer)

# ==================================================
# WATER STATE
# ==================================================
func enter_water():
	in_water = true
	player.in_water = true
	bubbles_left = MAX_BUBBLES
	bubble_container.visible = true
	update_bubbles()
	bubble_timer.start()

func exit_water():
	in_water = false
	player.in_water = false
	bubble_timer.stop()
	drown_damage_timer.stop()
	bubble_container.visible = false
	bubbles_left = MAX_BUBBLES

func _on_bubble_tick():
	if not in_water: return
	if bubbles_left > 0:
		bubbles_left -= 1
		update_bubbles()
		if bubbles_left == 0:
			drown_damage_timer.start()

func update_bubbles():
	for i in range(bubble_container.get_child_count()):
		var bubble := bubble_container.get_child(i) as TextureRect
		if i < bubbles_left:
			bubble.visible = true
			bubble.modulate.a = 1.0
		else:
			bubble.visible = false

# ==================================================
# SCORE
# ==================================================
func create_score_ui():
	var canvas := CanvasLayer.new()
	add_child(canvas)
	
	score_label = Label.new()
	canvas.add_child(score_label)
	
	# Apply font settings
	score_label.add_theme_font_override("font", load("res://assets/fonts/Jersey10-Regular.ttf"))
	score_label.add_theme_font_size_override("font_size", 40)
	
	# --- ADD THIS LINE FOR OPACITY ---
	# Color(1, 1, 1) keeps it white, 0.8  sets the transparency
	score_label.modulate = Color(1, 1, 1, 0.8) 
	
	score_label.position = Vector2(88, 20)   # right of the pause button
	update_score_label()

func update_score_label():
	if score_label:
		score_label.text = "Score: %d" % Global.score

func add_score(amount: int):
	Global.add_score(amount)
	update_score_label()

# ==================================================
# DEATH
# ==================================================
func _on_player_died():
	if not is_inside_tree() or _round_ended:
		return # Stop if the node is already detached
	if Net.active:
		_respawn_online()
		return
	_round_ended = true
	if answer_popup.visible:
		answer_popup.close()
	var final_score := Global.score
	Global.end_game(false)
	Global.reset_score_only()
	# Even a loss teaches something: show the answer and the fact behind it.
	var body := ""
	if not current_solution.is_empty():
		body = "The answer was [color=#ffd166]%s[/color]\n" % current_solution.to_upper()
		if not Global.learning_journal.concepts.is_empty():
			body += str(Global.learning_journal.concepts.back().get("definition", "")) + "\n"
	body += "\n%s   Score %d" % [["You'll get it next time!", "Nice try, explorer!", "The island wins this round."].pick_random(), final_score]
	RoundCard.show_card(self, "Out of hearts", body,
		[["Try again", func(): get_tree().reload_current_scene()],
		 ["Home", func(): get_tree().change_scene_to_file("res://ui/home_screen/home_screen.tscn")]], true)


# Online rooms don't kick you out: a short penalty, then back in with full hearts.
func _respawn_online() -> void:
	Global.add_score(-15)
	exit_water()
	var layer := CanvasLayer.new()
	layer.layer = PixelUI.PAGE_LAYER
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PixelUI.panel(PixelUI.FRAME, 34, 18)
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(PixelUI.label("Knocked out!", 52, PixelUI.GOLD))
	var sub := PixelUI.label("", 28)
	v.add_child(sub)
	for i in [3, 2, 1]:
		sub.text = "-15 score   ·   back in %d" % i
		await get_tree().create_timer(1.0).timeout
	spawner.spawn_player_at_center()
	hearts.heal(hearts.max_hearts)
	layer.queue_free()


# Dev/testing: `-- --sim-hint-at=8 --sim-win-at=15` picks a hint / wins the round
# by script, so round flow and multiplayer sync can be checked without input.
func _dev_simulation() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0).trim_prefix("--")] = float(a.get_slice("=", 1))
	if args.has("sim-say-at"):  # long reply to check bubble layout
		get_tree().create_timer(args["sim-say-at"]).timeout.connect(func(): agentic_bot.speak(
			"In Python a tuple is an ordered, immutable sequence. You create one with commas, usually inside parentheses, and it can be used as a dictionary key."))
	for a in OS.get_cmdline_user_args():
		# --sim-walk=left|right|up|down holds that direction from 3 s to 4 s (torch / animation checks)
		if a.begins_with("--sim-walk="):
			var act := "ui_" + a.get_slice("=", 1)
			get_tree().create_timer(3.0).timeout.connect(func(): Input.action_press(act))
			get_tree().create_timer(4.0).timeout.connect(func(): Input.action_release(act))
	if args.has("sim-jump-at"):
		get_tree().create_timer(args["sim-jump-at"]).timeout.connect(func():
			Input.action_press("jump")
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_release("jump"))
	for a in OS.get_cmdline_user_args():  # --sim-voice=<16 kHz wav> speaks it to Bolt at 8 s
		if a.begins_with("--sim-voice="):
			get_tree().create_timer(8.0).timeout.connect(func(): agentic_bot._voice.sim_voice_file(a.get_slice("=", 1)))
	if args.has("sim-die-at"):
		get_tree().create_timer(args["sim-die-at"]).timeout.connect(func(): hearts.damage(hearts.max_hearts))
	if args.has("sim-chat-at") and mp:
		get_tree().create_timer(args["sim-chat-at"]).timeout.connect(func(): mp._send_chat("Found a hint over here!"))
	if args.has("sim-menu-at"):
		get_tree().create_timer(args["sim-menu-at"]).timeout.connect(func(): agentic_bot._voice.toggle_menu())
	if args.has("sim-hint-at"):
		await get_tree().create_timer(args["sim-hint-at"]).timeout
		for h in get_tree().get_nodes_in_group("hints"):
			h.emit_signal("collected")
			h.queue_free()
			break
	if args.has("sim-win-at"):
		await get_tree().create_timer(args["sim-win-at"]).timeout
		Global.add_score(30)
		Global.next_level()
		on_round_won()
