extends TextureRect
class_name HintBulb

@export var bulb_texture: Texture2D
@export var index: int = 0

var hint_text: String = ""
var is_on := false

var atlas: AtlasTexture

signal hovered(text: String)
signal unhovered


func _ready():
	custom_minimum_size = Vector2(48, 48)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Create AtlasTexture
	atlas = AtlasTexture.new()
	atlas.atlas = bulb_texture
	texture = atlas

	set_off()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_on():
	is_on = true
	atlas.region = Rect2(
		0,
		0,
		bulb_texture.get_width() / 2,
		bulb_texture.get_height()
	)


func set_off():
	is_on = false
	atlas.region = Rect2(
		bulb_texture.get_width() / 2,
		0,
		bulb_texture.get_width() / 2,
		bulb_texture.get_height()
	)


func _on_mouse_entered():
	if is_on:
		emit_signal("hovered", hint_text)


func _on_mouse_exited():
	emit_signal("unhovered")
