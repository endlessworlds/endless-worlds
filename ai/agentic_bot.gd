extends CanvasLayer
class_name AgenticBot

# ============================================================
# AgenticBot – 6×5 spritesheet bot displayed at the bottom-right.
# Art: assets/agentic_bot.png, made by tools/make_bot.py (48 px pixel art saved at x2).
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
const BOT_SCALE      := Vector2(1.0, 1.0)  # 96 px frames, drawn 1:1 so the pixels stay crisp
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
const FONT_PATH      := "res://assets/fonts/Jersey10-Regular.ttf"
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
var _voice: VoiceAssistant
var _ring: _ListenRing
var _base_y     := 0.0
var _t          := 0.0
var speak_aloud := true     # text-to-speech for hints and answers
var _tts_voice  := ""
# Voice/text sync: speech starts when typing starts; word-boundary events from the
# TTS engine move the text along with the voice. Engines without boundary events
# fall back to a speaking-pace timer.
const TTS_CHAR_DELAY := 0.062   # ≈ speaking pace at rate 1.05
var _utt_id := 0
var _tts_on := false
var _tts_word_end := -1          # chars confirmed spoken so far (-1 = no boundary seen yet)


# ==============================================================
func _ready() -> void:
	layer = 20   # above all game UI

	var bot_tex: Texture2D = load("res://assets/agentic_bot.png")
	_frame_w = bot_tex.get_width()  / float(COLS)
	_frame_h = bot_tex.get_height() / float(ROWS)

	_ring = _ListenRing.new()
	add_child(_ring)
	_build_sprite(bot_tex, _frame_w, _frame_h)
	_build_bubble()
	_voice = VoiceAssistant.new()
	add_child(_voice)
	_voice.setup(self)
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if not voices.is_empty():
		_tts_voice = voices[0]
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_BOUNDARY, _on_tts_boundary)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_ended)

	await get_tree().process_frame
	_layout()
	get_viewport().size_changed.connect(_layout)


# ==============================================================
# Public API
# ==============================================================
func speak(text: String) -> void:
	DisplayServer.tts_stop()
	_tts_on = false
	_fit_bubble(text)
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
# Show what the player said (from speech-to-text or typing) while Bolt thinks.
func show_user_text(text: String) -> void:
	_fit_bubble("You: " + text)
	_state = _State.IDLE
	_label.text = "You: \"%s\"" % text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_bot.play(ANIM_THINKING)


func set_listen_level(v: float) -> void:
	_ring.level = v
	_ring.active = v > 0.0


func _fit_bubble(text: String) -> void:
	var lines := ceili(text.length() / 30.0) + 1
	_bubble.size = Vector2(BUBBLE_W + 60, maxf(BUBBLE_H * 0.6, lines * 22.0 + 24.0))
	_bubble.position.y = _bubble_bottom() - _bubble.size.y


# Bubble grows upward from a fixed bottom edge that sits above both Bolt and his
# icon tray (tray spans base_y-28 .. base_y+20), so replies never cover the buttons.
func _bubble_bottom() -> float:
	return _base_y - maxf(_frame_h * BOT_SCALE.y * 0.5 + 8.0, 40.0)


func _process(delta: float) -> void:
	# gentle hover so Bolt feels alive
	_t += delta
	if not _jumping and _base_y != 0.0:
		_bot.position.y = _base_y + sin(_t * 2.2) * 3.0
	_ring.position = _bot.position
	match _state:
		_State.SPEAKING:
			_elapsed += delta
			var target := int(_elapsed / (TTS_CHAR_DELAY if _tts_on else CHAR_DELAY))
			if _tts_on and _tts_word_end >= 0:
				target = maxi(_chars_shown, _tts_word_end)   # follow the voice, never go backwards
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
		_voice.toggle_menu()


func _jump() -> void:
	if _jumping:
		return
	_jumping = true
	var origin_y := _base_y
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

	_base_y = _bot.position.y
	# Bubble sits above and to the left of the bot
	_bubble.size     = Vector2(BUBBLE_W + 60, BUBBLE_H)
	_bubble.position = Vector2(
		_bot.position.x - BUBBLE_W - 60 + bw * 0.5,
		0.0
	)
	_bubble.position.y = _bubble_bottom() - BUBBLE_H
	_ring.radius = maxf(bw, bh) * 0.55
	_voice.layout(_bot.position, Vector2(bw, bh))


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
	# same pixel frame as Bolt's icon tray so the HUD reads as one set
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/pixel/frame_normal.png")
	style.set_texture_margin_all(12)

	_bubble = Panel.new()
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.visible    = false
	_bubble.modulate.a = 0.0
	add_child(_bubble)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left   = 16
	_label.offset_top    = 12
	_label.offset_right  = -16
	_label.offset_bottom = -12
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override("font", load(FONT_PATH))
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
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
			# Thinking done → voice and typing start together
			_state = _State.SPEAKING
			_elapsed = 0.0
			_start_voice()
			_bot.play(ANIM_TALKING)

		ANIM_HAPPY:
			# Celebration done → return to idle, start DONE countdown
			_state = _State.DONE
			_done_timer = 0.0
			_bot.play(ANIM_IDLE)



func _start_voice() -> void:
	_tts_word_end = -1
	_tts_on = speak_aloud and not _tts_voice.is_empty()
	if _tts_on:
		_utt_id += 1
		DisplayServer.tts_speak(_full_text, _tts_voice, Global.voice_tts_volume(), 1.1, 1.05, _utt_id, true)


func _on_tts_boundary(pos: int, id: int) -> void:
	if id != _utt_id or _state != _State.SPEAKING:
		return
	# reveal through the end of the word being spoken
	var end := _full_text.find(" ", pos + 1)
	_tts_word_end = maxi(_tts_word_end, end if end != -1 else _full_text.length())


func _on_tts_ended(id: int) -> void:
	if id == _utt_id:
		_tts_word_end = _full_text.length()


# Pulsing ring around Bolt that follows the microphone level while listening.
class _ListenRing extends Node2D:
	var level := 0.0
	var active := false
	var radius := 60.0
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		if not active:
			return
		var pulse := 1.0 + minf(level * 12.0, 0.5) + sin(_t * 8.0) * 0.03
		draw_circle(Vector2.ZERO, radius * pulse, Color(1.0, 0.25, 0.35, 0.12))
		draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 48, Color(1.0, 0.35, 0.45, 0.9), 3.0, true)
		draw_arc(Vector2.ZERO, radius * (pulse + 0.15), 0.0, TAU, 48, Color(1.0, 0.35, 0.45, 0.35), 2.0, true)
