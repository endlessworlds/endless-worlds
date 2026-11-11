class_name Achievements

# Milestones worked out from the saved stats (nothing extra to store): [name, how, done?]

static func list() -> Array:
	var s: Dictionary = Global.stats
	var n := func(k: String) -> int: return int(s.get(k, 0))
	var arsenal = s.get("survival_arsenal", {})
	if typeof(arsenal) != TYPE_DICTIONARY:
		arsenal = {}
	var owned := 0
	var best_lvl := 0
	for id in arsenal:
		if int(arsenal[id]) > 0:
			owned += 1
		best_lvl = maxi(best_lvl, int(arsenal[id]))
	var facts: int = Global.learning_journal.concepts.size()
	return [
		["First answer", "Solve your first riddle", n.call("total_wins") >= 1],
		["Riddle fan", "Solve 10 riddles", n.call("total_wins") >= 10],
		["Riddle master", "Solve 25 riddles", n.call("total_wins") >= 25],
		["Climber", "Reach level 5", n.call("best_level") >= 5],
		["Bookworm", "Learn 10 facts (Journal)", facts >= 10],
		["Scholar", "Learn 30 facts (Journal)", facts >= 30],
		["Regular", "Play 3 days in a row", n.call("day_streak") >= 3],
		["Devoted", "Play 7 days in a row", n.call("day_streak") >= 7],
		["Survivor", "Survival: reach round 3", n.call("survival_best_round") >= 3],
		["Veteran", "Survival: reach round 5", n.call("survival_best_round") >= 5],
		["Legend", "Survival: reach round 10", n.call("survival_best_round") >= 10],
		["Boss slayer", "Survival: defeat a boss", n.call("survival_bosses") >= 1],
		["Boss hunter", "Survival: defeat 10 bosses", n.call("survival_bosses") >= 10],
		["Exterminator", "Survival: 100 monsters", n.call("survival_kills") >= 100],
		["Unstoppable", "Survival: 500 monsters", n.call("survival_kills") >= 500],
		["Collector", "Own 3 weapons", owned >= 3],
		["Arsenal", "Own all 6 weapons", owned >= 6],
		["Perfectionist", "Level a weapon to 5 stars", best_lvl >= 5],
	]


static func unlocked() -> int:
	var c := 0
	for a in list():
		if a[2]:
			c += 1
	return c


# The page (opened from Stats).
static func open(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	parent.add_child(layer)
	var all := list()
	var v := PixelUI.page(layer, "🏆 Achievements  %d/%d" % [unlocked(), all.size()], 700, layer.queue_free)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(440.0, parent.get_viewport().get_visible_rect().size.y - 200.0))
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 1 if Screen.is_narrow() else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for a in all:
		var card := PixelUI.panel(PixelUI.FRAME_ACTIVE if a[2] else PixelUI.FRAME, 14, 6)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.modulate.a = 1.0 if a[2] else 0.6
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		card.add_child(box)
		box.add_child(PixelUI.label(("★ " if a[2] else "☆ ") + str(a[0]), 26, PixelUI.GOLD if a[2] else PixelUI.MUTED, false))
		box.add_child(PixelUI.label(str(a[1]), 20, PixelUI.CREAM, false))
		grid.add_child(card)
	return layer
