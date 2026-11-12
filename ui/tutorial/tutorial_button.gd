extends Button

# "How to play": a pixel book medallion (tools/make_ui_art.py), no caption.
# The scenes anchor it bottom-centre; it sizes itself and sits just above the bottom edge.

func _ready():
	scale = Vector2.ONE
	flat = true
	focus_mode = Control.FOCUS_NONE
	modulate = Color(1, 1, 1, 0.92)
	icon = preload("res://assets/ui/tutorial_badge.png")
	tooltip_text = "How to play"
	size = get_combined_minimum_size()
	offset_left = -size.x * 0.5
	offset_right = size.x * 0.5
	offset_top = -size.y - 8.0
	offset_bottom = -8.0
	PixelUI.juicy(self)
	pressed.connect(_open)

func _open():
	var page := TutorialOverlay.new()
	get_tree().current_scene.add_child(page)
	page.open()
