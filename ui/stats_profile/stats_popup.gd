extends CanvasLayer
class_name StatsPage

# Lifetime stats page (pixel style). StatsPage.open(parent, on_reset)

var _on_reset: Callable


static func open(parent: Node, on_reset: Callable) -> CanvasLayer:
	# load() instead of the class name: a script can't name itself before it is registered
	var s = load("res://ui/stats_profile/stats_popup.gd").new()
	s._on_reset = on_reset
	parent.add_child(s)
	return s


func _ready() -> void:
	var v := PixelUI.page(self, "📊 Your Stats", 680, queue_free)
	# The only door into Survival mode: a small bug button next to close.
	var head: HBoxContainer = v.get_child(0)
	var bug := PixelUI.button("🐛", func(): get_tree().change_scene_to_file("res://survival/survival.tscn"))
	bug.custom_minimum_size = Vector2(48, 48)
	bug.tooltip_text = "Survival mode"
	head.add_child(bug)
	head.move_child(bug, 1)
	var s: Dictionary = Global.stats
	var n := func(k: String) -> String: return str(int(s.get(k, 0)))
	var games := int(s.total_games)
	var rate := "%d%%" % int(round(100.0 * s.total_wins / games)) if games > 0 else "-"
	var secs := int(s.total_play_time)
	var tiles := [
		["🎯", "Games", str(games), PixelUI.CREAM],
		["🏆", "Wins", n.call("total_wins"), Color(0.5, 0.95, 0.55)],
		["❌", "Losses", n.call("total_losses"), Color(1.0, 0.5, 0.45)],
		["📈", "Win rate", rate, PixelUI.GOLD],
		["⏳", "Play time", "%dm %ds" % [secs / 60, secs % 60], PixelUI.CREAM],
		["💡", "Hints used", n.call("total_hints_used"), PixelUI.GOLD],
		["⭐", "Total score", n.call("total_score"), PixelUI.GOLD],
		["🧭", "Best level", n.call("best_level"), Color(0.5, 0.95, 0.55)],
		["🔥", "Win streak", str(Global.win_streak), Color(1.0, 0.6, 0.3)],
	]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for t in tiles:
		var p := PixelUI.panel()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		p.add_child(box)
		box.add_child(PixelUI.label("%s %s" % [t[0], t[1]], 22, PixelUI.MUTED))
		box.add_child(PixelUI.label(t[2], 44, t[3]))
		grid.add_child(p)

	var surv := int(s.get("survival_best_round", 0))
	v.add_child(PixelUI.label("AI difficulty right now: %s%s" % [Global.difficulty.capitalize(),
		("   ·   💀 Survival best: round %d" % surv) if surv > 0 else ""], 24, PixelUI.MUTED))

	# reset asks twice
	var reset := PixelUI.button("Reset all progress", func(): pass)
	reset.pressed.connect(func():
		if reset.text.begins_with("Reset"):
			reset.text = "Sure? Click again to erase everything"
		else:
			queue_free()
			_on_reset.call())
	reset.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	v.add_child(reset)
