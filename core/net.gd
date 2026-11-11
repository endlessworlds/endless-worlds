extends Node

# Online rooms through a tiny WebSocket relay (relay/ — a Cloudflare Worker).
# The relay only forwards JSON between up to 10 players in a room; all game
# logic runs on the host's machine (world seed, riddle generation, round flow).
#
# Messages: every packet is a Dictionary with "t" (type). The relay adds "from".
#   relay -> us : welcome{id, peers}, join{id,name}, leave{id}, error{msg}, host_left
#   game        : start{seed, qtype, topic, round}, riddle{data}, hint{idx}, topic{topic},
#                 pos{x,y,a,f,s,c}, won{name, answer}, chat{text}, hello{c}

signal connected(my_id: int)
signal peer_joined(id: int, player_name: String)
signal peer_left(id: int)
signal message(from: int, data: Dictionary)
signal disconnected(reason: String)

const MAX_PLAYERS := 10
const HOST_ONLY := ["start", "riddle", "topic"]
const DEFAULT_RELAY := "wss://endless-worlds-relay.srujanmpadmashali.workers.dev"
const COLORS: Array[Color] = [
	Color("4cc9f0"), Color("f72585"), Color("ffd60a"), Color("80ed99"), Color("ff8c42"),
	Color("b388ff"), Color("ff595e"), Color("00f5d4"), Color("f4a261"), Color("e0e0e0"),
]

var relay_url := DEFAULT_RELAY
var ws: WebSocketPeer
var my_id := 0
var room_code := ""
var player_name := "Player"
var peers := {}            # id -> name (includes me)
var peer_chars := {}       # id -> character index (from "hello" messages)
var active := false        # inside a connected room
var round_data := {}       # last "start" from host
var round_riddle := {}     # last riddle for this round (cached for late scene loads)
var round_hints: Array = []  # hint idxs already taken this round
var room_topic := ""       # topic the host picked for the next round (shown in the lobby)
var _connecting_for := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep the connection alive behind paused menus
	var env := EnvLoader.load_env()
	relay_url = str(env.get("RELAY_URL", ProjectSettings.get_setting("application/config/relay_url", DEFAULT_RELAY))).trim_suffix("/")
	set_process(false)


func is_host() -> bool:
	return active and my_id == 1


func color_of(id: int) -> Color:
	return COLORS[(maxi(id, 1) - 1) % COLORS.size()]


func host_room(name: String, code: String = "") -> void:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no 0/O/1/I confusion
	while code.length() < 5:
		code += chars[randi() % chars.length()]
	_open(code, name, true)


func join_room(code: String, name: String) -> void:
	_open(code.strip_edges().to_upper(), name, false)


func _open(code: String, name: String, host: bool) -> void:
	leave()
	room_code = code
	player_name = name.strip_edges().left(16) if not name.strip_edges().is_empty() else "Player"
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20  # voice clips for the host's AI server
	var url := "%s/room/%s?name=%s&host=%d" % [relay_url, code, player_name.uri_encode(), 1 if host else 0]
	print("[Net] connecting ", url)
	var err := ws.connect_to_url(url)
	if err != OK:
		disconnected.emit("Could not open connection (%s)" % error_string(err))
		return
	_connecting_for = 0.0
	set_process(true)


func send(data: Dictionary, to: int = 0) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if to != 0:
		data["to"] = to
	ws.send_text(JSON.stringify(data))


func leave() -> void:
	if ws:
		ws.close()
	ws = null
	active = false
	my_id = 0
	peers.clear()
	peer_chars.clear()
	round_data = {}
	round_riddle = {}
	round_hints = []
	room_topic = ""
	set_process(false)


func _process(delta: float) -> void:
	if ws == null:
		return
	ws.poll()
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING:
		_connecting_for += delta
		if _connecting_for > 8.0:
			_fail("Can't reach the multiplayer relay at %s" % relay_url)
		return
	if state == WebSocketPeer.STATE_CLOSED:
		print("[Net] socket closed: code %d reason '%s' after %.1f s" % [ws.get_close_code(), ws.get_close_reason(), Time.get_ticks_msec() / 1000.0])
		_fail("Connection closed (%d)" % ws.get_close_code() if not active else "Disconnected from room")
		return
	while ws and ws.get_available_packet_count() > 0:
		var data = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY:
			_handle(data)


func _fail(reason: String) -> void:
	print("[Net] ", reason)
	var was_room := room_code
	leave()
	if not was_room.is_empty():
		disconnected.emit(reason)


func _handle(d: Dictionary) -> void:
	match str(d.get("t", "")):
		"welcome":
			my_id = int(d.id)
			active = true
			peers.clear()
			for p in d.get("peers", []):
				peers[int(p.id)] = str(p.name)
			peers[my_id] = player_name
			peer_chars[my_id] = Global.character
			print("[Net] joined room %s as #%d" % [room_code, my_id])
			send({"t": "hello", "c": Global.character})
			connected.emit(my_id)
		"join":
			var id := int(d.id)
			peers[id] = str(d.name)
			send({"t": "hello", "c": Global.character}, id)   # tell the newcomer what I look like
			if is_host() and not room_topic.is_empty():
				send({"t": "topic", "topic": room_topic}, id)
			if is_host() and not round_data.is_empty():
				# Late joiner: hand them the running round so they drop straight in.
				send(round_data.duplicate(), id)
				if not round_riddle.is_empty():
					send({"t": "riddle", "data": round_riddle}, id)
				for idx in round_hints:
					send({"t": "hint", "idx": idx}, id)
			peer_joined.emit(id, str(d.name))
		"leave":
			peers.erase(int(d.id))
			peer_left.emit(int(d.id))
		"error":
			_fail(str(d.get("msg", "Relay error")))
		"host_left":
			_fail("The host left the room")
		_:
			var t := str(d.get("t", ""))
			if t == "hello":
				peer_chars[int(d.get("from", 0))] = int(d.get("c", 0))
			if t in HOST_ONLY and int(d.get("from", 0)) != 1:
				return  # the relay stamps the real sender; ignore forged round control
			# Cache round state so a scene that loads late still catches up.
			match t:
				"start":
					round_data = d
					round_riddle = {}
					round_hints = []
				"riddle":
					round_riddle = d.get("data", {})
				"hint":
					round_hints.append(int(d.idx))
				"topic":
					room_topic = str(d.get("topic", "")).left(40)
			message.emit(int(d.get("from", 0)), d)


# Scene for the running round: the riddle island or co-op Survival.
func round_scene() -> String:
	return "res://survival/survival.tscn" if str(round_data.get("mode", "island")) == "survival" else "res://map_components/map.tscn"


func in_survival() -> bool:
	return active and str(round_data.get("mode", "")) == "survival"


# Invite link for the current room: the game's own URL with ?room=CODE.
func invite_link() -> String:
	var base := "https://endlessworlds.github.io/endless-worlds/"
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("location.origin + location.pathname", true)
		if typeof(v) == TYPE_STRING and not str(v).is_empty():
			base = str(v)
	return "%s?room=%s" % [base, room_code]


# Room code from an invite link this page was opened with (web), once.
var _invite_checked := false

func take_invite_code() -> String:
	if _invite_checked or not OS.has_feature("web"):
		return ""
	_invite_checked = true
	var v = JavaScriptBridge.eval("""(function () {
		var c = new URLSearchParams(location.search).get('room') || '';
		if (c) { try { history.replaceState(null, '', location.pathname); } catch (e) {} }
		return c;
	})()""", true)
	var code := str(v).strip_edges().to_upper() if typeof(v) == TYPE_STRING else ""
	return code if code.length() >= 4 and code.length() <= 8 else ""


# Host helper: change the room's topic (lobby + next rounds) and tell everyone.
func set_topic(topic: String) -> void:
	room_topic = topic.strip_edges().left(40)
	if is_host():
		send({"t": "topic", "topic": room_topic})


# Host helper: start a round for everyone (and remember it locally).
func host_start_round(topic: String, round_no: int, mode := "") -> void:
	var pool := [Global.QuestionType.MCQ, Global.QuestionType.FILL_BLANK, Global.QuestionType.WORDLE,
		Global.QuestionType.WHACK, Global.QuestionType.WORD_LOCK, Global.QuestionType.KBC]
	room_topic = topic
	if mode.is_empty():
		mode = str(round_data.get("mode", "island"))
	round_data = {"t": "start", "seed": randi(), "qtype": pool.pick_random(), "topic": topic, "round": round_no, "mode": mode}
	round_riddle = {}
	round_hints = []
	send(round_data.duplicate())
