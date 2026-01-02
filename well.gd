extends Area2D
class_name Well

signal interact

var player_inside := false

func _ready():
	body_entered.connect(func(body):
		if body.name == "Player":
			emit_signal("interact")
	)
	

func _input(event):
	if player_inside and event.is_action_pressed("ui_accept"):
		emit_signal("interact")
