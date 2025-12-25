extends Node2D

# ---------------- WORLD SIZE ----------------
@export var width := 200
@export var height := 200

@onready var tilemap : TileMapLayer = $TileMap
@onready var noise := FastNoiseLite.new()
@onready var glow_manager := $GlowManager   # Node2D with PointLight2D

# ---------------- DAY / NIGHT ----------------
enum TimeOfDay { DAY, NIGHT }

@export var day_color   : Color = Color(1, 1, 1, 1)
@export var night_color : Color = Color(0.3, 0.3, 0.5, 1)

# ⏱ TIME SETTINGS
@export var real_seconds_per_game_minute := 1.0   # 15 sec = 15 game minutes
@export var dawn_start := 5.0
@export var day_start := 7.0
@export var dusk_start := 17.0
@export var night_start := 19.0

var current_time : TimeOfDay
var game_hour : int
var game_minute : int
var time_accumulator := 0.0

# ---------------- TILE ATLAS ----------------
const SRC := 0

const GRASS = Vector2i(0, 0)
const DIRT  = Vector2i(1, 0)
const CLAY  = Vector2i(2, 0)
const MUD   = Vector2i(3, 0)

const SAND  = Vector2i(0, 1)
const LAVA  = Vector2i(1, 1)
const MAGMA = Vector2i(2, 1)
const WATER = Vector2i(3, 1)

# ---------------- CLOCK UI ----------------
var clock_label : Label


# ==================================================
# READY
# ==================================================
func _ready():
	randomize()

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.008
	noise.seed = randi()

	# Random start time
	game_hour = randi_range(0, 23)
	game_minute = [0, 15, 30, 45].pick_random()

	generate_world()
	create_clock_ui()
	update_time_state()


# ==================================================
# TIME SYSTEM
# ==================================================
func _process(delta):
	time_accumulator += delta

	if time_accumulator >= real_seconds_per_game_minute:
		time_accumulator = 0.0
		advance_time(15)


func advance_time(minutes: int):
	game_minute += minutes

	if game_minute >= 60:
		game_minute = 0
		game_hour = (game_hour + 1) % 24

	update_time_state()
	update_clock_text()


func update_time_state():
	var time := game_hour + game_minute / 60.0
	var target_color : Color

	if time >= night_start or time < dawn_start:
		target_color = night_color
		current_time = TimeOfDay.NIGHT

	elif time >= dusk_start:
		var t := (time - dusk_start) / (night_start - dusk_start)
		target_color = day_color.lerp(night_color, t)

	elif time >= day_start:
		target_color = day_color
		current_time = TimeOfDay.DAY

	else:
		var t := (time - dawn_start) / (day_start - dawn_start)
		target_color = night_color.lerp(day_color, t)

	modulate = target_color
	update_glow(target_color)


func update_glow(color: Color):
	if not glow_manager:
		return

	var darkness := 1.0 - color.v
	glow_manager.visible = darkness > 0.05
	glow_manager.modulate.a = clamp(darkness, 0.0, 1.0)


# ==================================================
# CLOCK UI
# ==================================================
func create_clock_ui():
	var canvas := CanvasLayer.new()
	add_child(canvas)

	clock_label = Label.new()
	canvas.add_child(clock_label)

	clock_label.anchor_right = 1
	clock_label.anchor_bottom = 1
	clock_label.offset_right = -20
	clock_label.offset_bottom = -20
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	clock_label.add_theme_font_size_override("font_size", 18)

	update_clock_text()


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


# ==================================================
# WORLD GENERATION
# ==================================================
func generate_world():
	fill_water()
	generate_island()
	add_sand_edges()

	place_patches(DIRT, 0.3, 0.015)
	place_patches(MAGMA, 0.45, 0.02)

	for x in width:
		for y in height:
			var pos := Vector2i(x, y)
			if tilemap.get_cell_atlas_coords(pos) == MAGMA and randf() < 0.12:
				tilemap.set_cell(pos, SRC, LAVA)

	place_patches(WATER, 0.4, 0.018)
	place_patches(MUD, 0.55, 0.025)
	place_patches(CLAY, 0.6, 0.028)


func fill_water():
	for x in width:
		for y in height:
			tilemap.set_cell(Vector2i(x, y), SRC, WATER)


func generate_island():
	for x in width:
		for y in height:
			if noise.get_noise_2d(x, y) > -0.1:
				tilemap.set_cell(Vector2i(x, y), SRC, GRASS)


func add_sand_edges():
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			var pos := Vector2i(x, y)

			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if tilemap.get_cell_atlas_coords(pos + d) == WATER:
						tilemap.set_cell(pos, SRC, SAND)
						break


func place_patches(tile: Vector2i, threshold: float, scale: float):
	var old_freq := noise.frequency
	noise.frequency = scale

	for x in width:
		for y in height:
			if noise.get_noise_2d(x, y) > threshold:
				var pos := Vector2i(x, y)
				if tilemap.get_cell_atlas_coords(pos) == GRASS:
					tilemap.set_cell(pos, SRC, tile)

	noise.frequency = old_freq
