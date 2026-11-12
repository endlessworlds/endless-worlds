# Global.gd (Autoload)
extends Node


enum QuestionType {
	MCQ,
	FILL_BLANK,
	WORDLE,
	WHACK,
	WORD_LOCK,
	KBC,
	CODING
}


const SAVE_PATH := "user://save.json"
var rl: DifficultyRL
var difficulty: String = "MEDIUM"
var current_question_type: QuestionType = QuestionType.MCQ
var is_coding_mode: bool = false
var current_coding_question: Dictionary = {}
var coding_theme: String = "dark"     # coding screen editor theme: "dark" | "light" (saved)
var coding_drafts: Dictionary = {}    # quest title -> unsubmitted code, so closing the popup keeps your work
var coding_solved_session := 0        # quests solved since "Coding" was pressed on the home screen
var _coding_questions: Array = []     # unique quests from data/coding_questions.json (cached)
var _coding_deck: Array = []          # shuffled indices still to play; refilled when empty


# Backend for AI riddles / code checks. Override per deployment with the project
# setting "application/config/api_base_url", or on the web build by defining
# `window.ENDLESS_WORLDS_API = "https://..."` in the HTML shell (export head_include).
var api_base_url: String = "http://127.0.0.1:8000"
var win_streak: int = 0
var player_name: String = ""   # empty until chosen; online rooms then get a random name
var character: int = 0   # 0 .. Characters.COUNT - 1
var torch_mode := 0  # 0 auto (night), 1 always on, 2 off
var graphics := "auto"  # "auto" | "high" | "low" (saved); see Screen.low()
var sound_volume := 1.0  # 0..1 master volume (saved)
var music_volume := 1.0  # 0..1 ambience tracks, "Music" bus (saved)
var sfx_volume := 1.0    # 0..1 every other sound, "SFX" bus (saved)
var voice_volume := 1.0  # 0..1 Bolt's text-to-speech; not an audio bus (saved)
var vibration := true    # phones: short buzz when hurt (saved)
var input_locked := false  # true while typing (chat / ask-the-bot) so WASD doesn't move the player


# Pixel-art icon font mapped onto emoji code points (assets/fonts/pixel_icons.fnt).
# Installed as the first fallback of every UI font, so any emoji in any label renders
# as a matching 16px pixel icon instead of a glossy system emoji.
# Behind it: a full colour emoji font (anything players type: chat, topics, names) and a
# symbol font (● ✓ ✗ → ▸ …). Desktop can borrow those from the OS, but the web build
# gets no system fonts at all, so without them every emoji/symbol showed as a box.
var _fonts_keepalive: Array = []

func _install_icon_font() -> void:
	var chain: Array[Font] = []
	var icons: FontFile = load("res://assets/fonts/pixel_icons.fnt")
	if icons:
		icons.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY  # crisp 1x/2x/3x pixels
		chain.append(icons)
	for path in ["res://assets/fonts/NotoColorEmoji-Regular.ttf", "res://assets/fonts/DejaVuSans-Symbols.ttf"]:
		if ResourceLoader.exists(path):
			var f: FontFile = load(path)
			if f:
				f.modulate_color_glyphs = false   # keep emoji in their own colours
				chain.append(f)
	_fonts_keepalive.append_array(chain)
	for f in [load("res://assets/fonts/Jersey10-Regular.ttf"), ThemeDB.fallback_font]:
		if not f is Font:
			continue
		var fb: Array[Font] = []
		fb.append_array(chain)
		for old in f.fallbacks:
			if not fb.has(old):
				fb.append(old)
		f.fallbacks = fb
		_fonts_keepalive.append(f)  # keep the patched resource cached for later load() calls


func _ready():
	_install_icon_font()
	api_base_url = ProjectSettings.get_setting("application/config/api_base_url", api_base_url)
	# The packaged .env can point a shared build at a hosted AI server (API_URL=https://...).
	api_base_url = str(EnvLoader.load_env().get("API_URL", api_base_url))
	if OS.has_feature("web"):
		var js_url = JavaScriptBridge.eval("window.ENDLESS_WORLDS_API || ''")
		if typeof(js_url) == TYPE_STRING and not js_url.is_empty():
			api_base_url = js_url
	api_base_url = api_base_url.trim_suffix("/")
	load_game()
	apply_sound()
	for arg in OS.get_cmdline_user_args():  # dev: -- --char=N tries a character without the picker
		if arg.begins_with("--char="):
			character = int(arg.get_slice("=", 1))
	_init_rl()


# Daily visit streak: the first visit of a day extends it (or restarts it after a missed
# day) and pays a small coin bonus for the Survival armory. Returns the bonus (0 = already
# counted today).
func daily_checkin() -> int:
	var today := Time.get_date_string_from_system()
	if str(stats.get("last_day", "")) == today:
		return 0
	var local_now := int(Time.get_unix_time_from_system()) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var yesterday := Time.get_date_string_from_unix_time(local_now - 86400)
	var streak := int(stats.get("day_streak", 0))
	streak = streak + 1 if str(stats.get("last_day", "")) == yesterday else 1
	stats["day_streak"] = streak
	stats["last_day"] = today
	var bonus := mini(10 * streak, 50)
	stats["survival_coins"] = int(stats.get("survival_coins", 0)) + bonus
	save_game()
	return bonus


func apply_sound() -> void:
	_set_bus("Master", sound_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


# Music / SFX buses are made here (Global loads first), so players just use them by name.
func _set_bus(bus_name: String, vol: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_mute(i, vol <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(vol, 0.001)))


# Text-to-speech volume (0..100) for Bolt: the Voice slider times the master volume.
func voice_tts_volume() -> int:
	return int(round(100.0 * voice_volume * sound_volume))


# A fun random name for online rooms (Global.player_name until the player types their own).
const NAME_ADJ := ["Swift", "Brave", "Sneaky", "Lucky", "Fuzzy", "Cosmic", "Turbo", "Sleepy",
	"Mighty", "Pixel", "Jolly", "Witty", "Shiny", "Zippy", "Bold", "Quiet"]
const NAME_ANIMAL := ["Fox", "Otter", "Panda", "Falcon", "Gecko", "Yak", "Owl", "Lynx",
	"Koala", "Badger", "Moth", "Toad", "Wolf", "Crab", "Llama", "Raven"]

func random_player_name() -> String:
	return "%s %s" % [NAME_ADJ.pick_random(), NAME_ANIMAL.pick_random()]


func api_url(path: String) -> String:
	return api_base_url + path


# ------------------------------------------------------------------ coding quests
# Quests are dealt from a shuffled deck so a session never repeats one until every
# quest has been seen; exact duplicates in the JSON (same text + tests) are dropped.
func coding_questions() -> Array:
	if _coding_questions.is_empty():
		var arr = JSON.parse_string(FileAccess.get_file_as_string("res://data/coding_questions.json"))
		var seen := {}
		if typeof(arr) == TYPE_ARRAY:
			for q in arr:
				if typeof(q) != TYPE_DICTIONARY:
					continue
				var key := str(q.get("desc", "")) + str(q.get("testCases", []))
				if not seen.has(key):
					seen[key] = true
					_coding_questions.append(q)
	return _coding_questions


func start_coding_session() -> void:
	coding_solved_session = 0
	_coding_deck.clear()
	current_coding_question = next_coding_question()


func next_coding_question() -> Dictionary:
	var all := coding_questions()
	if all.is_empty():
		return {}
	if _coding_deck.is_empty():
		for i in all.size():
			_coding_deck.append(i)
		_coding_deck.shuffle()
		# don't deal the quest that was just played as the first card of a fresh deck
		if all.size() > 1 and all[_coding_deck.back()] == current_coding_question:
			_coding_deck.push_front(_coding_deck.pop_back())
	return all[_coding_deck.pop_back()]

func _init_rl():
	if rl != null and is_instance_valid(rl):
		return
	rl = DifficultyRL.new()
	add_child(rl)
	if rl.has_method("init_rl"):
		rl.init_rl()
	difficulty = rl.choose_difficulty()

func save_game():
	var data := {
		"stats": stats,
		"high_score": high_score,
		"selected_topic": selected_topic,
		"win_streak": win_streak,
		"player_name": player_name,
		"character": character,
		"coding_theme": coding_theme,
		"graphics": graphics,
		"sound_volume": sound_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"voice_volume": voice_volume,
		"vibration": vibration,
		"learning_journal": learning_journal
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("✅ Game saved")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("ℹ No save file found")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("❌ Save file corrupted")
		return

	stats = data.get("stats", stats)
	high_score = data.get("high_score", high_score)
	selected_topic = data.get("selected_topic", selected_topic)
	win_streak = int(data.get("win_streak", 0))
	player_name = str(data.get("player_name", player_name))
	character = int(data.get("character", 0))
	coding_theme = "light" if str(data.get("coding_theme", "dark")) == "light" else "dark"
	graphics = str(data.get("graphics", "auto"))
	if not graphics in ["auto", "high", "low"]:
		graphics = "auto"
	sound_volume = clampf(float(data.get("sound_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 1.0)), 0.0, 1.0)
	voice_volume = clampf(float(data.get("voice_volume", 1.0)), 0.0, 1.0)
	vibration = bool(data.get("vibration", true))
	if data.has("learning_journal"):
		var lj = data["learning_journal"]
		if lj.has("solved_riddles"):
			learning_journal.solved_riddles = lj["solved_riddles"]
		if lj.has("concepts"):
			learning_journal.concepts = lj["concepts"]

	print("✅ Save loaded")

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("🗑️ Stats save deleted")
	else:
		print("⚠️ No save file found")
	reset_difficulty_model()
	print("🧠 Difficulty RL reset done")

func reset_all_stats():
	# Reset lifetime stats
	stats = {
		"total_games": 0,
		"total_wins": 0,
		"total_losses": 0,
		"total_score": 0,
		"total_play_time": 0.0,
		"total_hints_used": 0,
		"best_level": 1,
		"topics": {}
	}

	# Reset session + game values
	score = 0
	high_score = 0
	level = 1
	selected_topic = "programming"
	session_start_time = 0.0
	current_hint_count = 0
	win_streak = 0

	# Reset learning journal
	learning_journal = {"solved_riddles": [], "concepts": []}

	# Delete saved file
	delete_save()
	
	# Immediately write a clean save
	reset_difficulty_model()
	save_game()

func get_difficulty() -> String:
	_init_rl()
	difficulty = rl.choose_difficulty()
	return difficulty

func update_difficulty(win: bool, hints_used: int):
	_init_rl()
	rl.give_feedback(win, hints_used)
	difficulty = rl.current_diff

func reset_difficulty_model():
	if FileAccess.file_exists("user://difficulty_rl.json"):
		DirAccess.remove_absolute("user://difficulty_rl.json")
	if rl != null and is_instance_valid(rl):
		rl.queue_free()
	rl = DifficultyRL.new()
	add_child(rl)
	if rl.has_method("init_rl"):
		rl.init_rl()
	difficulty = rl.choose_difficulty()

# ================= BASIC GAME DATA =================
var selected_topic: String = "programming"
var score: int = 0
var high_score: int = 0
var level: int = 1

# ================= SESSION TRACKING =================
var session_start_time := 0.0
var current_hint_count := 0

# ================= LEARNING JOURNAL =================
var show_journal_on_home: bool = false

var learning_journal := {
	"solved_riddles": [],  # {question, answer, topic, timestamp}
	"concepts": [],        # {name, definition, topic, timestamp}
}

func add_riddle_to_journal(question: String, answer: String) -> void:
	learning_journal.solved_riddles.append({
		"question": question,
		"answer": answer,
		"topic": selected_topic,
		"timestamp": Time.get_unix_time_from_system()
	})
	save_game()

func add_concept_to_journal(concept_text: String) -> void:
	if concept_text.strip_edges().is_empty():
		return
	# Avoid duplicates (compare full text)
	for entry in learning_journal.concepts:
		if entry.get("definition", "") == concept_text:
			return
	learning_journal.concepts.append({
		"name": concept_text.left(60),
		"definition": concept_text,
		"topic": selected_topic,
		"timestamp": Time.get_unix_time_from_system()
	})
	save_game()

# ================= LIFETIME STATS =================
var stats := {
	"total_games": 0,
	"total_wins": 0,
	"total_losses": 0,
	"total_score": 0,
	"total_play_time": 0.0,
	"total_hints_used": 0,
	"best_level": 1,

	# topic → data
	"topics": {
		# "programming": { "played": 3, "wins": 2, "losses": 1, "time": 120 }
	}
}

func reset_score():
	score = 0
	level = 1

func reset_score_only():
	score = 0

func add_score(amount: int):
	score += amount
	if(score<0):
		score=0
	if score > high_score:
		high_score = score

func next_level():
	level += 1

# ================= SESSION CONTROL =================
func start_game():
	session_start_time = Time.get_unix_time_from_system()
	current_hint_count = 0

func record_hint():
	current_hint_count += 1

func end_game(win: bool):
	var now := Time.get_unix_time_from_system()
	var time_played := now - session_start_time

	stats.total_games += 1
	stats.total_play_time += time_played
	stats.total_hints_used += current_hint_count
	stats.total_score += score

	if level > stats.best_level:
		stats.best_level = level

	# Topic stats
	if not stats.topics.has(selected_topic):
		stats.topics[selected_topic] = {
			"played": 0,
			"wins": 0,
			"losses": 0,
			"time": 0.0
		}

	var t = stats.topics[selected_topic]
	t.played += 1
	t.time += time_played

	if win:
		stats.total_wins += 1
		t.wins += 1
		win_streak += 1
	else:
		stats.total_losses += 1
		t.losses += 1
		win_streak = 0
		
	update_difficulty(win, current_hint_count)
	save_game()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func stats_to_string() -> String:
	var s := ""
	s += "Total Games: %d\n" % stats.total_games
	s += "Wins: %d\n" % stats.total_wins
	s += "Losses: %d\n" % stats.total_losses
	s += "Total Time: %d s\n" % int(stats.total_play_time)
	s += "Hints Used: %d\n" % stats.total_hints_used
	s += "Total Score: %d\n" % stats.total_score
	s += "Best Level: %d\n" % stats.best_level
	s += "Current Topic: %s\n" % selected_topic
	s += "Difficulty: %s\n" % difficulty
	return s
