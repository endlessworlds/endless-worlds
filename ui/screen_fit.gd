extends Node
class_name ScreenFit

# Keeps a popup on screen: whenever `content` is larger than the viewport (small phone,
# portrait, keyboard open), `target` is scaled down around its centre so all of it shows.
#
#   ScreenFit.attach(center_container, panel)   # scale the CenterContainer that holds the panel
#   ScreenFit.attach(vbox)                      # scale a control by its own size
#
# The helper is a child node of `target`, so it disappears with it (no dangling signals).

var target: Control
var content: Control
var margin := 12.0


static func attach(p_target: Control, p_content: Control = null, p_margin := 12.0) -> ScreenFit:
	var f := ScreenFit.new()
	f.name = "ScreenFit"
	f.target = p_target
	f.content = p_content if p_content else p_target
	f.margin = p_margin
	p_target.add_child(f)
	return f


func _ready() -> void:
	content.resized.connect(refit)
	if target != content:
		target.resized.connect(refit)
	get_viewport().size_changed.connect(refit)
	Screen.keyboard_changed.connect(_on_keyboard)
	refit.call_deferred()


func refit() -> void:
	if not is_instance_valid(target) or not is_instance_valid(content):
		return
	var vp := target.get_viewport_rect().size
	# A full-screen CenterContainer moves its content up above the on-screen keyboard.
	var kb := Screen.keyboard_cover()
	if target is CenterContainer:
		target.offset_bottom = -kb
		vp.y -= kb
	var need := content.size.max(content.get_combined_minimum_size())
	if need.x < 1.0 or need.y < 1.0:
		return
	var s := minf(1.0, minf((vp.x - margin * 2.0) / need.x, (vp.y - margin * 2.0) / need.y))
	s = maxf(s, 0.3)
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2(s, s)


func _on_keyboard(_h: float) -> void:
	refit()
