extends CanvasLayer
class_name RiddleUI

# ================= NODES =================
@onready var panel: Panel = $Panel
@onready var toggle_button: TextureButton = $Panel/RiddleToggle
@onready var riddle_label: Label = $Panel/RiddleText
@onready var bulb_column: VBoxContainer = $Panel/HintsColumn
@onready var tooltip: Label = $Panel/HintTooltip

# ================= DATA =================
var hints: Array[String] = []
var bulbs: Array[HintBulb] = []
var unlocked_count := 0
var riddle_visible := false

# ==================================================
func _ready() -> void:
	# --- Initial state ---
	riddle_label.visible = false
	riddle_label.modulate.a = 0.0
	riddle_visible = false

	tooltip.visible = false
	tooltip.text = ""
	var sb := StyleBoxTexture.new()   # same pixel frame as the other HUD panels
	sb.texture = preload("res://assets/ui/pixel/frame_normal.png")
	sb.set_texture_margin_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	tooltip.add_theme_stylebox_override("normal", sb)
	tooltip.add_theme_font_size_override("font_size", 22)
	tooltip.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Long riddles / hints wrap to the screen instead of running off a phone screen.
	riddle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit_riddle()
	get_viewport().size_changed.connect(_fit_riddle)

	# Toggle riddle
	toggle_button.pressed.connect(_on_toggle_pressed)

	# Collect bulbs
	for child in bulb_column.get_children():
		if child is HintBulb:
			var bulb := child as HintBulb
			bulbs.append(bulb)
			bulb.set_off()
			bulb.hovered.connect(_on_bulb_hovered.bind(bulb))
			bulb.unhovered.connect(_on_bulb_unhovered)

func _fit_riddle() -> void:
	var w := minf(900.0, get_viewport().get_visible_rect().size.x - 40.0)
	riddle_label.offset_left = -w * 0.5
	riddle_label.offset_right = w * 0.5


# ==================================================
# SETUP RIDDLE (called from Map.gd)
# ==================================================
func setup_riddle(data: Dictionary) -> void:
	riddle_label.text = str(data.get("riddle", ""))

	# Reset riddle visibility
	riddle_visible = false
	riddle_label.visible = false
	riddle_label.modulate.a = 0.0

	# Setup hints
	hints.clear()
	unlocked_count = 0

	var raw_hints: Array = data.get("hints", [])
	for h in raw_hints:
		hints.append(str(h))

	# Reset bulbs
	for bulb in bulbs:
		bulb.set_off()

	for i in range(min(hints.size(), bulbs.size())):
		bulbs[i].hint_text = hints[i]

# ==================================================
# TOGGLE RIDDLE TEXT
# ==================================================
func _on_toggle_pressed() -> void:
	riddle_visible = !riddle_visible
	var tween := create_tween()

	if riddle_visible:
		riddle_label.visible = true
		riddle_label.modulate.a = 0.0
		tween.tween_property(riddle_label, "modulate:a", 1.0, 0.25)
	else:
		tween.tween_property(riddle_label, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): riddle_label.visible = false)

# ==================================================
# UNLOCK HINTS
# ==================================================
func unlock_next_hint() -> void:
	if unlocked_count >= bulbs.size():
		return

	bulbs[unlocked_count].set_on()
	unlocked_count += 1

# ==================================================
# HOVER LOGIC: a framed card to the right of the bulb, centred on it and kept on screen
# ==================================================
func _on_bulb_hovered(text: String, bulb: HintBulb) -> void:
	var vp := get_viewport().get_visible_rect().size
	var left := bulb.global_position.x + bulb.size.x + 10.0 - panel.global_position.x
	var w := clampf(vp.x - left - 24.0, 180.0, 420.0)
	tooltip.text = "💡 Hint %d
%s" % [bulbs.find(bulb) + 1, text]
	var font := tooltip.get_theme_font("font")
	var fs := tooltip.get_theme_font_size("font_size")
	var h := font.get_multiline_string_size(tooltip.text, HORIZONTAL_ALIGNMENT_LEFT, w - 32.0, fs).y + 22.0
	var mid := bulb.global_position.y + bulb.size.y * 0.5 - panel.global_position.y
	tooltip.position = Vector2(left, clampf(mid - h * 0.5, 8.0, vp.y - h - 8.0))
	tooltip.size = Vector2(w, h)
	tooltip.visible = true



func _on_bulb_unhovered() -> void:
	tooltip.visible = false
	tooltip.text = ""
