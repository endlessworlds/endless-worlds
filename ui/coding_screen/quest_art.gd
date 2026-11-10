extends Control
class_name QuestArt

# Animated pixel-art illustration for a coding quest, built from the question itself:
#   craft_*  -> ingredient slots  "coal x3 + stick x3 = torch"
#   brew_*   -> "water x99 + magic x83 = potion" with bubbles
#   mine_*   -> pickaxe swinging at an ore block, gems popping out
#   detect_* -> distance ruler with the player, a wandering mob and the danger zone
# Sprites come from assets/quest (tools/make_quest_art.py) and assets/survival.

const FONT := preload("res://assets/fonts/Jersey10-Regular.ttf")
const ITEM_DIR := "res://assets/quest/%s.png"

# param / item word -> sprite name in assets/quest
const ITEM_ALIASES := {
	"sticks": "stick", "diamonds": "diamond", "planks": "plank", "ores": "ore",
}
const MOBS := {
	"creeper": "bomber", "zombie": "zombie", "skeleton": "skeleton",
	"spider": "spider", "enderman": "ghost",
}

var kind := "generic"           # craft | brew | mine | detect | generic
var dark := true
var _t := 0.0
var _a := {}                    # parsed parts of the question
var _tex := {}                  # name -> Texture2D


func setup(q: Dictionary, is_dark: bool) -> void:
	dark = is_dark
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(0, 196)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parse(q)
	queue_redraw()


# Sprite for the header tile (result item / mob), or null.
func hero_texture() -> Texture2D:
	match kind:
		"craft", "brew": return _tex.get("result")
		"mine": return _tex.get("gem")
		"detect": return _mob_frame_tex()
	return null


static func category_of(q: Dictionary) -> String:
	var fn := str(q.get("funcName", ""))
	for p in ["craft", "brew", "mine", "detect"]:
		if fn.begins_with(p + "_"):
			return p
	return "generic"


func _parse(q: Dictionary) -> void:
	kind = category_of(q)
	var fn := str(q.get("funcName", ""))
	var desc := str(q.get("desc", ""))
	var nums: Array[int] = []
	var re := RegEx.create_from_string("\\d+")
	for m in re.search_all(desc):
		nums.append(int(m.get_string()))
	var params := _params(str(q.get("startingCode", "")))
	_a = {"icon": str(q.get("icon", "💻"))}

	match kind:
		"craft", "brew":
			if params.size() < 2 or nums.size() < 2:
				kind = "generic"
				return
			var result := "potion" if kind == "brew" else fn.trim_prefix("craft_")
			_a.names = [params[0], params[1], result]
			_a.counts = [nums[0], nums[1]]
			_tex.a = _item(params[0])
			_tex.b = _item(params[1])
			_tex.result = _item(result)
		"mine":
			var mineral := fn.trim_prefix("mine_")
			var m := RegEx.create_from_string("drops (\\d+)").search(desc)
			_a.mineral = mineral
			_a.per = int(m.get_string(1)) if m else (nums[0] if nums.size() > 0 else 1)
			_tex.ore = _item("ore_" + mineral)
			_tex.gem = _item(mineral)
			_tex.pick = _item("pickaxe")
		"detect":
			var mob := fn.trim_prefix("detect_")
			var m := RegEx.create_from_string("less than (\\d+)").search(desc)
			_a.mob = mob
			_a.limit = maxi(1, int(m.get_string(1)) if m else (nums[0] if nums.size() > 0 else 5))
			var path := "res://assets/survival/%s.png" % MOBS.get(mob, "slime")
			_tex.mob = load(path) if ResourceLoader.exists(path) else null
			_tex.player = Characters.front(Global.character)


func _params(code: String) -> Array:
	var m := RegEx.create_from_string("def\\s+\\w+\\s*\\(([^)]*)\\)").search(code)
	if not m:
		return []
	var out := []
	for p in m.get_string(1).split(","):
		if not p.strip_edges().is_empty():
			out.append(p.strip_edges())
	return out


func _item(word: String) -> Texture2D:
	var n: String = ITEM_ALIASES.get(word, word)
	var path := ITEM_DIR % n
	return load(path) if ResourceLoader.exists(path) else null


func _mob_frame_tex() -> Texture2D:
	var src: Texture2D = _tex.get("mob")
	if src == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = src
	at.region = Rect2(0, 0, 16, 16)
	return at


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


# ------------------------------------------------------------------ drawing helpers
func _ground_h() -> float:
	return 34.0


func _box(r: Rect2, bg: Color, border: Color, radius := 8, bw := 2, corners := [true, true, true, true]) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.corner_radius_top_left = radius if corners[0] else 0
	sb.corner_radius_top_right = radius if corners[1] else 0
	sb.corner_radius_bottom_right = radius if corners[2] else 0
	sb.corner_radius_bottom_left = radius if corners[3] else 0
	draw_style_box(sb, r)


func _text(pos: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, w := -1.0) -> void:
	var outline := Color(0.05, 0.05, 0.1, 0.85)
	draw_string_outline(FONT, pos, s, align, w, sz, 5, outline)
	draw_string(FONT, pos, s, align, w, sz, col)


func _sprite(tex: Texture2D, center: Vector2, px: float, region := Rect2()) -> void:
	if tex == null:
		return
	var r := Rect2(center - Vector2(px, px) * 0.5, Vector2(px, px))
	if region.has_area():
		draw_texture_rect_region(tex, r, region)
	else:
		draw_texture_rect(tex, r, false)


func _slot(center: Vector2, tex: Texture2D, count: String, label: String, glow := false) -> void:
	var s := 84.0
	var r := Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s))
	if glow:
		var g := 0.35 + 0.25 * sin(_t * 3.0)
		_box(r.grow(6), Color(1.0, 0.8, 0.28, g * 0.35), Color(0, 0, 0, 0), 14, 0)
	_box(r, Color(0.07, 0.08, 0.14, 0.72) if dark else Color(1, 1, 1, 0.78),
		Color(1.0, 0.8, 0.28) if glow else (Color(0.55, 0.6, 0.8, 0.8) if dark else Color(0.45, 0.4, 0.3, 0.6)), 10, 3)
	_sprite(tex, center, 64)
	if count != "":
		_text(Vector2(r.end.x - 76, r.end.y - 6), count, 26, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT, 70)
	if label != "":
		_text(Vector2(r.position.x - 30, r.end.y + 24), label.to_upper(), 22, Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER, s + 60)


func _op(center: Vector2, s: String) -> void:
	_text(center + Vector2(-20, 14), s, 46, Color(1.0, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 40)


# ------------------------------------------------------------------ scene
func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10 or h < 10:
		return
	_draw_backdrop(w, h)
	match kind:
		"craft", "brew": _draw_recipe(w, h)
		"mine": _draw_mine(w, h)
		"detect": _draw_detect(w, h)
		_: _text(Vector2(0, h * 0.5 + 30), _a.get("icon", "💻"), 96, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_backdrop(w: float, h: float) -> void:
	var gh := _ground_h()
	var top := Color("#141a3c") if dark else Color("#7cc4f5")
	var bot := Color("#33427a") if dark else Color("#d8efff")
	# banded pixel sky (top corners rounded, bands square)
	_box(Rect2(0, 0, w, h - gh), top, Color(0, 0, 0, 0), 10, 0, [true, true, false, false])
	var bands := 7
	for i in range(1, bands):
		var y0 := (h - gh) * float(i) / bands
		draw_rect(Rect2(0, y0, w, (h - gh) / bands + 1), top.lerp(bot, float(i) / (bands - 1)))
	if dark:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 40:
			var p := Vector2(rng.randf() * w, rng.randf() * (h - gh - 20))
			var tw := 0.45 + 0.45 * sin(_t * 2.0 + i * 1.7)
			var s := 2.0 if i % 5 else 3.0
			draw_rect(Rect2(p.floor(), Vector2(s, s)), Color(1, 1, 0.9, tw))
		# moon
		var mc := Vector2(40, 34)
		draw_circle(mc, 16, Color("#f4ecd0"))
		draw_circle(mc + Vector2(7, -5), 14, top)
	else:
		var sc := Vector2(42, 38)
		draw_circle(sc, 22 + sin(_t * 2.0), Color(1, 0.9, 0.4, 0.35))
		draw_circle(sc, 16, Color("#ffd84a"))
		var cx := fmod(_t * 12.0, w + 160) - 80
		for c in [[cx, 34.0], [fmod(cx + w * 0.55, w + 160) - 80, 60.0]]:
			var cp := Vector2(c[0], c[1])
			draw_rect(Rect2(cp + Vector2(-34, 0), Vector2(68, 12)), Color(1, 1, 1, 0.9))
			draw_rect(Rect2(cp + Vector2(-20, -10), Vector2(36, 12)), Color(1, 1, 1, 0.9))
	# ground: grass lip + dirt with speckles
	var g0 := h - gh
	_box(Rect2(0, g0, w, gh), Color("#6b4428") if dark else Color("#8a5a32"), Color(0, 0, 0, 0), 10, 0, [false, false, true, true])
	draw_rect(Rect2(0, g0, w, 8), Color("#3f8f45") if dark else Color("#5cbf55"))
	draw_rect(Rect2(0, g0 + 8, w, 3), Color("#2c6a33") if dark else Color("#3f9a44"))
	var x := 6.0
	var k := 0
	while x < w - 6:
		draw_rect(Rect2(x, g0 + 16 + (k % 3) * 5, 4, 4), Color(0, 0, 0, 0.18))
		x += 23 + (k * 7) % 13
		k += 1


func _draw_recipe(w: float, h: float) -> void:
	var cy := (h - _ground_h()) * 0.5 - 6
	var gap := 128.0
	var cx := w * 0.5
	var bob := sin(_t * 2.6) * 4.0
	_slot(Vector2(cx - gap * 1.25, cy), _tex.get("a"), "x%d" % _a.counts[0], _a.names[0])
	_op(Vector2(cx - gap * 0.62, cy), "+")
	_slot(Vector2(cx, cy), _tex.get("b"), "x%d" % _a.counts[1], _a.names[1])
	_op(Vector2(cx + gap * 0.62, cy), "=")
	_slot(Vector2(cx + gap * 1.25, cy + bob), _tex.get("result"), "", _a.names[2], true)
	if kind == "brew":   # bubbles rising from the potion
		for i in 5:
			var ph := fmod(_t * 0.8 + i * 0.21, 1.0)
			var p := Vector2(cx + gap * 1.25 - 16 + i * 8 + sin(_t * 3 + i) * 3, cy - 44 - ph * 40)
			draw_circle(p, 3.0 + i % 2, Color(0.85, 0.65, 1.0, 1.0 - ph))


func _draw_mine(w: float, h: float) -> void:
	var cy := (h - _ground_h()) * 0.5 - 6
	var per: int = _a.per
	var row_w := mini(per, 6) * 46.0
	var total := 84.0 + 70.0 + row_w
	var x0 := (w - total) * 0.5
	var ore_c := Vector2(x0 + 42, cy)
	var swing := fmod(_t, 1.2) / 1.2                 # 0..1 per hit
	var hit := swing > 0.55 and swing < 0.7
	var shake := Vector2(sin(_t * 80.0) * 2.0, 0) if hit else Vector2.ZERO
	_slot(ore_c + shake, _tex.get("ore"), "x1", "%s ore" % _a.mineral)
	# pickaxe swings from raised to strike on the ore's top-right corner
	var ang := lerpf(-1.1, 0.35, ease(clampf(swing / 0.6, 0, 1), 2.5)) if swing < 0.6 else lerpf(0.35, -1.1, (swing - 0.6) / 0.4)
	draw_set_transform(ore_c + Vector2(52, -40), ang, Vector2.ONE)
	_sprite(_tex.get("pick"), Vector2(0, -6), 52)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if hit:
		for i in 4:
			var d := Vector2(cos(i * 1.6), sin(i * 1.6)) * (10 + (swing - 0.55) * 160)
			draw_rect(Rect2(ore_c + Vector2(30, -30) + d, Vector2(4, 4)), Color(1, 0.95, 0.6))
	_op(Vector2(x0 + 84 + 35, cy), "→")
	# gems pop in one after another every loop
	var shown := int(fmod(_t * 3.0, per + 3.0))
	for i in per:
		var col := i % 6
		var row := i / 6
		var c := Vector2(x0 + 84 + 70 + 23 + col * 46, cy - 6 + row * 44 - (20 if per > 6 else 0))
		var vis := i < shown
		var pop := 0.92 + 0.08 * sin(_t * 4 + i)
		if vis:
			_sprite(_tex.get("gem"), c + Vector2(0, sin(_t * 3 + i) * 2), 44 * pop)
		else:
			_box(Rect2(c - Vector2(14, 14), Vector2(28, 28)), Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.25), 6, 2)
	_text(Vector2(x0 + 84 + 70, cy + 66), "%d %s PER ORE" % [per, "GEM" if per == 1 else "GEMS"], 22,
		Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER, row_w + 8)


func _draw_detect(w: float, h: float) -> void:
	var gh := _ground_h()
	var g0 := h - gh
	var limit: int = _a.limit
	var maxd := limit * 2
	var x0 := 92.0
	var x1 := w - 36.0
	var unit := (x1 - x0) / maxd
	var lx := x0 + limit * unit
	# zones
	draw_rect(Rect2(x0, 18, lx - x0, g0 - 18), Color(1, 0.25, 0.25, 0.16))
	draw_rect(Rect2(lx, 18, x1 - lx, g0 - 18), Color(0.3, 1, 0.45, 0.10))
	_text(Vector2(x0, 40), "DANGER ZONE", 24, Color("#ff8a8a"), HORIZONTAL_ALIGNMENT_CENTER, lx - x0)
	_text(Vector2(lx, 40), "SAFE", 24, Color("#8dffa8"), HORIZONTAL_ALIGNMENT_CENTER, x1 - lx)
	# dashed threshold line
	var y := 18.0
	while y < g0:
		draw_rect(Rect2(lx - 1, y, 3, 8), Color(1, 0.85, 0.35))
		y += 14
	# ruler ticks in the dirt
	var step := 1 if maxd <= 12 else 2
	for d in range(0, maxd + 1, step):
		var tx := x0 + d * unit
		draw_rect(Rect2(tx - 1, g0 + 8, 2, 6), Color(1, 1, 1, 0.75))
		_text(Vector2(tx - 20, g0 + 31), str(d), 18,
			Color(1, 0.85, 0.35) if d == limit else Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 40)
	# player at distance 0
	var pt: Texture2D = _tex.get("player")
	if pt:
		var ph := 78.0
		var pw := ph * pt.get_width() / pt.get_height()
		draw_texture_rect(pt, Rect2(Vector2(x0 - pw * 0.5, g0 - ph + 4), Vector2(pw, ph)), false)
	# wandering mob
	var dist := clampf(limit + (limit * 0.8) * sin(_t * 0.7), 0.6, maxd - 0.4)
	var mx := x0 + dist * unit
	var frame := int(_t * 4.0) % 2
	_sprite(_tex.get("mob"), Vector2(mx, g0 - 26), 52, Rect2(frame * 16, 0, 16, 16))
	var danger := dist < limit
	var tag := "d = %d  →  %s" % [int(dist), "DANGER" if danger else "SAFE"]
	var tw := 150.0
	var tr := Rect2(clampf(mx - tw * 0.5, 4, w - tw - 4), g0 - 98, tw, 30)
	_box(tr, Color(0.07, 0.08, 0.14, 0.85), Color("#ff6b6b") if danger else Color("#5ee08a"), 8, 2)
	_text(Vector2(tr.position.x, tr.position.y + 23), tag, 22, Color("#ffb0b0") if danger else Color("#b4ffc6"), HORIZONTAL_ALIGNMENT_CENTER, tw)
	_text(Vector2(lx - 60, g0 - 6), "< %d" % limit, 22, Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER, 50)
