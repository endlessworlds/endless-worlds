extends Camera2D
class_name CameraShake

var shake_strength := 10.0
var shake_duration := 0.3

func shake():
	var tween := create_tween()
	var steps := 8

	for i in range(steps):
		var offset := Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		tween.tween_property(self, "offset", offset, shake_duration / steps)

	tween.tween_property(self, "offset", Vector2.ZERO, 0.1)
