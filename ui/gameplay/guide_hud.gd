extends Control
class_name GuideHud

# Objective pill under the riddle magnifier + faint compass arrows far around the player
# pointing to the nearest hint bulb (gold) and the nearest well (cyan).

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")
const HINT_COL := Color(1.0, 0.85, 0.3)
const WELL_COL := Color(0.4, 0.85, 1.0)
const RING := 280.0           # far from the player so they stay out of the way
const ARROW_ALPHA := 0.32

var player: Node2D
var tasks: Tasks
var riddle_ui: RiddleUI
var _objective: Label
var _pill: PanelContainer


func setup(local_player: Node2D, task_node: Tasks, riddle: RiddleUI = null) -> void:
	player = local_player
	tasks = task_node
	riddle_ui = riddle
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pill := PanelContainer.new()
	_pill = pill
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.6)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel", sb)
	pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.offset_top = 92   # below the riddle magnifier
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pill)
	_objective = Label.new()
	_objective.add_theme_font_override("font", FONT)
	_objective.add_theme_font_size_override("font_size", 24)
	pill.add_child(_objective)


func _process(delta: float) -> void:
	if player == null:
		return
	# the riddle text opens right where the pill sits: step aside while it's shown
	var target_a := 0.0 if riddle_ui and riddle_ui.riddle_visible else 1.0
	_pill.modulate.a = move_toward(_pill.modulate.a, target_a, delta * 6.0)
	var got := tasks.collected_hints if tasks else 0
	var total := tasks.total_hints if tasks else 0
	if Global.is_coding_mode:
		_objective.text = "💻 Coding quest   ·   🪣 Open any well to start"
	elif total == 0:
		_objective.text = "⏳ Preparing your riddle…"
	elif got < total:
		_objective.text = "💡 Hints %d/%d   ·   🔍 Read the riddle   ·   🪣 Answer at any well" % [got, total]
	else:
		_objective.text = "✅ All hints found!  Head to a 🪣 well to answer"
	queue_redraw()


func _nearest(group: String) -> Node2D:
	var best: Node2D = null
	var bd := INF
	for n in get_tree().get_nodes_in_group(group):
		if n is Node2D and not n.is_queued_for_deletion():
			var d: float = n.global_position.distance_squared_to(player.global_position)
			if d < bd:
				bd = d
				best = n
	return best


func _draw() -> void:
	if player == null:
		return
	var center := player.get_global_transform_with_canvas().origin
	_arrow(center, _nearest("hints"), HINT_COL)
	_arrow(center, _nearest("wells"), WELL_COL)


func _arrow(center: Vector2, target: Node2D, col: Color) -> void:
	if target == null:
		return
	var tp := target.get_global_transform_with_canvas().origin
	var to := tp - center
	var dist := to.length()
	if get_viewport_rect().grow(-40).has_point(tp):
		return  # already on screen: the glow is enough
	var dir := to / dist
	var tip := center + dir * RING
	var side := dir.orthogonal() * 7.0
	var a := ARROW_ALPHA + sin(Time.get_ticks_msec() * 0.004) * 0.06
	draw_colored_polygon(PackedVector2Array([tip + dir * 12.0, tip + side, tip - dir * 2.0, tip - side]), Color(col, a))
