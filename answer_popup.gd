extends CanvasLayer
class_name AnswerPopup

@onready var message: Label = $Panel/VBoxContainer/MessageLabel
@onready var input: LineEdit = $Panel/VBoxContainer/AnswerInput
@onready var submit: Button = $Panel/VBoxContainer/SubmitButton
@onready var close_button: Button = $Panel/CloseButton

var correct_answer: String = ""
var hearts: HeartSystem
var map_ref

func _ready():
	visible = false
	submit.pressed.connect(_on_submit)
	close_button.pressed.connect(close)

	# 🚫 Prevent Enter key from submitting
	input.gui_input.connect(_block_enter_key)

# =============================
# OPEN POPUP
# =============================
func open(solution: String, heart_system: HeartSystem, map):
	if solution.is_empty():
		push_error("❌ AnswerPopup opened with EMPTY solution!")
		return

	visible = true
	input.text = ""
	message.text = "Enter your answer"
	correct_answer = solution.to_lower()
	hearts = heart_system
	map_ref = map

	input.grab_focus()

# =============================
# BLOCK ENTER KEY
# =============================
func _block_enter_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()

# =============================
# ESC TO CLOSE
# =============================
func _input(event):
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()

func close():
	visible = false
	input.text = ""
	message.text = ""

# =============================
# SUBMIT LOGIC
# =============================
func _on_submit():
	var user_answer := input.text.strip_edges().to_lower()

	print(user_answer + " " + correct_answer)

	if user_answer == correct_answer:
		message.text = "🎉 VICTORY!"
		
		Global.add_score(50)
		Global.next_level()   # ⭐ LEVEL UP
		
		await get_tree().create_timer(1.5).timeout
		close()
		
		# 🏠 GO BACK TO HOME
		get_tree().change_scene_to_file("res://HomeScreen.tscn")

	else:
		message.text = "❌ Try again"
		hearts.damage(1)
		input.text = ""
		await get_tree().create_timer(1.0).timeout
		close()
