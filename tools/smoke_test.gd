# Automated play-through used by CI (.github/workflows/smoke.yml). It walks through every
# screen with the real engine and prints one line per step; any "SCRIPT ERROR" in the
# log is a real bug in that step.
#   godot --headless --path . res://tools/smoke_test.tscn -- --surv-bot --surv-god [--touch]
extends Node


func _ready() -> void:
	var r := Runner.new()
	r.name = "SmokeRunner"
	get_tree().root.add_child.call_deferred(r)


class Runner extends Node:
	var fails := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _run()
		print("SMOKE DONE: %d check(s) failed" % fails)
		get_tree().quit(1 if fails > 0 else 0)

	func step(s: String) -> void:
		print("SMOKE: ", s)

	func check(ok: bool, what: String) -> void:
		if not ok:
			fails += 1
			printerr("SMOKE CHECK FAILED: " + what)

	func frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func secs(t: float) -> void:
		await get_tree().create_timer(t, true, false, true).timeout

	func scene() -> Node:
		return get_tree().current_scene

	func goto(path: String) -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(path)
		await frames(6)

	func close_modals() -> void:
		for m in get_tree().get_nodes_in_group("modal"):
			m.queue_free()
		get_tree().paused = false
		Global.input_locked = false
		await frames(3)

	func key(code: Key, unicode := 0) -> void:
		for down in [true, false]:
			var e := InputEventKey.new()
			e.keycode = code
			e.unicode = unicode
			e.pressed = down
			Input.parse_input_event(e)
		await frames(2)

	func _run() -> void:
		step("touch=%s low=%s viewport=%s" % [Screen.is_touch, Screen.low(), get_tree().root.get_visible_rect().size])
		await _home()
		await _keyboard()
		await _map_riddles()
		await _map_coding()
		await _survival()
		await _layouts()

	# ------------------------------------------------------------ home + pages
	func _home() -> void:
		step("home screen")
		await goto("res://ui/home_screen/home_screen.tscn")
		var home := scene()
		check(home != null and home.has_method("_relayout"), "home scene loaded")
		home._relayout()
		step("stats page + graphics toggle")
		var stats: Node = StatsPage.open(home, func(): pass)
		await frames(5)
		for i in 3:
			Screen.cycle_graphics()
			await frames(2)
		await close_modals()
		step("settings page")
		SettingsPage.open(home)
		await frames(5)
		Global.sound_volume = 0.5
		Global.apply_sound()
		Screen.vibrate(10)
		await close_modals()
		Global.sound_volume = 1.0
		Global.apply_sound()
		step("achievements")
		Achievements.open(home)
		await frames(5)
		await close_modals()
		step("journal")
		home._open_journal()
		await frames(5)
		await close_modals()
		step("tutorial")
		var tut := TutorialOverlay.new()
		home.add_child(tut)
		tut.open()
		await frames(5)
		for i in 7:
			if is_instance_valid(tut):
				tut._go(1)
				await frames(2)
		await close_modals()
		step("lobby (no connection)")
		var lobby := Lobby.open(home, func(): return "Space")
		await frames(5)
		lobby._on_close()
		await frames(3)
		step("install card + fullscreen label")
		Screen.fullscreen_label()
		Screen.controls_hint()
		step("character picker / chips / topic")
		home.topic_input.text = "Space"
		home._on_size_changed()
		await frames(4)

	# ------------------------------------------------------------ on-screen keyboard
	func _keyboard() -> void:
		step("game keyboard")
		var kb: GameKeyboard = Screen.keyboard
		var own := false
		if kb == null:
			kb = GameKeyboard.new()
			add_child(kb)
			own = true
		var home := scene()
		home.topic_input.text = ""
		home.topic_input.grab_focus()
		await frames(4)
		check(kb.is_open(), "keyboard opens when a text box has focus")
		for k in ["h", "i", "space", "⇧", "A", "123", "4", "#+=", "[", "abc", "😀", "🔥", "abc", "⌫"]:
			kb._on_down(k)
			kb._stop_repeat()
			await frames(3)
		step("typed: '%s'" % home.topic_input.text)
		check(home.topic_input.text == "hi A4[", "keyboard typed 'hi A4[' (got '%s')" % home.topic_input.text)
		var te := TextEdit.new()
		te.size = Vector2(300, 120)
		home.add_child(te)
		te.grab_focus()
		await frames(4)
		for k in ["x", "⏎", "⇥", "y", "←", "→"]:
			kb._on_down(k)
			kb._stop_repeat()
			await frames(3)
		step("code typed: %s" % JSON.stringify(te.text))
		check(te.text.begins_with("x\n") and te.text.ends_with("y"), "keyboard types into the code editor")
		kb._on_down("⌄")
		await frames(4)
		check(not kb.is_open(), "keyboard closes")
		te.queue_free()
		if own:
			kb.queue_free()
		await frames(2)

	# ------------------------------------------------------------ riddle island
	func _wait_riddle(map: Node) -> void:
		for i in 200:
			if str(map.current_solution) != "":
				return
			await secs(0.1)

	func _map_riddles() -> void:
		step("map: solo riddle round")
		Global.is_coding_mode = false
		Global.selected_topic = "space"
		await goto("res://map_components/map.tscn")
		var map := scene()
		check(map != null and map.has_method("_on_well_interacted"), "map loaded")
		await _wait_riddle(map)
		check(str(map.current_solution) != "", "riddle arrived (offline bank)")
		step("riddle: '%s' options=%s" % [map.current_solution, map.current_options])
		await secs(1.0)
		step("map: riddle toggle, Bolt menu, pause, RL page, torch")
		map.riddle_ui._on_toggle_pressed()
		await frames(5)
		map.riddle_ui.unlock_next_hint()
		map.agentic_bot._voice.toggle_menu()
		await secs(0.5)
		map.agentic_bot._voice.toggle_menu()
		map.agentic_bot.speak("Testing the speech bubble with a fairly long line of text.")
		await secs(0.6)
		map.atmosphere.cycle_torch()
		map.toggle_debug_info()
		map._open_pause()
		await frames(5)
		await close_modals()
		map.get_node("RLOverlay").toggle()
		await secs(0.7)
		map.get_node("RLOverlay").toggle()
		await frames(3)
		step("map: walk + jump")
		Input.action_press("ui_right")
		await secs(0.5)
		Input.action_press("jump")
		await frames(3)
		Input.action_release("jump")
		await secs(0.6)
		Input.action_release("ui_right")
		step("map: hint pickup")
		for h in get_tree().get_nodes_in_group("hints"):
			h.emit_signal("collected")
			h.queue_free()
			break
		await frames(5)
		for t in [Global.QuestionType.MCQ, Global.QuestionType.FILL_BLANK, Global.QuestionType.WORDLE,
				Global.QuestionType.WHACK, Global.QuestionType.WORD_LOCK, Global.QuestionType.KBC]:
			step("answer popup type %d" % t)
			Global.current_question_type = t
			map.answer_popup.open(map.current_solution, map.current_options, map.hearts, map, map.current_question)
			await secs(0.4)
			check(map.answer_popup.visible, "popup type %d visible" % t)
			if t in [Global.QuestionType.FILL_BLANK, Global.QuestionType.WORDLE]:
				await key(KEY_A, 97)
				await key(KEY_B, 98)
				await key(KEY_BACKSPACE)
				if map.answer_popup.keyboard:
					map.answer_popup.keyboard._on_key_down("C")
					map.answer_popup.keyboard._on_key_down("BKSP")
			if t == Global.QuestionType.KBC:
				map.hearts.heal(9)
				map.answer_popup._kbc_use_fifty_fifty()
				await secs(0.3)
				map.answer_popup._kbc_use_audience_poll()
				await secs(0.3)
				map.answer_popup._kbc_use_phone_friend()   # 1 heart left: must refuse, not kill
				await secs(0.3)
				check(map.hearts.current_hearts >= 1 and not map._round_ended, "lifelines never knock the player out")
				map.hearts.heal(9)
			map.answer_popup.close()
			await frames(4)
		step("answer: wrong then right")
		Global.current_question_type = Global.QuestionType.MCQ
		map.answer_popup.open(map.current_solution, map.current_options, map.hearts, map, map.current_question)
		await frames(5)
		map.answer_popup._process_standard_answer("definitely-wrong")
		await secs(0.5)
		map.answer_popup._process_standard_answer(map.current_solution)
		await secs(2.5)
		step("round won card shown: modal=%d" % get_tree().get_nodes_in_group("modal").size())
		await close_modals()
		step("map: death")
		await goto("res://map_components/map.tscn")
		map = scene()
		await _wait_riddle(map)
		map.hearts.damage(map.hearts.max_hearts)
		await secs(1.0)
		check(get_tree().get_nodes_in_group("modal").size() > 0, "out-of-hearts card shown")
		await close_modals()

	func _map_coding() -> void:
		step("map: coding quest")
		Global.is_coding_mode = true
		Global.selected_topic = "coding"
		Global.start_coding_session()
		await goto("res://map_components/map.tscn")
		var map := scene()
		await secs(0.5)
		map._on_well_interacted()
		await secs(0.8)
		var pop: Node = map._coding_popup
		check(is_instance_valid(pop), "coding popup opened")
		if is_instance_valid(pop):
			pop._toggle_theme(true)
			await frames(5)
			pop._toggle_theme(false)
			await frames(5)
			pop._on_layout_changed()
			pop._on_keyboard_changed(300.0)
			await frames(3)
			pop._on_keyboard_changed(0.0)
			pop._reset_code()
			pop._skip_quest()
			await secs(0.5)
			pop._on_run_pressed()   # no server in CI: must fail gracefully
			await secs(1.5)
			pop.close()
		await secs(0.6)
		Global.is_coding_mode = false
		Global.input_locked = false

	# ------------------------------------------------------------ survival
	func _survival() -> void:
		step("survival: load")
		await goto("res://survival/survival.tscn")
		var g := scene()
		check(g != null and g.has_method("_fire"), "survival loaded")
		await secs(1.2)   # bot mode starts round 1 after 0.8 s
		step("survival: island cells=%d state=%s round=%d" % [g.walk_cells.size(), g.state, g.round_no])
		check(g.walk_cells.size() > 400, "island has land")
		check(g.is_walk(g.player.position), "player starts on land")
		step("survival: every weapon")
		for id in SurvivalArsenal.ORDER:
			g._fire(id, Vector2.RIGHT)
			await frames(6)
			g._fire_t = 0.0
		step("survival: every mob type + boss patterns")
		for tname in SurvivalMob.ORDER:
			g.portal(tname, g.near_player(60.0, 90.0), [] as Array[String])
		await secs(1.5)
		step("survival: mobs alive=%d" % g.mobs.size())
		check(g.mobs.size() > 0, "mobs spawned")
		for m in SurvivalMob.MUTATIONS:
			var muts: Array[String] = [m]
			g.portal("zombie", g.near_player(60.0, 90.0), muts)
		await secs(1.5)
		g._storm(Vector2.RIGHT, SurvivalArsenal.at_level("storm", 5))
		g.explode(g.player.position + Vector2(40, 0), 40.0, 0, false, true)
		g.drop_coins(g.player.position + Vector2(10, 0), 17)
		g.telegraph(g.player.position, 30.0, 0.5)
		g.telegraph_line(g.player.position, Vector2.RIGHT, 100.0, 0.5)
		for k in SurvivalGame.POWERUPS:
			g.take_powerup(k)
			await frames(3)
		g._maybe_powerup(g.player.position + Vector2(30, 0), true)
		g._dash()
		g._cycle_weapon(1)
		await secs(1.0)
		step("survival: night")
		g._day_t = 0.0
		await secs(0.5)
		check(g.dark > 0.8, "it is dark at midnight")
		step("survival: armory + intro + pause pages")
		SurvivalArsenal.add_coins(500)
		g._show_armory(func(): pass)
		await frames(6)
		check(SurvivalArsenal.buy_next("scatter"), "can buy a weapon")
		g._fill_armory()
		await frames(4)
		await close_modals()
		g.weapons = SurvivalArsenal.owned()
		g._show_intro()
		await frames(6)
		await close_modals()
		g._open_pause()
		await frames(4)
		await close_modals()
		step("survival: fast-forward a full run (bot + god mode)")
		Engine.time_scale = 6.0
		var t0 := Time.get_ticks_msec()
		while g.round_no < 4 and Time.get_ticks_msec() - t0 < 75000 and is_instance_valid(g):
			await secs(0.5)
		Engine.time_scale = 1.0
		step("survival: reached round %d, score %d, kills %d, state %s" % [g.round_no, g.score, g.kills, g.state])
		check(g.round_no >= 2, "survival gets past the first boss with the bot")
		step("survival: every boss")
		for i in SurvivalGame.BOSSES.size():
			for m in g.mobs.duplicate():
				if is_instance_valid(m):
					m.queue_free()
			g.mobs.clear()
			g.boss = null
			g.state = "boss_wait"
			g.round_no = i + 1
			g._spawn_boss()
			Engine.time_scale = 8.0
			await secs(1.6)
			Engine.time_scale = 1.0
			for pat in SurvivalGame.ALL_PATTERNS:
				if g.boss and is_instance_valid(g.boss) and not g.boss.dead:
					g.boss.state = ""
					g.boss._start_pattern(pat, Vector2.RIGHT, g.ppos())
				await frames(3)
		get_tree().paused = false
		await close_modals()
		step("survival: death card")
		g._god = false
		g.state = "waves"
		g.hearts.damage(99)
		await secs(0.6)
		await close_modals()

	# ------------------------------------------------------------ phone layouts
	func _layouts() -> void:
		step("layouts: portrait + landscape phone sizes")
		for size in [Vector2i(624, 1350), Vector2i(1350, 624), Vector2i(1280, 720)]:
			get_tree().root.content_scale_size = size
			await goto("res://ui/home_screen/home_screen.tscn")
			scene()._on_size_changed()
			await frames(4)
			StatsPage.open(scene(), func(): pass)
			await frames(4)
			await close_modals()
