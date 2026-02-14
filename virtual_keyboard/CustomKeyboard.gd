extends PanelContainer
class_name CustomKeyboard

signal key_pressed(character: String)
signal backspace_pressed
signal enter_pressed

@onready var main_vbox = VBoxContainer.new()
const FONT_PATH = "res://Jersey10-Regular.ttf" 

# Store references to buttons to animate them via PC input
var key_nodes: Dictionary = {}

const ALPHA_ROWS = [
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L"],
	["SHIFT", "Z", "X", "C", "V", "B", "N", "M", "BKSP"],
	["SPACE", "ENTER"]
]

func _ready():
	# --- SCREEN SIZING LOGIC ---
	var screen_width = get_viewport_rect().size.x
	# Set max width to half of screen
	custom_minimum_size.x = screen_width / 2
	
	# Center the keyboard horizontally
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Tray Background
	var tray_style = StyleBoxFlat.new()
	tray_style.bg_color = Color(0, 0, 0, 0.2)
	add_theme_stylebox_override("panel", tray_style)
	
	main_vbox.add_theme_constant_override("separation", 3)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Ensure the internal vbox fills the constrained width
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	_build_number_row()
	_build_alpha_rows()

func _build_number_row():
	var num_grid = GridContainer.new()
	num_grid.columns = 10
	num_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num_grid.add_theme_constant_override("h_separation", 3)
	main_vbox.add_child(num_grid)
	
	for n in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]:
		num_grid.add_child(_create_key_button(n))

func _build_alpha_rows():
	for row_data in ALPHA_ROWS:
		var row_hbox = HBoxContainer.new()
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_theme_constant_override("separation", 3)
		main_vbox.add_child(row_hbox)
		
		for key_text in row_data:
			var btn = _create_key_button(key_text)
			if key_text in ["SPACE", "ENTER", "SHIFT", "BKSP"]:
				btn.size_flags_stretch_ratio = 1.5
			row_hbox.add_child(btn)

func _create_key_button(txt: String) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.focus_mode = Control.FOCUS_NONE
	
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 40
	btn.pivot_offset = Vector2(20, 20) # Center pivot for scaling
	
	# Store in dictionary for PC input lookup
	key_nodes[txt.to_upper()] = btn
	
	# Font Setup
	if FileAccess.file_exists(FONT_PATH):
		var dynamic_font = load(FONT_PATH)
		btn.add_theme_font_override("font", dynamic_font)
	
	# Translucent Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.15)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.1)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 20)
	
	btn.pressed.connect(_on_key_down.bind(txt))
	return btn

# --- ANIMATION LOGIC ---
func animate_key_press(key_txt: String):
	var clean_key = key_txt.to_upper()
	if key_nodes.has(clean_key):
		var btn = key_nodes[clean_key]
		
		# Ensure pivot is centered for smooth scaling/rotation
		btn.pivot_offset = btn.size / 2
		
		# Generate a random "cute" whitish shade (Off-white, cream, pale blue-white)
		var r = randf_range(0.8, 1.0)
		var g = randf_range(0.8, 1.0)
		var b = randf_range(0.9, 1.0)
		var random_white = Color(r, g, b, 1.0)
		
		# Create ONE single tween for everything
		var tween = create_tween().set_parallel(true)
		
		# 1. SMOOTH SCALE (Slightly slower for "liquid" feel)
		# Shrink slightly then pop back with a soft ease
		tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.1).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# 2. SMOOTH ROTATION (Gentle tilt)
		var tilt = randf_range(-4.0, 4.0)
		tween.tween_property(btn, "rotation_degrees", tilt, 0.1).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_property(btn, "rotation_degrees", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
		
		# 3. COLOR TRANSITION (To the random shade and back)
		# We brighten the button while changing its tint
		btn.modulate = random_white * 1.5 # Start brightened with the tint
		tween.tween_property(btn, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)
		
		# 4. TEMPORARY DEPTH
		btn.z_index = 5
		tween.finished.connect(func(): btn.z_index = 0)

		
func _on_key_down(key: String):
	animate_key_press(key)
	match key:
		"BKSP": backspace_pressed.emit()
		"ENTER": enter_pressed.emit()
		"SPACE": key_pressed.emit(" ")
		"SHIFT": pass
		_: key_pressed.emit(key)
