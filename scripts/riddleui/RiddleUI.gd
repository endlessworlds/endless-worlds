extends CanvasLayer
class_name RiddleUI

# ================= NODES =================
@onready var riddle_label: Label = $Panel/VBoxContainer/RiddleText
@onready var hint_container: HBoxContainer = $Panel/VBoxContainer/HintsRow
@onready var tooltip: Label = $Panel/VBoxContainer/HintTooltip

# ================= DATA =================
var hints: Array[String] = []
var bulbs: Array[HintBulb] = []
var unlocked_count := 0


# ==================================================
func _ready() -> void:
	tooltip.text = ""
	tooltip.visible = true

	# Collect all HintBulb children (any name is fine)
	for child in hint_container.get_children():
		if child is HintBulb:
			bulbs.append(child as HintBulb)
			child.set_off()
			child.hovered.connect(_on_bulb_hovered)
			child.unhovered.connect(_on_bulb_unhovered)


# ==================================================
# CALLED FROM Map.gd WHEN GEMINI RETURNS DATA
# ==================================================

func setup_riddle(data: Dictionary) -> void:
	# Set the riddle text
	riddle_label.text = str(data.get("riddle", ""))

	# Clear the existing hints array
	hints.clear()

	# Get hints from data (no duplicate declaration)
	var raw_hints: Array = data.get("hints", [])
	for h in raw_hints:
		hints.append(str(h))

	unlocked_count = 0

	# Turn all bulbs off
	for bulb in bulbs:
		bulb.set_off()

	# Assign hints to bulbs
	for i in range(min(hints.size(), bulbs.size())):
		bulbs[i].hint_text = hints[i]


# ==================================================
# CALLED WHEN PLAYER COLLECTS A HINT
# ==================================================
func unlock_next_hint() -> void:
	if unlocked_count >= bulbs.size():
		return

	bulbs[unlocked_count].set_on()
	unlocked_count += 1


# ==================================================
# HOVER EVENTS
# ==================================================
func _on_bulb_hovered(text: String) -> void:
	tooltip.text = text


func _on_bulb_unhovered() -> void:
	tooltip.text = ""
