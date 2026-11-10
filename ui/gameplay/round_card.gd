extends CanvasLayer
class_name RoundCard

# Centered glass card used for "Level cleared" and the pause menu.
#   RoundCard.show_card(parent, "Title", "body text", [["Next ▶", callable], ...])

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")


static func show_card(parent: Node, title: String, body: String, buttons: Array, pause_game := false) -> RoundCard:
	var card := RoundCard.new()
	card.layer = 90
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(card)
	card._build(title, body, buttons)
	if pause_game:
		parent.get_tree().paused = true
	return card


func _build(title: String, body: String, buttons: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.box(PixelUI.FRAME, 30, 24))
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", FONT)
	t.add_theme_font_size_override("font_size", 56)
	t.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	t.add_theme_color_override("font_shadow_color", Color(0.6, 0.2, 0.0, 0.8))
	t.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(t)

	if not body.is_empty():
		var b := RichTextLabel.new()
		b.bbcode_enabled = true
		b.fit_content = true
		b.scroll_active = false
		b.text = "[center]%s[/center]" % body
		b.custom_minimum_size = Vector2(460, 0)
		b.add_theme_font_override("normal_font", FONT)
		b.add_theme_font_size_override("normal_font_size", 26)
		b.add_theme_color_override("default_color", Color(0.88, 0.92, 1.0))
		v.add_child(b)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var first: Button = null
	for spec in buttons:
		var btn := PixelUI.button(spec[0], func(): pass, first == null)
		btn.custom_minimum_size = Vector2(190, 54)
		btn.focus_mode = Control.FOCUS_ALL
		var cb: Callable = spec[1]
		btn.pressed.connect(func():
			get_tree().paused = false
			queue_free()
			cb.call())
		row.add_child(btn)
		if first == null:
			first = btn
	if first:
		first.call_deferred("grab_focus")

	# pop-in
	panel.pivot_offset = Vector2(260, 120)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
