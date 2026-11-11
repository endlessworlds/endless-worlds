extends Node2D

@export var firefly_count := 100
@export var spawn_radius := 600.0

@onready var time_system: Node = get_tree().current_scene.get_node("TimeSystem")

func _ready():
	_spawn_fireflies()

func _process(_delta):
	if time_system == null:
		return

	var h: int = time_system.game_hour
	visible = (h >= 19 or h <= 4) # ✅ 7PM → 4AM

func _spawn_fireflies():
	for i in range(Screen.fx_count(firefly_count, 0.3)):
		var f := Sprite2D.new()
		f.texture = _make_pixel_texture()
		f.modulate = Color(1.0, 1.0, 0.6, 0.0)
		f.scale = Vector2(2, 2)
		f.position = Vector2(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		add_child(f)

		_firefly_blink(f)
		_firefly_drift(f)

func _make_pixel_texture() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _firefly_blink(f: Sprite2D):
	var t := create_tween()
	t.set_loops()

	var max_a := randf_range(0.4, 0.9)
	var blink_in := randf_range(0.2, 0.6)
	var blink_out := randf_range(0.2, 0.6)
	var wait := randf_range(0.3, 1.2)

	t.tween_property(f, "modulate:a", max_a, blink_in)
	t.tween_interval(wait)
	t.tween_property(f, "modulate:a", 0.0, blink_out)
	t.tween_interval(wait)

func _firefly_drift(f: Sprite2D):
	_firefly_drift_step(f)

func _firefly_drift_step(f: Sprite2D):
	var t := create_tween()
	var offset := Vector2(randf_range(-30, 30), randf_range(-20, 20))
	t.tween_property(f, "position", f.position + offset, randf_range(2.0, 4.0))
	t.tween_callback(func(): _firefly_drift_step(f))
