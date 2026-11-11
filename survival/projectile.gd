extends Node2D
class_name SurvivalShot

# One projectile: the player's weapon shots (hostile = false) or a mob/boss shot.
# Movement and hits are resolved by SurvivalGame each frame.

var vel := Vector2.ZERO
var r := 3.0
var dmg := 1.0
var hostile := true
var color := Color(1, 0.4, 0.3)
var life := 4.0
var pierce := 0
var homing := 0.0          # turn rate toward the player (rad/s), hostile only
var slows := false         # web: slows the player instead of extra damage
var hit_ids: Array = []    # mobs already hit (for piercing shots)
var kind := "bolt"         # player shots: bolt | pellet | fire | spear | moon
var boom := 0.0            # fireballs: explosion radius
var returning := false     # boomerang on its way back
var t := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if hostile:
		draw_circle(Vector2.ZERO, r + 1.0, Color(0.1, 0.05, 0.1, 0.9))
		draw_circle(Vector2.ZERO, r, color)
		draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.4, color.lightened(0.5))
		if slows:
			draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 12, Color(0.95, 0.95, 1.0, 0.7), 1.0)
		return
	var d := vel.normalized()
	match kind:
		"pellet":
			draw_circle(Vector2.ZERO, r * 0.8, color)
			draw_line(Vector2.ZERO, -d * r * 2.5, Color(color, 0.5), r * 0.8)
		"fire":
			var flick := 1.0 + sin(t * 30.0) * 0.12
			draw_circle(-d * r * 1.6, r * 0.9, Color(1.0, 0.35, 0.05, 0.45))
			draw_circle(Vector2.ZERO, r * 1.6 * flick, Color(1.0, 0.45, 0.1))
			draw_circle(Vector2.ZERO, r * 0.9, Color(1.0, 0.9, 0.45))
		"spear":
			var tip := d * r * 3.2
			draw_line(-d * r * 3.0, tip * 0.4, Color(0.75, 0.6, 0.35), 1.5)
			draw_colored_polygon(PackedVector2Array([tip, tip * 0.4 + d.orthogonal() * r * 0.9,
				tip * 0.4 - d.orthogonal() * r * 0.9]), color)
			draw_line(-d * r * 6.0, -d * r * 3.0, Color(color, 0.35), 1.0)
		"moon":
			var a := t * 18.0
			draw_arc(Vector2.ZERO, r * 1.8, a, a + PI * 1.2, 10, color, r * 0.9)
			draw_arc(Vector2.ZERO, r * 1.8, a, a + PI * 1.2, 10, Color(1, 1, 1, 0.7), r * 0.35)
		_:
			# a little diamond-shaped arcane bolt pointing where it flies
			var dd := d * r * 1.8
			var s := dd.orthogonal() * 0.45
			draw_colored_polygon(PackedVector2Array([dd, s, -dd * 0.7, -s]), color)
			draw_colored_polygon(PackedVector2Array([dd * 0.6, s * 0.5, -dd * 0.3, -s * 0.5]), Color(0.92, 1.0, 1.0))
