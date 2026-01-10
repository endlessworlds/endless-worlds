# Global.gd (Autoload)
extends Node

const SAVE_PATH := "user://save.json"
func save_game():
	var data := {
		"stats": stats,
		"high_score": high_score,
		"selected_topic": selected_topic
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

	print("✅ Save loaded")

func delete_save():
	var path := "user://save.json"

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("🗑️ Stats save deleted")
	else:
		print("⚠️ No save file found")
		
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

	# Delete saved file
	delete_save()

	# Immediately write a clean save
	save_game()

# ================= BASIC GAME DATA =================
var selected_topic: String = "programming"
var score: int = 0
var high_score: int = 0
var level: int = 1

# ================= SESSION TRACKING =================
var session_start_time := 0.0
var current_hint_count := 0

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


func _ready():
	load_game()


func reset_score():
	score = 0
	level = 1

func reset_score_only():
	score = 0

func add_score(amount: int):
	score += amount
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
	else:
		stats.total_losses += 1
		t.losses += 1
		
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
	return s
