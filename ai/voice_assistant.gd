extends Control
class_name VoiceAssistant

# Talk to Bolt (the AgenticBot):
#   • click Bolt -> pixel icon menu fans out: talk, hands-free, type, voice, torch, chat
#   • hold V     -> push-to-talk
#   • hands-free -> voice activity detection starts/stops recording by itself
# Audio is captured from the mic bus, downsampled to 16 kHz mono WAV, transcribed by
# Whisper (POST /api/transcribe), answered by the RAG endpoint (POST /api/rag, spoiler-free
# guide persona), then shown in Bolt's bubble and spoken with the OS / browser TTS.

signal heard(text: String)

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")
const TARGET_RATE := 16000
const PRE_ROLL_S := 0.35
const MAX_RECORD_S := 12.0
const END_SILENCE_S := 0.9
const MIN_SPEECH_S := 0.35

enum State { IDLE, LISTENING, TRANSCRIBING, THINKING }

var bot: AgenticBot
var state := State.IDLE
var hands_free := false
var level := 0.0                     # smoothed mic RMS for the UI ring

var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
var _step := 1.0
var _phase := 0.0
var _rec := PackedFloat32Array()
var _pre := PackedFloat32Array()
var _rec_time := 0.0
var _silence := 0.0
var _voice_on := 0.0
var _noise := 0.01
var _ptt := false
var _cooldown := 0.0                 # ignore the mic right after Bolt finishes talking

var _http_stt: HTTPRequest
var _http_ask: HTTPRequest
var _status: Label
var _ask: LineEdit
var _menu_open := false
var _items := {}                     # id -> Button
var _bot_center := Vector2.ZERO
var _bot_size := Vector2(80, 80)

const ICON_DIR := "res://assets/ui/pixel/"
# id, icon, short tooltip — fanned out around Bolt when he's clicked
const MENU := [
	["talk", "mic", "Talk (hold V)"],
	["handsfree", "handsfree", "Hands-free"],
	["type", "keyboard", "Type"],
	["voice", "speaker", "Voice"],
	["torch", "torch", "Torch (F)"],
	["chat", "chat", "Chat (T)"],
]


func setup(owner_bot: AgenticBot) -> void:
	bot = owner_bot
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_http_stt = HTTPRequest.new()
	_http_stt.timeout = 25.0
	_http_stt.request_completed.connect(_on_stt_done)
	add_child(_http_stt)
	_http_ask = HTTPRequest.new()
	_http_ask.timeout = 30.0
	_http_ask.request_completed.connect(_on_ask_done)
	add_child(_http_ask)
	Net.message.connect(_on_net)
	_build_ui()


# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	for spec in MENU:
		if spec[0] == "chat" and not Net.active:
			continue
		var b := _icon_button(spec[1], spec[2])
		b.pressed.connect(_on_menu.bind(spec[0]))
		b.visible = false
		add_child(b)
		_items[spec[0]] = b

	_status = Label.new()
	_status.add_theme_font_override("font", FONT)
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status.add_theme_constant_override("outline_size", 6)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	_ask = LineEdit.new()
	_ask.placeholder_text = "Ask Bolt…"
	_ask.max_length = 200
	_ask.add_theme_font_override("font", FONT)
	_ask.add_theme_font_size_override("font_size", 24)
	_ask.add_theme_stylebox_override("normal", _frame("hover", 16))
	_ask.add_theme_stylebox_override("focus", _frame("hover", 16))
	_ask.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	_ask.visible = false
	_ask.text_submitted.connect(func(t): _close_ask(); ask(t))
	add_child(_ask)
	_refresh_icons()


func _frame(name: String, pad: int = 0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(ICON_DIR + "frame_%s.png" % name)
	sb.set_texture_margin_all(12)
	if pad > 0:
		sb.content_margin_left = pad
		sb.content_margin_right = pad
	return sb


func _icon_button(icon: String, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(48, 48)
	b.size = Vector2(48, 48)
	b.pivot_offset = Vector2(24, 24)
	b.icon = load(ICON_DIR + "icon_%s.png" % icon)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 32)
	b.add_theme_stylebox_override("normal", _frame("normal"))
	b.add_theme_stylebox_override("hover", _frame("hover"))
	b.add_theme_stylebox_override("pressed", _frame("active"))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _set_active(id: String, on: bool) -> void:
	var b: Button = _items.get(id)
	if b:
		b.add_theme_stylebox_override("normal", _frame("active" if on else "normal"))


func _refresh_icons() -> void:
	_set_active("talk", state == State.LISTENING)
	_set_active("handsfree", hands_free)
	_set_active("voice", bot.speak_aloud)
	if _items.has("voice"):
		_items.voice.icon = load(ICON_DIR + ("icon_speaker.png" if bot.speak_aloud else "icon_mute.png"))
	if _items.has("torch"):
		_items.torch.tooltip_text = "Torch: " + ["Auto", "On", "Off"][Global.torch_mode] + " (F)"
		_set_active("torch", Global.torch_mode == 1)
		_items.torch.modulate.a = 0.45 if Global.torch_mode == 2 else 1.0


func toggle_menu() -> void:
	_menu_open = not _menu_open
	var ids: Array = _items.keys()
	# tray slides out to the left of Bolt, below his speech bubble
	for i in ids.size():
		var b: Button = _items[ids[i]]
		var target := Vector2(_bot_center.x - _bot_size.x * 0.5 - 62.0 - i * 54.0, _bot_center.y - 4.0) - b.size * 0.5
		var tw := b.create_tween().set_parallel()
		if _menu_open:
			b.visible = true
			b.position = _bot_center - b.size * 0.5
			b.scale = Vector2(0.2, 0.2)
			b.modulate.a = 0.0
			tw.tween_property(b, "position", target, 0.28).set_delay(i * 0.035).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "scale", Vector2.ONE, 0.28).set_delay(i * 0.035).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "modulate:a", 1.0, 0.15).set_delay(i * 0.035)
		else:
			tw.tween_property(b, "position", _bot_center - b.size * 0.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(b, "scale", Vector2(0.2, 0.2), 0.18)
			tw.tween_property(b, "modulate:a", 0.0, 0.18)
			tw.chain().tween_callback(func(): b.visible = false)
	_refresh_icons()


func _on_menu(id: String) -> void:
	var scene := get_tree().current_scene
	match id:
		"talk":
			_on_mic_pressed()
		"handsfree":
			hands_free = not hands_free and _ensure_mic()
			_set_status("Hands-free" if hands_free else "")
		"type":
			toggle_menu()
			open_ask()
		"voice":
			bot.speak_aloud = not bot.speak_aloud
			if not bot.speak_aloud:
				DisplayServer.tts_stop()
		"torch":
			if scene and scene.get("atmosphere"):
				scene.atmosphere.cycle_torch()
		"chat":
			toggle_menu()
			if scene and scene.get("mp"):
				scene.mp._open_chat()
	_refresh_icons()


func layout(bot_center: Vector2, bot_size: Vector2) -> void:
	_bot_center = bot_center
	_bot_size = bot_size
	_status.size = Vector2(200, 26)
	_status.position = bot_center + Vector2(-100, -bot_size.y * 0.5 - 30)
	_ask.size = Vector2(380, 48)
	_ask.position = bot_center + Vector2(-420, -bot_size.y * 0.5 - 70)


func open_ask() -> void:
	_ask.visible = true
	_ask.text = ""
	_ask.grab_focus()
	Global.input_locked = true


func _close_ask() -> void:
	_ask.visible = false
	_ask.release_focus()
	Global.input_locked = false


func _unhandled_key_input(event: InputEvent) -> void:
	if _ask.visible and event.is_action_pressed("ui_cancel"):
		_close_ask()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ mic
func _ensure_mic() -> bool:
	if _capture:
		return true
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		_set_status("No mic")
		return false
	var bus := AudioServer.get_bus_index("VoiceIn")
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "VoiceIn")
		AudioServer.set_bus_mute(bus, true)  # capture only, never play the mic back
		AudioServer.add_bus_effect(bus, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(bus, 0)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "VoiceIn"
	add_child(_mic)
	_mic.play()
	_step = AudioServer.get_mix_rate() / float(TARGET_RATE)
	return true


func _on_mic_pressed() -> void:
	if state == State.LISTENING:
		_finish_recording()
	elif state == State.IDLE and _ensure_mic():
		_start_recording()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo or Global.input_locked:
		return
	if event.keycode == KEY_V:
		if event.pressed and state == State.IDLE and _ensure_mic():
			_ptt = true
			_start_recording()
		elif not event.pressed and _ptt:
			_ptt = false
			_finish_recording()


func _start_recording() -> void:
	DisplayServer.tts_stop()
	state = State.LISTENING
	_rec = _pre.duplicate()
	_rec_time = 0.0
	_silence = 0.0
	_set_status("Listening")
	_refresh_icons()


func _finish_recording() -> void:
	if state != State.LISTENING:
		return
	if _rec.size() < int(TARGET_RATE * MIN_SPEECH_S):
		state = State.IDLE
		_set_status("Again?" if not hands_free else "Hands-free")
		_refresh_icons()
		return
	state = State.TRANSCRIBING
	_set_status("Hearing")
	_refresh_icons()
	var wav := encode_wav(_rec, TARGET_RATE)
	_rec = PackedFloat32Array()
	if _via_host():
		_ask_host("/api/transcribe", "audio/wav", wav)
		return
	var err := _http_stt.request_raw(Global.api_url("/api/transcribe"),
		PackedStringArray(["Content-Type: audio/wav"]), HTTPClient.METHOD_POST, wav)
	if err != OK:
		_offline_reply()


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if DisplayServer.tts_is_speaking():
		_cooldown = 0.6
	if _capture == null:
		return
	var frames := _capture.get_buffer(_capture.get_frames_available())
	if frames.is_empty():
		return
	var sum := 0.0
	var chunk := PackedFloat32Array()
	for f in frames:
		var m := (f.x + f.y) * 0.5
		sum += m * m
		_phase += 1.0
		if _phase >= _step:
			_phase -= _step
			chunk.append(m)
	var rms := sqrt(sum / frames.size())
	level = lerpf(level, rms, 0.4)
	var threshold := maxf(0.02, _noise * 3.0)
	var loud := rms > threshold

	match state:
		State.IDLE:
			_noise = lerpf(_noise, rms, 0.02) if not loud else _noise
			_pre.append_array(chunk)
			var keep := int(TARGET_RATE * PRE_ROLL_S)
			if _pre.size() > keep:
				_pre = _pre.slice(_pre.size() - keep)
			if hands_free and _cooldown <= 0.0 and not _blocked():
				_voice_on = _voice_on + delta if loud else 0.0
				if _voice_on > 0.12:
					_voice_on = 0.0
					_start_recording()
		State.LISTENING:
			_rec.append_array(chunk)
			_rec_time += delta
			_silence = 0.0 if loud else _silence + delta
			var auto_stop := not _ptt and _silence > END_SILENCE_S and _rec_time > MIN_SPEECH_S
			if auto_stop or _rec_time > MAX_RECORD_S:
				_finish_recording()
	bot.set_listen_level(level if state == State.LISTENING else 0.0)


var _popup: Node

func _blocked() -> bool:
	if _popup == null or not is_instance_valid(_popup):
		_popup = get_tree().root.find_child("AnswerPopup", true, false)  # looked up once per scene
	return Global.input_locked or (_popup != null and _popup.visible)


# ------------------------------------------------------------------ brain
func ask(question: String) -> void:
	question = question.strip_edges()
	if question.is_empty():
		return
	heard.emit(question)
	state = State.THINKING
	_set_status("Thinking")
	bot.show_user_text(question)
	var scene := get_tree().current_scene
	var riddle := str(scene.get("current_question")) if scene and scene.get("current_question") != null else ""
	var body := {"prompt": question, "topic": Global.selected_topic}
	if not riddle.is_empty():
		body["riddle"] = riddle
	if _via_host():
		_ask_host("/api/rag", "application/json", JSON.stringify(body).to_utf8_buffer())
		return
	var err := _http_ask.request(Global.api_url("/api/rag"), PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_offline_reply()


# ------------------------------------------------------------------ online rooms
# Only the host runs the Python AI server. Guests send their audio / questions to the
# host through the relay; the host forwards them to its local API and sends the reply back.
const PROXY_PATHS := ["/api/transcribe", "/api/rag"]
var _pending := ""
var _req := 0


func _via_host() -> bool:
	return Net.active and not Net.is_host()


func _ask_host(path: String, content_type: String, raw: PackedByteArray) -> void:
	_pending = path
	_req += 1
	var mine := _req
	Net.send({"t": "api", "path": path, "ct": content_type, "b64": Marshalls.raw_to_base64(raw)}, 1)
	await get_tree().create_timer(30.0).timeout
	if _pending == path and _req == mine:  # host never answered this request
		_pending = ""
		_offline_reply()


func _on_net(from: int, d: Dictionary) -> void:
	match str(d.get("t", "")):
		"api":
			if Net.is_host() and str(d.get("path", "")) in PROXY_PATHS:
				_proxy_for(from, str(d.path), str(d.get("ct", "application/json")), Marshalls.base64_to_raw(str(d.get("b64", ""))))
		"api_reply":
			var path := str(d.get("path", ""))
			if path != _pending:
				return
			_pending = ""
			var body := str(d.get("body", "")).to_utf8_buffer()
			var ok := HTTPRequest.RESULT_SUCCESS if int(d.get("code", 0)) != 0 else HTTPRequest.RESULT_CANT_CONNECT
			if path == "/api/transcribe":
				_on_stt_done(ok, int(d.code), [], body)
			else:
				_on_ask_done(ok, int(d.code), [], body)


func _proxy_for(peer: int, path: String, content_type: String, raw: PackedByteArray) -> void:
	var http := HTTPRequest.new()
	http.timeout = 25.0
	add_child(http)
	http.request_completed.connect(func(result, code, _h, body: PackedByteArray):
		Net.send({"t": "api_reply", "path": path, "code": code if result == HTTPRequest.RESULT_SUCCESS else 0,
			"body": body.get_string_from_utf8()}, peer)
		http.queue_free())
	if http.request_raw(Global.api_url(path), PackedStringArray(["Content-Type: " + content_type]), HTTPClient.METHOD_POST, raw) != OK:
		Net.send({"t": "api_reply", "path": path, "code": 0, "body": ""}, peer)
		http.queue_free()


func _on_stt_done(result: int, code: int, _h, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_offline_reply()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var text := str(data.get("text", "")) if typeof(data) == TYPE_DICTIONARY else ""
	if text.strip_edges().length() < 2:
		state = State.IDLE
		_set_status("Again?")
		return
	ask(text)


func _on_ask_done(result: int, code: int, _h, body: PackedByteArray) -> void:
	state = State.IDLE
	_set_status("Hands-free" if hands_free else "")
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_offline_reply()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var reply := str(data.get("reply", "")) if typeof(data) == TYPE_DICTIONARY else ""
	bot.speak(reply.strip_edges() if not reply.is_empty() else "Hmm, I'm not sure. Try a hint bulb!")


func _offline_reply() -> void:
	state = State.IDLE
	_set_status("")
	bot.speak("I can't reach my AI brain right now. Grab the glowing hint bulbs and check the riddle with the magnifier!")


func _set_status(t: String) -> void:
	if _status:
		_status.text = t


# 16-bit PCM mono WAV — what Whisper expects.
static func encode_wav(samples: PackedFloat32Array, rate: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)    # "RIFF"
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)    # "WAVE"
	h.encode_u32(12, 0x20746d66)   # "fmt "
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)            # PCM
	h.encode_u16(22, 1)            # mono
	h.encode_u32(24, rate)
	h.encode_u32(28, rate * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)   # "data"
	h.encode_u32(40, data.size())
	return h + data


# Dev/testing: push a 16 kHz mono WAV through the exact mic -> STT -> answer path.
func sim_voice_file(path: String) -> void:
	var src := FileAccess.get_file_as_bytes(path)
	_rec = PackedFloat32Array()
	for i in range(44, src.size() - 1, 2):
		_rec.append(src.decode_s16(i) / 32768.0)
	state = State.LISTENING
	_finish_recording()
