extends Node2D
class_name Confetti

# Win celebration: two paper cannons fire from the bottom corners and a shower falls from the
# top. Each piece is a little card that flips (its width follows cos(spin)), so you see its
# darker back side half the time, flutters side to side and slows in the air. Gold sparkles
# twinkle over the middle and the screen flashes once. Frees itself after ~3.5 s.
#   Confetti.burst(self)

const COLORS := [Color("ffd23f"), Color("ff5d8f"), Color("3ec7ff"), Color("7ce35b"),
	Color("ff8a2b"), Color("b383ff"), Color("ffffff")]
const LIFE := 3.6

var _p: Array = []         # pieces: [pos, vel, color, size, rot, spin, flip, flip_speed, sway]
var _sparks: Array = []    # sparkles: [pos, delay, scale]
var _t := 0.0


static func burst(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120    # above popups and pages
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.get_tree().root.add_child(layer)
	var c := Confetti.new()
	layer.add_child(c)
	c._start()
	Sound.play("confetti")


func _start() -> void:
	var vp := get_viewport().get_visible_rect().size
	var n := 70 if Screen.low() else 130     # per cannon
	for side in [-1.0, 1.0]:
		var origin := Vector2(vp.x * 0.5 - side * vp.x * 0.5, vp.y + 10.0)
		for i in n:
			var ang := deg_to_rad(randf_range(48.0, 80.0))
			var speed := randf_range(0.8, 1.3) * vp.y * 2.5   # peaks from mid-screen to near the top
			_add(origin, Vector2(cos(ang) * side * speed, -sin(ang) * speed))
	for i in (40 if Screen.low() else 90):    # shower from the top
		_add(Vector2(randf() * vp.x, randf_range(-vp.y * 0.5, -10.0)), Vector2(randf_range(-60, 60), randf_range(40, 160)))
	for i in 14:
		_sparks.append([Vector2(vp.x * randf_range(0.2, 0.8), vp.y * randf_range(0.12, 0.55)), randf() * 1.2, randf_range(0.7, 1.4)])
	var flash := ColorRect.new()
	flash.color = Color(1, 0.95, 0.75, 0.28)
	flash.size = vp
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(flash)
	get_parent().move_child(flash, 0)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.35)


func _add(pos: Vector2, vel: Vector2) -> void:
	var w := randf_range(7.0, 11.0)
	var size := Vector2(w, w * randf_range(1.3, 1.9)) if randf() < 0.75 else Vector2(w, w)
	_p.append([pos, vel, COLORS.pick_random(), size, randf() * TAU, randf_range(-6.0, 6.0),
		randf() * TAU, randf_range(6.0, 13.0), randf_range(30.0, 70.0)])


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		get_parent().queue_free()
		return
	for p in _p:
		var v: Vector2 = p[1]
		v.y += 900.0 * delta
		v *= pow(0.12, delta)                   # air drag: fast pop, then a slow float
		v.y = minf(v.y, 240.0)                  # paper terminal velocity
		p[1] = v
		p[6] += p[7] * delta
		p[0] += v * delta + Vector2(sin(p[6] * 0.5) * p[8] * delta, 0.0)
		p[4] += p[5] * delta
	queue_redraw()


func _draw() -> void:
	var fade := clampf((LIFE - _t) / 0.8, 0.0, 1.0)
	for p in _p:
		var flip := cos(p[6])
		var col: Color = p[2] if flip > 0.0 else (p[2] as Color).darkened(0.35)
		col.a = fade
		var s: Vector2 = p[3]
		draw_set_transform(p[0], p[4], Vector2(maxf(absf(flip), 0.15), 1.0))
		draw_rect(Rect2(-s * 0.5, s), col)
	draw_set_transform(Vector2.ZERO)
	for s in _sparks:
		var k: float = _t - s[1]
		if k < 0.0 or k > 0.9:
			continue
		var r: float = sin(k / 0.9 * PI) * 9.0 * s[2]   # grow, then shrink
		var gold := Color(1, 0.92, 0.45, fade)
		var pos: Vector2 = s[0]
		draw_rect(Rect2(pos - Vector2(r, 1.5), Vector2(r * 2.0, 3.0)), gold)
		draw_rect(Rect2(pos - Vector2(1.5, r), Vector2(3.0, r * 2.0)), gold)
		draw_rect(Rect2(pos - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(1, 1, 1, fade))
