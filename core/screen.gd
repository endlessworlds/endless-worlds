# Screen.gd (Autoload) — phone / tablet support, mostly for the web build on GitHub Pages.
#
# The game is designed for a 1280x720 canvas. On a phone that canvas is squeezed into
# ~390 CSS px, so everything looks far away and tiny ("zoomed out"), and in portrait
# the 16:9 layout only fills a thin strip. On mobile we therefore pick our own scale:
#
#   * a fixed number of physical pixels per logical pixel, worked out from the device's
#     short screen side (not the window), so the shorter screen side is 600–720 logical px;
#   * the logical viewport then simply follows the window in both orientations.
#
# Because the scale comes from the *screen*, it does not change when the phone keyboard
# opens or the browser bars slide in and out — the UI only re-flows, it never shrinks.
# Desktop keeps the engine's normal 1280x720 "expand" stretch.
extends Node

signal layout_changed   # the logical viewport size changed (rotation, resize, keyboard)

const SHORT_SIDE_MIN := 600.0   # logical px on the short side of a small phone
const SHORT_SIDE_MAX := 720.0   # the size the game was designed for
const CSS_TO_LOGICAL := 1.6     # logical px per CSS px before clamping

var is_web := OS.has_feature("web")
var is_mobile := false   # phone / tablet (browser or native)
var is_touch := false    # touch-first device: on-screen buttons, "tap" wording, auto-aim
var _ppl := 0.0          # physical px per logical px (0 = engine default)
var keyboard: GameKeyboard   # the game's own on-screen keyboard (touch devices only)

signal keyboard_changed(height: float)   # logical px covered by the on-screen keyboard
signal quality_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if is_web and not is_mobile and DisplayServer.is_touchscreen_available():
		# iPadOS Safari reports a desktop user agent; a touch laptop has a big screen
		# (and a mouse + keyboard, so it keeps the desktop controls).
		is_mobile = _css_short_side() < 900.0
	is_touch = is_mobile or "--touch" in OS.get_cmdline_user_args()   # dev: preview the touch UI
	if is_mobile:
		get_tree().root.size_changed.connect(_apply_scale)
		_apply_scale()
	_apply_quality.call_deferred()   # after Global has loaded the saved setting
	if is_touch or is_web:
		# The phone's own keyboard must never open: switch it off on every text box the
		# moment it is created (the game's keyboard types instead, see game_keyboard.gd).
		get_tree().node_added.connect(_no_system_keyboard)
	if is_touch:
		# Typing uses the game's keyboard, never the phone's (see game_keyboard.gd).
		keyboard = GameKeyboard.new()
		add_child(keyboard)
		keyboard.height_changed.connect(func(h): keyboard_changed.emit(h))


func _no_system_keyboard(n: Node) -> void:
	if n is LineEdit or n is TextEdit:
		n.virtual_keyboard_enabled = false


# ------------------------------------------------------------------ graphics quality
# "Low" (the automatic choice on phones and tablets) keeps the look but costs far less:
#   * the game is drawn at its own resolution and scaled up, instead of at the phone's
#     full pixel density (3x DPR = ~9x fewer pixels to shade),
#   * no full-screen post-processing pass, fewer particles, critters and lights.
func low() -> bool:
	var g := str(Global.graphics)
	return g == "low" or (g == "auto" and is_mobile)


func graphics_label() -> String:
	var g := str(Global.graphics)
	return "Graphics: %s" % ({"auto": "Auto (%s)" % ("Low" if is_mobile else "High"), "high": "High", "low": "Low"}[g])


func cycle_graphics() -> void:
	var order := ["auto", "high", "low"]
	Global.graphics = order[(order.find(Global.graphics) + 1) % order.size()]
	Global.save_game()
	_apply_quality()


func _apply_quality() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if low() else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	quality_changed.emit()


# Scale a particle / critter count for the current quality.
func fx_count(n: int, low_factor := 0.4) -> int:
	return maxi(1, int(n * low_factor)) if low() else n


func is_portrait() -> bool:
	var s := get_tree().root.get_visible_rect().size
	return s.y > s.x


func is_narrow() -> bool:   # not enough width for the desktop layout
	return get_tree().root.get_visible_rect().size.x < 960.0


# ------------------------------------------------------------------ scale
func _apply_scale() -> void:
	var win := get_tree().root
	var phys := Vector2(DisplayServer.window_get_size())
	if phys.x < 2.0 or phys.y < 2.0:
		return
	if _ppl <= 0.0:
		var css_short := _css_short_side()
		var dpr := _pixel_ratio()
		if css_short <= 0.0:   # no JS screen info: derive it from the window
			css_short = minf(phys.x, phys.y) / dpr
		var logical_short := clampf(css_short * CSS_TO_LOGICAL, SHORT_SIDE_MIN, SHORT_SIDE_MAX)
		_ppl = maxf(0.25, css_short * dpr / logical_short)
	var logical := Vector2i(maxi(1, roundi(phys.x / _ppl)), maxi(1, roundi(phys.y / _ppl)))
	if logical != win.content_scale_size:
		win.content_scale_size = logical
		layout_changed.emit()


func _css_short_side() -> float:
	if is_web:
		var v = JavaScriptBridge.eval("Math.min(window.screen.width || 0, window.screen.height || 0)", true)
		if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
			return float(v)
		return 0.0
	var s := Vector2(DisplayServer.screen_get_size())
	return minf(s.x, s.y) / maxf(1.0, DisplayServer.screen_get_scale())


func _pixel_ratio() -> float:
	if is_web:
		var v = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		if typeof(v) in [TYPE_FLOAT, TYPE_INT] and float(v) > 0.0:
			return float(v)
		return 1.0
	return maxf(1.0, DisplayServer.screen_get_scale())


# Logical px at the bottom of the screen covered by the on-screen keyboard (0 = closed).
func keyboard_cover() -> float:
	return keyboard.covered_height() if keyboard else 0.0


func keyboard_open() -> bool:
	return keyboard != null and keyboard.is_open()


# ------------------------------------------------------------------ fullscreen
func can_fullscreen() -> bool:
	if is_web:
		# iPhone Safari has no Fullscreen API for pages — "Add to Home Screen" instead.
		return JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true) == true
	return not OS.has_feature("mobile")


# The web page goes fullscreen as a whole (see ewFullscreen in the export's head include):
# that keeps the phone keyboard's hidden text field inside the fullscreen area.
func is_fullscreen() -> bool:
	if is_web:
		return JavaScriptBridge.eval("!!(document.fullscreenElement || document.webkitFullscreenElement)", true) == true
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# Must be called from a tap / click handler: browsers only allow fullscreen after a gesture.
# Leaving fullscreen with this button also stops the automatic fullscreen-on-tap.
func toggle_fullscreen() -> void:
	if is_web:
		if is_fullscreen():
			JavaScriptBridge.eval("window.ewAutoFullscreen = false; window.ewExitFullscreen && window.ewExitFullscreen();", true)
		else:
			JavaScriptBridge.eval("window.ewAutoFullscreen = window.ewIsPhone; window.ewFullscreen && window.ewFullscreen();", true)
		return
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ------------------------------------------------------------------ install as an app
func can_install() -> bool:
	return is_web and JavaScriptBridge.eval("!window.ewInstalled", true) == true


# Shows the browser's install prompt when it offers one; otherwise explains how to add
# the game to the home screen on this device.
func install_app(parent: Node) -> void:
	var r = JavaScriptBridge.eval("window.ewInstall ? window.ewInstall() : 'manual'", true)
	if str(r) == "prompted":
		return
	var how := "Tap the browser menu (⋮), then  Install app  or  Add to Home screen."
	if OS.has_feature("web_ios") or JavaScriptBridge.eval("/iPad|iPhone|Macintosh/.test(navigator.userAgent) && navigator.maxTouchPoints > 1", true) == true:
		how = "In Safari tap  Share  (the square with the arrow),\nthen  Add to Home Screen."
	elif not is_mobile:
		how = "Click the install icon at the right end of the address bar,\nor the browser menu  >  Install Endless Worlds."
	RoundCard.show_card(parent, "Install the game", how + "\n\nIt then opens fullscreen from its own icon, like an app.", [["OK", func(): pass]])


func fullscreen_label() -> String:
	return "Exit fullscreen" if is_fullscreen() else "Fullscreen"


# Text helpers so hints match the device ("Tap" vs "Press E").
func controls_hint() -> String:
	if is_touch:
		return "Move: joystick (push far to sprint)   Jump: ↑ button\nAnswer: walk into a well or terminal   Tap Bolt for voice, torch and chat"
	return "Move: WASD   Sprint: Shift   Jump: Space   Talk: V   Torch: F\nClick Bolt for more"
