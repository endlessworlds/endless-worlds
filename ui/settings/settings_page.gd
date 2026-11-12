extends CanvasLayer
class_name SettingsPage

# Settings: graphics quality, volume (master / music / effects / voice), vibration (phones), fullscreen, install.
# Opened from the home screen and from the pause menus. Pauses a solo game while open.
#   SettingsPage.open(parent)

var _was_paused := false
var _on_close: Callable


static func open(parent: Node, on_close := Callable()) -> SettingsPage:
	var p := SettingsPage.new()
	p._on_close = on_close
	parent.add_child(p)
	return p


func _ready() -> void:
	_was_paused = get_tree().paused
	if not Net.active:
		get_tree().paused = true
	var v := PixelUI.page(self, "⚙ Settings", 560, _close)

	var gfx := PixelUI.button(Screen.graphics_label(), func(): pass)
	gfx.pressed.connect(func():
		Screen.cycle_graphics()
		gfx.text = Screen.graphics_label())
	v.add_child(gfx)
	var note := PixelUI.label("Low = smoother on phones and older computers", 20, PixelUI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

	_volume_row(v, "Master", Global.sound_volume, func(val): Global.sound_volume = val)
	_volume_row(v, "Music", Global.music_volume, func(val): Global.music_volume = val)
	_volume_row(v, "Effects", Global.sfx_volume, func(val): Global.sfx_volume = val)
	_volume_row(v, "Voice", Global.voice_volume, func(val): Global.voice_volume = val)

	if Screen.is_touch:
		var vib := PixelUI.button("", func(): pass)
		var vib_text := func(): vib.text = "Vibration: %s" % ("On" if Global.vibration else "Off")
		vib_text.call()
		vib.pressed.connect(func():
			Global.vibration = not Global.vibration
			Global.save_game()
			vib_text.call()
			Screen.vibrate(60))
		v.add_child(vib)

	if Screen.can_fullscreen():
		var fs := PixelUI.button(Screen.fullscreen_label(), func(): pass)
		fs.pressed.connect(func():
			Screen.toggle_fullscreen()
			await get_tree().create_timer(0.4, true).timeout
			if is_instance_valid(fs):
				fs.text = Screen.fullscreen_label())
		v.add_child(fs)

	if Screen.can_install():
		v.add_child(PixelUI.button("📲 Install app", func(): Screen.install_app(self)))

	var done := PixelUI.button("Done", _close, true)
	done.custom_minimum_size = Vector2(0, 56)
	v.add_child(done)


# One labelled 0..100% slider; `set_value` stores the new value, then the sound is re-applied.
func _volume_row(v: VBoxContainer, title: String, value: float, set_value: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var sl := PixelUI.label(title, 28, PixelUI.CREAM, false)
	sl.custom_minimum_size.x = 110
	row.add_child(sl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(200, 36)
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var pct := PixelUI.label("", 26, PixelUI.GOLD, false)
	pct.custom_minimum_size.x = 64
	row.add_child(pct)
	var show_pct := func(val: float): pct.text = "Off" if val <= 0.0 else "%d%%" % int(round(val * 100.0))
	show_pct.call(value)
	slider.value_changed.connect(func(val: float):
		set_value.call(val)
		Global.apply_sound()
		show_pct.call(val))
	slider.drag_ended.connect(func(_changed): Global.save_game())


func _close() -> void:
	Global.save_game()
	get_tree().paused = _was_paused
	queue_free()
	if _on_close.is_valid():
		_on_close.call()
