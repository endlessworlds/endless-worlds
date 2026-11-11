extends CanvasLayer
class_name TouchControls

# On-screen buttons for phones and tablets (pause, jump, answer, dash...).
# TouchScreenButton is used instead of Button so a thumb can press jump while the
# other thumb is still on the joystick (GUI buttons only see one finger).
#
#   var tc := TouchControls.new()
#   add_child(tc)
#   tc.add("jump", "icon:jump", Vector2(1, 1), Vector2(-24, -96), 96, "jump")        # fires an input action
#   tc.add("pause", "II", Vector2(0, 0), Vector2(14, 14), 60, "", _open_pause)  # or calls a function
#   tc.show_when = func(): return not popup.visible                            # hide during popups
#
# `anchor` is a screen corner / edge (0..1); `offset` moves the button in from it.

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")

var show_when: Callable          # returns bool; buttons hide while it's false
var _buttons := {}               # id -> {btn, anchor, offset, size, touch_only}
var _tex_cache := {}


func _ready() -> void:
	layer = 25   # above the HUD, below Bolt's menu, pages and popups
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()


# touch_only = false keeps the button on desktop too (e.g. the pause button).
func add(id: String, text: String, anchor: Vector2, offset: Vector2, diameter: float,
		action := "", on_press := Callable(), touch_only := true, wide := 1.0) -> TouchScreenButton:
	var size := Vector2(diameter * wide, diameter)
	var b := TouchScreenButton.new()
	var minimal := text.begins_with("icon:")   # icon buttons: just a faint ring + the icon
	b.texture_normal = _make_tex(size, false, minimal)
	b.texture_pressed = _make_tex(size, true, minimal)
	b.passby_press = false
	if not action.is_empty():
		b.action = action
	if on_press.is_valid():
		b.pressed.connect(on_press)
	if text.begins_with("icon:"):   # a small drawn icon instead of a word
		var ic := Sprite2D.new()
		ic.texture = _make_icon(text.trim_prefix("icon:"), int(diameter * 0.42))
		ic.modulate = Color(1, 1, 1, 0.9)
		ic.position = size * 0.5
		b.add_child(ic)
		add_child(b)
		_buttons[id] = {"btn": b, "anchor": anchor, "offset": offset, "size": size, "touch_only": touch_only}
		_layout()
		return b
	var l := Label.new()
	l.text = text
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", int(diameter * (0.42 if text.length() <= 3 or wide > 1.5 else 0.3)))
	l.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.1, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	add_child(b)
	_buttons[id] = {"btn": b, "anchor": anchor, "offset": offset, "size": size, "touch_only": touch_only}
	_layout()
	return b


func get_button(id: String) -> TouchScreenButton:
	return _buttons[id].btn if _buttons.has(id) else null


func set_label(id: String, text: String) -> void:
	var b := get_button(id)
	if b and b.get_child_count() > 0 and b.get_child(0) is Label:
		(b.get_child(0) as Label).text = text


# Context buttons (e.g. "Answer" only next to a well).
func set_visible_button(id: String, on: bool) -> void:
	if _buttons.has(id):
		_buttons[id]["hidden"] = not on


func _process(_delta: float) -> void:
	var allowed: bool = show_when.call() if show_when.is_valid() else true
	for id in _buttons:
		var e: Dictionary = _buttons[id]
		var want: bool = allowed and not e.get("hidden", false) and (Screen.is_touch or not e.touch_only)
		if e.btn.visible != want:
			e.btn.visible = want


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	for id in _buttons:
		var e: Dictionary = _buttons[id]
		var a: Vector2 = e.anchor
		e.btn.position = Vector2(a.x * vp.x, a.y * vp.y) + e.offset - a * e.size


# Rounded translucent pill / circle, drawn once per size.
func _make_tex(size: Vector2, pressed: bool, minimal := false) -> Texture2D:
	var key := "%dx%d%s%s" % [int(size.x), int(size.y), "p" if pressed else "", "m" if minimal else ""]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var w := int(size.x)
	var h := int(size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var fill := Color(0.06, 0.08, 0.16, 0.62) if not pressed else Color(0.95, 0.62, 0.15, 0.85)
	var edge := Color(1.0, 0.82, 0.35, 0.85)
	var edge_w := 3.0
	if minimal:
		fill = Color(1, 1, 1, 0.08) if not pressed else Color(1, 1, 1, 0.28)
		edge = Color(1, 1, 1, 0.45)
		edge_w = 1.6
	for y in h:
		for x in w:
			# distance to the pill's centre line
			var cx := clampf(x + 0.5, r, w - r)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - r).length()
			if d <= r - edge_w:
				img.set_pixel(x, y, fill)
			elif d <= r:
				img.set_pixel(x, y, edge)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


# Pixel icons for buttons: "jump" = a plain up arrow.
func _make_icon(kind: String, px: int) -> Texture2D:
	var n := maxi(12, px)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := n * 0.5
	for y in n:
		for x in n:
			var fx := x + 0.5
			var fy := y + 0.5
			var on := false
			match kind:
				"jump":
					var head := n * 0.45                                  # a plain up arrow
					if fy > n * 0.08 and fy < head and absf(fx - c) <= (fy - n * 0.08) / (head - n * 0.08) * n * 0.36:
						on = true
					elif fy >= head and fy < n * 0.92 and absf(fx - c) <= n * 0.09:
						on = true
			if on:
				img.set_pixel(x, y, Color(1.0, 0.96, 0.86))
	# dark outline so it reads on any background
	var out := img.duplicate() as Image
	for y in n:
		for x in n:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n and img.get_pixelv(q).a > 0.0:
					out.set_pixel(x, y, Color(0.05, 0.04, 0.1, 0.9))
					break
	return ImageTexture.create_from_image(out)


# True when `p` (viewport coordinates) lands on a visible button.
func hit_test(p: Vector2) -> bool:
	for id in _buttons:
		var e: Dictionary = _buttons[id]
		if e.btn.visible and Rect2(e.btn.position, e.size).has_point(p):
			return true
	return false
