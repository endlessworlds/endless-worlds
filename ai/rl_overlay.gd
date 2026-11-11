extends CanvasLayer

# "Difficulty AI" button (right edge) + page: shows what the Q-learning model thinks.
# The page is built once and only its texts are refreshed, so nothing flickers or jumps;
# it is a normal pixel page (fits any screen, ✕ / Esc closes, game buttons hide behind it).

const STATES := ["BORING", "CHALLENGED", "TOO_HARD"]
const STATE_NAMES := {"BORING": "Too easy", "CHALLENGED": "Just right", "TOO_HARD": "Too hard"}
const ACTION_NAMES := {"DOWN": "Easier", "SAME": "Same", "UP": "Harder"}

@onready var btn: TextureButton = $ToggleButton
@onready var panel: Panel = $Panel          # old scene node, no longer used

var rl
var _page: CanvasLayer
var _summary: Label
var _cells := {}            # "STATE/ACTION" -> Label
var _refresh_t := 0.0


func _ready() -> void:
	rl = Global.rl
	panel.visible = false
	btn.texture_normal = load("res://assets/rl.png")
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 0.5
	btn.anchor_bottom = 0.5
	btn.offset_left = -70
	btn.offset_right = -10
	btn.offset_top = -30
	btn.offset_bottom = 30
	btn.modulate.a = 0.75
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "Difficulty AI"
	btn.pressed.connect(toggle)


func toggle() -> void:
	if is_instance_valid(_page):
		_close()
	else:
		_open()


func _close() -> void:
	if is_instance_valid(_page):
		_page.queue_free()
	_page = null
	_cells.clear()
	btn.visible = true


func _open() -> void:
	if rl == null:
		rl = Global.rl
	if rl == null:
		return
	btn.visible = false
	_page = CanvasLayer.new()
	add_child(_page)
	var v := PixelUI.page(_page, "🧠 Difficulty AI", 620, _close)
	var intro := PixelUI.label("The game learns how hard to make your riddles. After each round it scores the choice it made; higher numbers = better choices.", 20, PixelUI.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = minf(540.0, PixelUI.avail_width(60.0))
	v.add_child(intro)
	_summary = PixelUI.label("", 28, PixelUI.GOLD)
	v.add_child(_summary)

	var grid := GridContainer.new()
	grid.columns = rl.ACTIONS.size() + 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	grid.add_child(PixelUI.label("Last round felt", 20, PixelUI.MUTED, false))
	for a in rl.ACTIONS:
		grid.add_child(PixelUI.label(str(ACTION_NAMES.get(a, a)), 22, PixelUI.MUTED))
	for st in STATES:
		var name_lbl := PixelUI.label(str(STATE_NAMES.get(st, st)), 24, PixelUI.CREAM, false)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_lbl)
		for a in rl.ACTIONS:
			var cell := PixelUI.panel(PixelUI.FRAME, 10, 4)
			cell.custom_minimum_size = Vector2(96, 0)
			var l := PixelUI.label("--", 24)
			cell.add_child(l)
			grid.add_child(cell)
			_cells["%s/%s" % [st, a]] = l
	_refresh()


func _process(delta: float) -> void:
	if not is_instance_valid(_page):
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.5
		_refresh()


func _refresh() -> void:
	if _summary == null or not is_instance_valid(_summary):
		return
	var felt := str(STATE_NAMES.get(rl.prev_state, "-"))
	var did := str(ACTION_NAMES.get(rl.prev_action, "-"))
	_summary.text = "Now: %s     Last round: %s  →  %s" % [str(rl.current_diff).capitalize().replace("_", " "), felt, did]
	for st in STATES:
		var best := ""
		var best_v := -INF
		if rl.q.has(st):
			for a in rl.ACTIONS:
				var val := float(rl.q[st].get(a, 0.0))
				if val > best_v:
					best_v = val
					best = a
		for a in rl.ACTIONS:
			var l: Label = _cells.get("%s/%s" % [st, a])
			if l == null:
				continue
			if rl.q.has(st):
				l.text = "%.2f" % float(rl.q[st].get(a, 0.0))
				l.add_theme_color_override("font_color", PixelUI.GOLD if a == best and best_v != 0.0 else PixelUI.CREAM)
			else:
				l.text = "--"
				l.add_theme_color_override("font_color", PixelUI.MUTED)
