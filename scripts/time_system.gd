extends Node
@onready var jersey_font: FontFile = load("res://Jersey10-Regular.ttf")

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
func init_time():
	current_light_color = day_color
	target_light_color = day_color
	get_parent().modulate = day_color

	game_hour = randi_range(0, 23)
	game_minute = [0, 15, 30, 45].pick_random()

	create_clock_ui()
	update_time_state()
	update_clock_text()

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

	get_parent().modulate = current_light_color
	update_flower_lighting()

# ==================================================
# FLOWER LIGHTING
# ==================================================
func update_flower_lighting():
	if flower_spawner != null:
		for child in flower_spawner.get_children():
			if child is Sprite2D:
				child.modulate = current_light_color

	if tree_spawner != null:
		for child in tree_spawner.get_children():
			if child is Sprite2D:
				child.modulate = current_light_color

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

func update_time_state():
	var time_float := game_hour + game_minute / 60.0

	if time_float >= night_start or time_float < dawn_start:
		target_light_color = night_color
		current_time = TimeOfDay.NIGHT

	elif time_float >= dusk_start:
		var t := (time_float - dusk_start) / (night_start - dusk_start)
		target_light_color = day_color.lerp(night_color, t)

	elif time_float >= day_start:
		target_light_color = day_color
		current_time = TimeOfDay.DAY

	else:
		var t := (time_float - dawn_start) / (day_start - dawn_start)
		target_light_color = night_color.lerp(day_color, t)

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
