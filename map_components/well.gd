extends Area2D
class_name Well

# Answer point: a well in riddle mode, a CRT terminal in coding mode (see map.gd).
# Walking in opens it; while standing here, E / Enter opens it again.

signal interact

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")

var player_inside := false
var prompt_text := "Answer"
var _prompt: Label


func _ready():
	body_entered.connect(func(body):
		if body.name == "Player":
			player_inside = true
			_set_prompt(true)
			emit_signal("interact")
	)
	body_exited.connect(func(body):
		if body.name == "Player":
			player_inside = false
			_set_prompt(false)
	)


# _unhandled_input: keys typed into a popup / code editor / chat never reach this.
func _unhandled_input(event):
	if not player_inside or Global.input_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		emit_signal("interact")


func _set_prompt(on: bool) -> void:
	if _prompt == null:
		_prompt = Label.new()
		_prompt.text = "[E]  " + prompt_text
		_prompt.add_theme_font_override("font", FONT)
		_prompt.add_theme_font_size_override("font_size", 18)
		_prompt.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
		_prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.1))
		_prompt.add_theme_constant_override("outline_size", 6)
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.size = Vector2(160, 24)
		_prompt.position = Vector2(-80, -64)
		_prompt.z_index = 100
		add_child(_prompt)
	_prompt.visible = on
	if on:
		_prompt.modulate.a = 0.0
		create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.2)
