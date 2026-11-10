extends Node2D
class_name SurvivalShot

# One projectile: the player's bolts (hostile = false) or a mob/boss shot.
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
var hit_ids: Array = []    # mobs already hit (for piercing bolts)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if hostile:
		draw_circle(Vector2.ZERO, r + 1.0, Color(0.1, 0.05, 0.1, 0.9))
		draw_circle(Vector2.ZERO, r, color)
		draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.4, color.lightened(0.5))
		if slows:
			draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 12, Color(0.95, 0.95, 1.0, 0.7), 1.0)
	else:
		# a little diamond-shaped arcane bolt pointing where it flies
		var d := vel.normalized() * r * 1.8
		var s := d.orthogonal() * 0.45
		draw_colored_polygon(PackedVector2Array([d, s, -d * 0.7, -s]), Color(0.45, 0.95, 1.0))
		draw_colored_polygon(PackedVector2Array([d * 0.6, s * 0.5, -d * 0.3, -s * 0.5]), Color(0.92, 1.0, 1.0))
