extends CanvasLayer
class_name TutorialOverlay

# How-to-play page (pixel style): short looping clips with one line each.

const SLIDES := [
	["res://assets/tutorial/slide1.ogv", "Type any topic, or tap one of the topic chips"],
	["res://assets/tutorial/slide2.ogv", "Click the magnifying glass to read the riddle"],
	["res://assets/tutorial/slide3.ogv", "Walk over hint bulbs to collect them"],
	["res://assets/tutorial/slide4.ogv", "Hover a lit bulb to read its hint"],
	["res://assets/tutorial/slide5.ogv", "Walk into a well to answer the riddle"],
	["res://assets/tutorial/slide6.ogv", "Avoid lava and deep water. Have fun learning!"],
]
const TOUCH_KEYS := "Joystick move (push far to sprint) · JUMP hop · II pause · tap Bolt to talk, torch and chat"
const KEYS := "WASD move · Shift sprint · Space jump · V talk to Bolt · F torch · T chat · Esc pause"

var _video: VideoStreamPlayer
var _text: Label
var _count: Label
var _prev: Button
var _next: Button
var _i := 0


func open() -> void:
	var v := PixelUI.page(self, "🎯 How to play", 760, queue_free)
	var frame := PixelUI.panel(PixelUI.FRAME, 6, 6)
	v.add_child(frame)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.loop = true
	var vw := minf(640.0, PixelUI.avail_width(60.0))
	_video.custom_minimum_size = Vector2(vw, vw * 9.0 / 16.0)
	frame.add_child(_video)
	_text = PixelUI.label("", 30)
	v.add_child(_text)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	v.add_child(nav)
	_prev = PixelUI.button("Back", _go.bind(-1))
	_prev.custom_minimum_size.x = 150
	nav.add_child(_prev)
	_count = PixelUI.label("", 26, PixelUI.MUTED)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_count)
	_next = PixelUI.button("Next", _go.bind(1), true)
	_next.custom_minimum_size.x = 150
	nav.add_child(_next)
	var keys := PixelUI.label(TOUCH_KEYS if Screen.is_touch else KEYS, 20, PixelUI.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = minf(640.0, PixelUI.avail_width(60.0))
	v.add_child(keys)
	_go(0)


func _go(step: int) -> void:
	if _i + step >= SLIDES.size():
		queue_free()
		return
	_i = clampi(_i + step, 0, SLIDES.size() - 1)
	_video.stream = load(SLIDES[_i][0])
	_video.play()
	_text.text = SLIDES[_i][1]
	if Screen.is_touch:
		_text.text = _text.text.replace("Click", "Tap").replace("Hover", "Tap")
	_count.text = "%d / %d" % [_i + 1, SLIDES.size()]
	_prev.disabled = _i == 0
	_next.text = "Got it!" if _i == SLIDES.size() - 1 else "Next"
