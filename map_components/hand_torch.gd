extends Node2D
class_name HandTorch

# A torch held in the character's hand: switches hands with facing direction,
# goes behind the body when walking away from the camera, animated flame,
# rising embers and a flickering warm PointLight2D at the flame tip.

const TEX := preload("res://assets/wildlife/torch.png")
const LIGHT_TEX := preload("res://assets/wildlife/light_soft.png")

# Torch node position (player-local px) and draw order per facing, measured from the
# player sprite: (hand pixel - 72) * 0.25 sprite scale, -10 sprite offset, -2 so the
# handle's bottom sits in the fist. Side views hold it close to the body.
const HANDS := {
	"walk_down": [Vector2(-9, -3), 1],
	"walk_up": [Vector2(9, -4), -1],
	"walk_right": [Vector2(-2, 2), 1],
	"walk_left": [Vector2(3.5, 2), 1],
}
const MERGE_DIST := 70.0          # torches closer than this share one light

var follow: AnimatedSprite2D      # the character's sprite (player or remote puppet)
var lit := false
var max_energy := 0.85         # lowered on bright snow so overlapping torches never blow out
var _spr: Sprite2D
var _light: PointLight2D
var _embers: CPUParticles2D
var _halo: Sprite2D
var _t := 0.0
var _level := 0.0                 # 0..1 fade


func _init(sprite_to_follow: AnimatedSprite2D = null) -> void:
	follow = sprite_to_follow


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = TEX
	_spr.hframes = 3
	_spr.scale = Vector2(0.95, 0.95)
	_spr.offset = Vector2(0, -6)          # handle bottom sits in the hand
	var emissive := CanvasItemMaterial.new()
	emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # fire isn't darkened by night
	_spr.material = emissive
	add_child(_spr)

	_halo = Sprite2D.new()
	_halo.texture = LIGHT_TEX
	_halo.scale = Vector2(0.09, 0.09)
	_halo.position = Vector2(0, -13)
	_halo.modulate = Color(1.0, 0.6, 0.2, 0.55)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_halo.material = add
	add_child(_halo)

	_embers = CPUParticles2D.new()
	_embers.position = Vector2(0, -15)
	_embers.material = _spr.material
	_embers.amount = Screen.fx_count(10, 0.5)
	_embers.lifetime = 0.9
	_embers.local_coords = false          # sparks trail behind when walking
	_embers.direction = Vector2(0, -1)
	_embers.spread = 25.0
	_embers.gravity = Vector2(0, -20)
	_embers.initial_velocity_min = 6.0
	_embers.initial_velocity_max = 16.0
	_embers.scale_amount_min = 0.6
	_embers.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	ramp.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	_embers.color_ramp = ramp
	_embers.emitting = false
	add_child(_embers)

	_light = PointLight2D.new()
	_light.texture = LIGHT_TEX
	_light.texture_scale = 1.15
	_light.color = Color(1.0, 0.68, 0.36)
	_light.position = Vector2(0, -15)
	_light.energy = 0.0
	# Sprites are depth-sorted with z = y/4 (up to ~2200); the default light z range
	# (-1024..1024) skipped most trees, flowers, animals, wells and bulbs.
	_light.range_z_min = -4096
	_light.range_z_max = 4096
	add_child(_light)
	visible = false
	add_to_group("hand_torches")


func set_lit(on: bool) -> void:
	lit = on


func _process(delta: float) -> void:
	_level = move_toward(_level, 1.0 if lit else 0.0, delta * 2.5)
	visible = _level > 0.01
	_embers.emitting = lit
	if not visible:
		return
	_t += delta
	var hand: Array = HANDS.get(str(follow.animation) if follow else "walk_down", HANDS["walk_down"])
	var bob := sin(_t * 9.0) * 0.6 if follow and follow.is_playing() else 0.0
	# ride along with the body: jump height and water sink move the sprite, not the player
	var body_y: float = follow.position.y + 10.0 if follow else 0.0
	position = hand[0] + Vector2(0, bob + body_y)
	z_index = hand[1]
	_spr.frame = int(_t * 10.0) % 3
	_spr.modulate.a = _level
	# layered noise flicker so it never looks like a pulsing circle
	var flick := 0.88 + sin(_t * 13.0) * 0.06 + sin(_t * 31.0 + 1.3) * 0.04 + randf() * 0.04
	# Overlapping additive lights blow out to a glowing blob, so in a cluster of torches
	# only one (the oldest node) keeps its light; the others still show their flame.
	var target := max_energy * flick * _level
	for t in get_tree().get_nodes_in_group("hand_torches"):
		if t != self and t.lit and t.get_instance_id() < get_instance_id() \
				and t.global_position.distance_to(global_position) < MERGE_DIST * 2.0:  # *2: map scale
			target = 0.0
			break
	_light.energy = lerpf(_light.energy, target, 0.2)
	_light.texture_scale = 1.15 + sin(_t * 7.0) * 0.03
	_halo.scale = Vector2.ONE * (0.085 + flick * 0.012) * _level
