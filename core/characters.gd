class_name Characters

# Playable characters: recolours of the original hero (index 0), see assets/characters/.

const NAMES := ["Shadow", "Ember", "Frost", "Forest", "Royal", "Rose"]
const BASE_SHEET := "res://assets/player.png"
const BASE_FRONT := "res://assets/front-player.png"


static func front(idx: int) -> Texture2D:
	return load(BASE_FRONT if idx <= 0 else "res://assets/characters/front_%d.png" % idx)


# Swap the sprite's atlas textures for the chosen character (same frame layout).
static func apply(sprite: AnimatedSprite2D, idx: int) -> void:
	idx = clampi(idx, 0, NAMES.size() - 1)
	if sprite.get_meta("character", 0) == idx:
		return
	sprite.set_meta("character", idx)
	if not sprite.has_meta("base_frames"):
		sprite.set_meta("base_frames", sprite.sprite_frames)
	var base: SpriteFrames = sprite.get_meta("base_frames")
	if idx == 0:
		sprite.sprite_frames = base
		return
	var sheet: Texture2D = load("res://assets/characters/player_%d.png" % idx)
	var frames: SpriteFrames = base.duplicate()
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			var at := frames.get_frame_texture(anim, i) as AtlasTexture
			if at == null:
				continue
			var copy: AtlasTexture = at.duplicate()
			copy.atlas = front(idx) if at.atlas.resource_path == BASE_FRONT else sheet
			frames.set_frame(anim, i, copy, frames.get_frame_duration(anim, i))
	var anim_now := sprite.animation
	var frame_now := sprite.frame
	sprite.sprite_frames = frames
	sprite.animation = anim_now
	sprite.frame = frame_now
