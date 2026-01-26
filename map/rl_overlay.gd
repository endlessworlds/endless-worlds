extends CanvasLayer

@onready var btn: TextureButton = $ToggleButton
@onready var panel: Panel = $Panel
@onready var diff_label: Label = $Panel/VBox/DifficultyLabel
@onready var q_label: Label = $Panel/VBox/QText 

var rl
var grid: GridContainer
var close_btn: Button # Reference for our new close button

func _ready():
	rl = Global.rl

	# -------- MAIN TOGGLE BUTTON --------
	btn.texture_normal = load("res://assets/rl.png")
	btn.z_index = 1000
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 0.5
	btn.anchor_bottom = 0.5
	btn.offset_left = -120
	btn.offset_right = -10
	btn.offset_top = -32
	btn.offset_bottom = 32
	btn.modulate.a = 0.7
	btn.pressed.connect(toggle)

	# -------- PANEL SETUP --------
	panel.visible = false
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340 
	panel.offset_right = -10
	panel.offset_top = -200 
	panel.offset_bottom = 350

	var vbox = $Panel/VBox
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 12)
	
	# -------- NEW: CLOSE BUTTON --------
	close_btn = Button.new()
	close_btn.text = "CLOSE OVERLAY"
	# Optional: Style the close button to match your theme
	var font = load("res://Jersey10-Regular.ttf")
	close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(toggle) # Connect to same toggle function
	vbox.add_child(close_btn) 
	# Move to top of VBox so it's easy to find
	vbox.move_child(close_btn, 0) 

	# Header Styling
	diff_label.add_theme_font_override("font", font)
	diff_label.add_theme_font_size_override("font_size", 32)
	
	# Sub-header
	q_label.text = "EXPECTED REWARD [ Q(s,a) ]"
	q_label.add_theme_font_override("font", font)
	q_label.add_theme_font_size_override("font_size", 22)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.modulate = Color(0.3, 0.9, 0.3)

	# The Q-Table Grid
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 40)
	vbox.add_child(grid)

	set_process(true)

func _process(_d):
	if panel.visible:
		update_text()

## Logic updated to hide 'btn' when panel is shown
func toggle():
	panel.visible = !panel.visible
	# Hide the main button if panel is open, show it if panel is closed
	btn.visible = !panel.visible 
	
	if panel.visible:
		update_text()

func update_text():
	# ... (Rest of your update_text logic remains exactly the same)
	diff_label.text = "DIFF: %s\nSTATE: %s\nACTION: %s" % [
		rl.current_diff,
		rl.prev_state,
		rl.prev_action
	]

	for child in grid.get_children():
		child.queue_free()

	var font = load("res://Jersey10-Regular.ttf")
	var states := ["BORING", "CHALLENGED", "TOO_HARD"]
	
	for st in states:
		var st_lbl = Label.new()
		st_lbl.text = "[ %s ]" % st
		st_lbl.add_theme_font_override("font", font)
		st_lbl.add_theme_font_size_override("font_size", 22)
		st_lbl.modulate = Color(0.9, 0.9, 0.2)
		grid.add_child(st_lbl)
		grid.add_child(Label.new()) # Spacer

		if not rl.q.has(st):
			for a in rl.ACTIONS:
				_add_row(a, "--", font)
			continue

		for a in rl.ACTIONS:
			_add_row(a, "%.4f" % float(rl.q[st].get(a, 0.0)), font)

# Helper to keep update_text clean
func _add_row(action_name, value_text, font):
	var action_lbl = Label.new()
	var value_lbl = Label.new()
	action_lbl.text = "  a_%s" % action_name.to_lower()
	value_lbl.text = value_text
	action_lbl.add_theme_font_override("font", font)
	action_lbl.add_theme_font_size_override("font_size", 20)
	value_lbl.add_theme_font_override("font", font)
	value_lbl.add_theme_font_size_override("font_size", 20)
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(action_lbl)
	grid.add_child(value_lbl)
