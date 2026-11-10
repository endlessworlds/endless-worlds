extends Node
@onready var jersey_font: FontFile = load("res://assets/fonts/Jersey10-Regular.ttf")
@onready var fog_rect: ColorRect = get_node("../FogLayer/FogRect")

# ---------------- DAY / NIGHT ----------------
enum TimeOfDay { DAY, NIGHT }

@export var day_color   : Color = Color(1, 1, 1, 1)
@export var night_color : Color = Color(0.3, 0.3, 0.5, 1)

# ⏱ TIME SETTINGS
@export var real_seconds_per_game_minute := 1.0
@export var dawn_start  := 5.0
@export var day_start   := 7.0
@export var dusk_start  := 17.0
@export var night_start := 19.0

# ---------------- LIGHT TRANSITION ----------------
@export var light_transition_speed := 0.4

var current_time : TimeOfDay
var game_hour : int
var game_minute : int
var time_accumulator := 0.0

var current_light_color : Color
var target_light_color  : Color

# ---------------- CLOCK UI ----------------
var clock_label : Label

# ---------------- FLOWER SPAWNER ----------------
@onready var flower_spawner := get_parent().get_node("FlowerSpawner")
@onready var tree_spawner := get_parent().get_node("TreeSpawner")


# ==================================================
# INIT
# ==================================================
var canvas_mod: CanvasModulate

func init_time():
	current_light_color = day_color
	target_light_color = day_color
	# CanvasModulate (not node modulate) so PointLight2Ds can light up the night.
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = day_color
	get_parent().add_child(canvas_mod)

	game_hour = randi_range(0, 23)
	game_minute = [0, 15, 30, 45].pick_random()
	for arg in OS.get_cmdline_user_args():  # dev: godot ... -- --hour=22
		if arg.begins_with("--hour="):
			game_hour = int(arg.get_slice("=", 1))
			update_time_state()
			current_light_color = target_light_color

	create_clock_ui()
	update_time_state()
	update_clock_text()
	
	fog_rect.visible = true
	fog_rect.modulate.a = 0.0
	fog_rect.self_modulate = Color(1.0, 0.9, 0.74)  # golden morning mist

func update_morning_fog(delta: float):
	var time_float := game_hour + game_minute / 60.0

	# Fog window: 5AM → 8AM
	var fog_start := 5.0
	var fog_end := 8.0

	var target_alpha := 0.0

	if time_float >= fog_start and time_float <= fog_end:
		# fade in quickly from 5-5:30
		if time_float < 5.5:
			target_alpha = remap(time_float, 5.0, 5.5, 0.0, 0.35)
		# fog strongest between 5:30-7:30
		elif time_float <= 7.5:
			target_alpha = 0.35
		# fade out 7:30-8
		else:
			target_alpha = remap(time_float, 7.5, 8.0, 0.35, 0.0)

	# smooth transition
	fog_rect.modulate.a = lerp(fog_rect.modulate.a, target_alpha, 3.0 * delta)

# ==================================================
# PROCESS
# ==================================================
func _process(delta):
	time_accumulator += delta

	if time_accumulator >= real_seconds_per_game_minute:
		time_accumulator = 0.0
		advance_time(15)

	current_light_color = current_light_color.lerp(
		target_light_color,
		light_transition_speed * delta
	)

	canvas_mod.color = current_light_color
	update_morning_fog(delta)


# ==================================================
# TIME LOGIC (UNCHANGED)
# ==================================================
func advance_time(minutes: int):
	game_minute += minutes

	if game_minute >= 60:
		game_minute -= 60
		game_hour = (game_hour + 1) % 24

	update_time_state()
	update_clock_text()

# Light colour through the day. Night stays night_color; mornings go through
# pre-dawn blue, a pink-orange sunrise and golden light before neutral noon,
# and evenings mirror it with a warm sunset and purple twilight.
const SKY_KEYS := [
	[0.0, Color(0.3, 0.3, 0.5)], [4.75, Color(0.3, 0.3, 0.5)],
	[5.5, Color(0.45, 0.42, 0.62)], [6.25, Color(0.95, 0.7, 0.62)],
	[7.0, Color(1.0, 0.82, 0.64)], [8.5, Color(1.0, 0.92, 0.79)],
	[11.0, Color(1.0, 1.0, 1.0)], [15.0, Color(1.0, 0.98, 0.93)],
	[17.0, Color(1.0, 0.85, 0.66)], [18.0, Color(0.98, 0.66, 0.52)],
	[18.75, Color(0.55, 0.42, 0.6)], [19.25, Color(0.3, 0.3, 0.5)],
	[24.0, Color(0.3, 0.3, 0.5)],
]
var _sky: Gradient


func hour_float() -> float:
	return game_hour + game_minute / 60.0


func sky_color(h: float) -> Color:
	if _sky == null:
		_sky = Gradient.new()
		_sky.offsets = PackedFloat32Array(SKY_KEYS.map(func(k): return k[0] / 24.0))
		_sky.colors = PackedColorArray(SKY_KEYS.map(func(k): return k[1]))
	return _sky.sample(fposmod(h, 24.0) / 24.0)


func update_time_state():
	var time_float := game_hour + game_minute / 60.0
	target_light_color = sky_color(time_float)
	current_time = TimeOfDay.NIGHT if (time_float >= night_start or time_float < dawn_start) else TimeOfDay.DAY

# ==================================================
# CLOCK UI (SAME AS ORIGINAL map.gd)
# ==================================================
func create_clock_ui():
	var canvas := CanvasLayer.new()
	add_child(canvas)

	clock_label = Label.new()
	canvas.add_child(clock_label)

	# Apply font
	clock_label.add_theme_font_override("font", jersey_font)
	clock_label.add_theme_font_size_override("font_size", 40)
	clock_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# --- SET OPACITY HERE ---
	# (1, 1, 1) keeps the original color, 0.8 sets the transparency
	clock_label.modulate = Color(1, 1, 1, 0.8)

	clock_label.anchor_right = 1
	clock_label.anchor_bottom = 1
	clock_label.offset_right = -20
	clock_label.offset_bottom = -20
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

func update_clock_text():
	var hour := game_hour
	var minute := game_minute
	var suffix := "AM"

	if hour >= 12:
		suffix = "PM"
	if hour > 12:
		hour -= 12
	if hour == 0:
		hour = 12

	clock_label.text = "%02d:%02d %s" % [hour, minute, suffix]
