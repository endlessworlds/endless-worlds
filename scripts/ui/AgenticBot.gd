extends CanvasLayer
class_name AgenticBot

# ============================================================
# AgenticBot – 6×5 spritesheet bot displayed at the bottom-right.
#
# Spritesheet layout (6 cols × 5 rows = 30 frames):
#   Row 0 (frames  0– 5) → idle      – neutral waiting loop
#   Row 1 (frames  6–11) → talking   – mouth / chest waveform loop
#   Row 2 (frames 12–17) → thinking  – hand-to-chin, one-shot
#   Row 3 (frames 18–23) → happy     – curved eyes / hover, one-shot
#   Row 4 (frames 24–29) → waving    – arm wave, one-shot
#
# Animation sequence triggered by speak():
#   waving → thinking → talking (+ typewriter) → happy → idle
# ============================================================

const COLS           := 6
const ROWS           := 5
const BOT_SCALE      := Vector2(1.2, 1.2)  # doubled from 0.6
const MARGIN         := Vector2(14, 14)    # padding from screen edges
const CLOCK_RESERVE  := 130.0             # pixels reserved for the clock at bottom-right
const BUBBLE_W       := 260.0
const BUBBLE_H       := 130.0
const BUBBLE_ALPHA   := 0.70              # speech bubble background opacity
const BUBBLE_BORDER  := 2                 # border width (px)
const BUBBLE_COLOR   := Color(1.0, 1.0, 1.0, 0.70)   # fill, matches BUBBLE_ALPHA
const BORDER_COLOR   := Color(0.35, 0.45, 0.9, 1.0)  # stroke color
const CHAR_DELAY     := 0.045              # seconds per character
const DONE_WAIT      := 5.0               # seconds bubble stays after happy anim
const FONT_PATH      := "res://Jersey10-Regular.ttf"
const JUMP_HEIGHT    := 30.0              # pixels the bot rises on a click-jump
const JUMP_DURATION  := 0.18             # seconds for each half of the jump arc

# Animation names match the spritesheet rows
const ANIM_IDLE     := "idle"
const ANIM_TALKING  := "talking"
const ANIM_THINKING := "thinking"
const ANIM_HAPPY    := "happy"
const ANIM_WAVING   := "waving"

enum _State { IDLE, GREETING, THINKING, SPEAKING, CELEBRATING, DONE }

# ---- nodes ----
var _bot: AnimatedSprite2D
var _bubble: Panel
var _label: Label

# ---- state ----
var _state: _State = _State.IDLE
var _full_text  := ""
var _chars_shown := 0
var _elapsed    := 0.0
var _done_timer := 0.0
var _frame_w    := 0.0
var _frame_h    := 0.0
var _jumping    := false   # true while a click-jump tween is running


# ==============================================================
func _ready() -> void:
	layer = 20   # above all game UI

	var bot_tex: Texture2D = load("res://assets/agentic_bot.png")
	_frame_w = bot_tex.get_width()  / float(COLS)
	_frame_h = bot_tex.get_height() / float(ROWS)

	_build_sprite(bot_tex, _frame_w, _frame_h)
	_build_bubble()

	await get_tree().process_frame
	_layout()


# ==============================================================
# Public API
# ==============================================================
func speak(text: String) -> void:
	# If already mid-sequence, reset cleanly
	_full_text    = text
	_chars_shown  = 0
	_elapsed      = 0.0
	_done_timer   = 0.0
	_state        = _State.GREETING

	_label.text        = ""
	_bubble.modulate.a = 0.0
	_bubble.visible    = true

	# Fade the bubble in while the bot waves
	var tw := create_tween()
	tw.tween_property(_bubble, "modulate:a", 1.0, 0.4)

	_bot.play(ANIM_WAVING)


# ==============================================================
func _process(delta: float) -> void:
	match _state:
		_State.SPEAKING:
			_elapsed += delta
			var target := int(_elapsed / CHAR_DELAY)
			target = min(target, _full_text.length())
			if target != _chars_shown:
				_chars_shown = target
				_label.text  = _full_text.substr(0, _chars_shown)
			if _chars_shown >= _full_text.length():
				_state = _State.CELEBRATING
				_bot.play(ANIM_HAPPY)

		_State.DONE:
			_done_timer += delta
			if _done_timer >= DONE_WAIT:
				_hide_bubble()


# ==============================================================
# Internals
# ==============================================================
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# Hit-test: is the click inside the bot sprite's bounding rect?
	var half_w := _frame_w * BOT_SCALE.x * 0.5
	var half_h := _frame_h * BOT_SCALE.y * 0.5
	var bot_rect := Rect2(_bot.position - Vector2(half_w, half_h), Vector2(half_w * 2.0, half_h * 2.0))
	if bot_rect.has_point(mb.position):
		_jump()


func _jump() -> void:
	if _jumping:
		return
	_jumping = true
	var origin_y := _bot.position.y
	var tw := create_tween()
	tw.tween_property(_bot, "position:y", origin_y - JUMP_HEIGHT, JUMP_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_bot, "position:y", origin_y, JUMP_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: _jumping = false)


func _hide_bubble() -> void:
	_state = _State.IDLE
	var tw := create_tween()
	tw.tween_property(_bubble, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _bubble.visible = false)


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var bw := _frame_w * BOT_SCALE.x
	var bh := _frame_h * BOT_SCALE.y

	# Bot sits to the left of the clock (bottom-right corner)
	_bot.position = Vector2(
		vp.x - MARGIN.x - CLOCK_RESERVE - bw * 0.5,
		vp.y - MARGIN.y - bh * 0.5
	)

	# Bubble sits above and to the left of the bot
	_bubble.size     = Vector2(BUBBLE_W, BUBBLE_H)
	_bubble.position = Vector2(
		_bot.position.x - BUBBLE_W + bw * 0.5,
		_bot.position.y - bh * 0.5 - BUBBLE_H - 8
	)


func _build_sprite(bot_tex: Texture2D, fw: float, fh: float) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# ── helper: add one row as a named animation ──────────────
	var add_anim := func(name: String, row: int, fps: float, loop: bool) -> void:
		frames.add_animation(name)
		frames.set_animation_speed(name, fps)
		frames.set_animation_loop(name, loop)
		for col in range(COLS):
			var at := AtlasTexture.new()
			at.atlas  = bot_tex
			at.region = Rect2(col * fw, row * fh, fw, fh)
			frames.add_frame(name, at)

	# Row 0 – idle:      neutral waiting loop
	add_anim.call(ANIM_IDLE,     0, 5.0, true)
	# Row 1 – talking:   mouth/waveform loop while typing
	add_anim.call(ANIM_TALKING,  1, 9.0, true)
	# Row 2 – thinking:  one-shot, used before speaking starts
	add_anim.call(ANIM_THINKING, 2, 7.0, false)
	# Row 3 – happy:     one-shot, played when typing is finished
	add_anim.call(ANIM_HAPPY,    3, 8.0, false)
	# Row 4 – waving:    one-shot, played as greeting on hint pickup
	add_anim.call(ANIM_WAVING,   4, 8.0, false)

	_bot = AnimatedSprite2D.new()
	_bot.sprite_frames = frames
	_bot.scale         = BOT_SCALE
	_bot.play(ANIM_IDLE)
	_bot.animation_finished.connect(_on_animation_finished)
	add_child(_bot)


func _build_bubble() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = BUBBLE_COLOR
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left  = 4
	style.border_width_left          = BUBBLE_BORDER
	style.border_width_top           = BUBBLE_BORDER
	style.border_width_right         = BUBBLE_BORDER
	style.border_width_bottom        = BUBBLE_BORDER
	style.border_color               = BORDER_COLOR

	_bubble = Panel.new()
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.visible    = false
	_bubble.modulate.a = 0.0
	add_child(_bubble)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left   = 10
	_label.offset_top    = 10
	_label.offset_right  = -10
	_label.offset_bottom = -10
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override("font", load(FONT_PATH))
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.35))
	_bubble.add_child(_label)


# ==============================================================
# Animation sequencing – drives the state machine forward
# ==============================================================
func _on_animation_finished() -> void:
	match _bot.animation:
		ANIM_WAVING:
			# Greeting done → now think before speaking
			_state = _State.THINKING
			_bot.play(ANIM_THINKING)

		ANIM_THINKING:
			# Thinking done → start typing and loop talking
			_state = _State.SPEAKING
			_elapsed = 0.0
			_bot.play(ANIM_TALKING)

		ANIM_HAPPY:
			# Celebration done → return to idle, start DONE countdown
			_state = _State.DONE
			_done_timer = 0.0
			_bot.play(ANIM_IDLE)

