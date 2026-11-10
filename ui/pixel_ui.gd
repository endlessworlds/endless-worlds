class_name PixelUI

# Shared look for every full-screen page (stats, journal, tutorial, cards):
# navy panel with a gold pixel frame, Jersey font, cream text.

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")
const FRAME := preload("res://assets/ui/pixel/frame_normal.png")
const FRAME_HOVER := preload("res://assets/ui/pixel/frame_hover.png")
const FRAME_ACTIVE := preload("res://assets/ui/pixel/frame_active.png")
const GOLD := Color(1.0, 0.8, 0.28)
const CREAM := Color(0.96, 0.92, 0.82)
const MUTED := Color(0.66, 0.7, 0.82)
const PAGE_LAYER := 60   # above home UI, HUD, multiplayer and Bolt layers


static func box(tex: Texture2D = FRAME, pad_x: int = 18, pad_y: int = 8) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(12)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func label(t: String, size: int = 24, col: Color = CREAM, center := true) -> Label:
	var l := Label.new()
	l.text = t
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func button(t: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 28)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, CREAM)
	b.add_theme_stylebox_override("normal", box(FRAME_ACTIVE if primary else FRAME, 18, 4))
	b.add_theme_stylebox_override("hover", box(FRAME_HOVER, 18, 4))
	b.add_theme_stylebox_override("pressed", box(FRAME_ACTIVE, 18, 4))
	b.pressed.connect(cb)
	return b


static func panel(tex: Texture2D = FRAME, pad_x: int = 18, pad_y: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(tex, pad_x, pad_y))
	return p


# Builds dim background + centered framed panel with a title and a close button
# inside `layer`. Returns the content VBox to fill. Esc also closes.
static func page(layer: CanvasLayer, title: String, width: float, on_close: Callable) -> VBoxContainer:
	layer.layer = PAGE_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var p := panel(FRAME, 30, 22)
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var t := label(title, 54, GOLD, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_color_override("font_shadow_color", Color(0.45, 0.2, 0.0, 0.9))
	t.add_theme_constant_override("shadow_offset_y", 3)
	head.add_child(t)
	var close := button("✕", on_close)
	close.custom_minimum_size = Vector2(48, 48)
	close.shortcut = Shortcut.new()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	close.shortcut.events = [esc]
	head.add_child(close)

	# pop in
	p.modulate.a = 0.0
	p.scale = Vector2(0.92, 0.92)
	p.resized.connect(func(): p.pivot_offset = p.size * 0.5)
	var tw := layer.create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.16)
	return v
