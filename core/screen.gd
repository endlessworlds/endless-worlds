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


# Logical px at the bottom of the game hidden by the phone keyboard. Android resizes the
# page (see interactive-widget in the export's head include); iOS Safari doesn't, it just
# draws the keyboard over the canvas — visualViewport tells us how much.
func keyboard_cover() -> float:
	if not (is_web and is_mobile) or _ppl <= 0.0:
		return 0.0
	var v = JavaScriptBridge.eval("window.visualViewport ? Math.max(0, window.innerHeight - window.visualViewport.height - window.visualViewport.offsetTop) : 0", true)
	if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
		return float(v) * _pixel_ratio() / _ppl
	return 0.0


# ------------------------------------------------------------------ fullscreen
func can_fullscreen() -> bool:
	if is_web:
		# iPhone Safari has no Fullscreen API for pages — "Add to Home Screen" instead.
		return JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true) == true
	return not OS.has_feature("mobile")


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# Must be called from a tap / click handler: browsers only allow fullscreen after a gesture.
func toggle_fullscreen() -> void:
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func fullscreen_label() -> String:
	return "Exit fullscreen" if is_fullscreen() else "Fullscreen"


# Text helpers so hints match the device ("Tap" vs "Press E").
func controls_hint() -> String:
	if is_touch:
		return "Move: joystick (push far to sprint)   Jump: JUMP\nAnswer: walk into a well or terminal   Tap Bolt for voice, torch and chat"
	return "Move: WASD   Sprint: Shift   Jump: Space   Talk: V   Torch: F\nClick Bolt for more"
