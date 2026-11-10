extends Button

func _ready():
	pressed.connect(_open)

func _open():
	var page := TutorialOverlay.new()
	get_tree().current_scene.add_child(page)
	page.open()
