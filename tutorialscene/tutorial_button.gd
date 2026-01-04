extends Button

@export var tutorial_scene: PackedScene

func _ready():
	pressed.connect(_open)

func _open():
	var overlay = tutorial_scene.instantiate()
	get_tree().current_scene.add_child(overlay)
	overlay.open()
