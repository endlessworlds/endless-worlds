extends CanvasLayer
class_name AnswerPopup

@onready var message: Label = $Panel/VBoxContainer/MessageLabel
@onready var input: LineEdit = $Panel/VBoxContainer/AnswerInput
@onready var submit: Button = $Panel/VBoxContainer/SubmitButton

var correct_answer := ""
var hearts: HeartSystem
var map_ref

func open(solution: String, heart_system: HeartSystem, map):
	visible = true
	input.text = ""
	message.text = "Enter your answer"
	correct_answer = solution.to_lower()
	hearts = heart_system
	map_ref = map
	input.grab_focus()

func _ready():
	visible = false
	submit.pressed.connect(_on_submit)
	input.text_submitted.connect(func(_t): _on_submit())

func _on_submit():
	var user_answer := input.text.strip_edges().to_lower()

	if user_answer == correct_answer:
		message.text = "🎉 VICTORY!"
		map_ref.add_score(50)
		await get_tree().create_timer(1.5).timeout
		visible = false
	else:
		message.text = "❌ Try again"
		hearts.damage(1)
		input.text = ""
