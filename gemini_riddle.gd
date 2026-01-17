extends Node
class_name GeminiRiddle

# ================= LLM CONFIG =================
const LLM_URL: String = "https://api.groq.com/openai/v1/chat/completions"

# ================= EASY PROGRAMMING FALLBACK RIDDLES =================
const FALLBACK_RIDDLES: Array[Dictionary] = [
	{
		"riddle": "I repeat a block of code until a condition becomes false. What am I?",
		"hints": ["Used for repetition", "Can be while or for", "Avoid infinite use", "Common control structure"],
		"solution": "Loop"
	},
	{
		"riddle": "I store a value that can change while the program runs. What am I?",
		"hints": ["Holds data", "Can be int or string", "Declared before use", "Changes over time"],
		"solution": "Variable"
	},
	{
		"riddle": "I compare two values and return true or false. What am I?",
		"hints": ["Used in conditions", "== is one example", "Returns boolean", "Checks equality"],
		"solution": "Operator"
	},
	{
		"riddle": "I group reusable code and can take inputs and return outputs. What am I?",
		"hints": ["Called many times", "Helps avoid repetition", "Has parameters", "Also called a method"],
		"solution": "Function"
	},
	{
		"riddle": "I decide which block of code runs based on a condition. What am I?",
		"hints": ["Uses true or false", "if / else", "Controls program flow", "Decision making"],
		"solution": "Condition"
	},
	{
		"riddle": "I hold multiple values under one name, accessed by an index. What am I?",
		"hints": ["Uses indices", "Ordered collection", "Starts at 0", "Common data structure"],
		"solution": "Array"
	}
]

@onready var http: HTTPRequest = $HTTPRequest

var api_key: String = ""
var LAMBDA_URL :String = ""

# ================= STORED DATA =================
var riddle_data: Dictionary = {
	"riddle": "",
	"hints": [],
	"solution": ""
}

signal riddle_generated(data: Dictionary)

# =================================================
func _ready() -> void:
	print("[GeminiRiddle] Initializing script...")
	var env: Dictionary = EnvLoader.load_env()
	api_key = env.get("LLM_API_KEY", "")
	LAMBDA_URL = env.get("LAMBDA_URL", "")
	
	print("[GeminiRiddle] Config Loaded. API Key Present: ", !api_key.is_empty(), " | Lambda URL Present: ", !LAMBDA_URL.is_empty())

	if not has_node("HTTPRequest"):
		print("[GeminiRiddle] Creating HTTPRequest node dynamically.")
		var new_http = HTTPRequest.new()
		add_child(new_http)
		http = new_http

	http.request_completed.connect(_on_response)

# =================================================
func generate_riddle() -> void:
	var difficulty = get_node("/root/Map/DifficultyRL").choose_difficulty()
	var topic = Global.selected_topic
	
	print("[GeminiRiddle] Starting generation. Topic: ", topic, " | Difficulty: ", difficulty)
	
	if api_key.is_empty():
		print("[GeminiRiddle] No API Key found. Routing to Lambda...")
		_call_lambda(difficulty, topic)
		return

	print("[GeminiRiddle] API Key found. Requesting from Groq LLM...")
	var prompt: String = """
Generate a riddle in STRICT JSON format only.
Structure:
{
  "riddle": "string",
  "hints": ["hint1", "hint2", "hint3", "hint4"],
  "solution": "string"
}
Rules:
- Topic: """ + topic + """
- Difficulty: """ + difficulty + """
- Valid JSON only, solution is one word.
"""

	var body := {
		"model": "llama-3.1-8b-instant",
		"messages": [{ "role": "user", "content": prompt }],
		"temperature": 0.5,
		"max_tokens": 256
	}

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key
	]

	var err := http.request(LLM_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

	if err != OK:
		push_error("[GeminiRiddle] HTTP Request Error: " + str(err))
		_use_fallback()

func _call_lambda(difficulty: String, topic: String) -> void:
	if LAMBDA_URL.is_empty():
		push_error("[GeminiRiddle] Lambda URL is missing! Cannot fetch riddle.")
		_use_fallback()
		return

	print("[GeminiRiddle] Sending POST to Lambda: ", LAMBDA_URL)
	var body := { "difficulty": difficulty, "topic": topic }
	var headers := PackedStringArray(["Content-Type: application/json"])

	var err := http.request(LAMBDA_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

	if err != OK:
		push_error("[GeminiRiddle] Lambda Connection Failed.")
		_use_fallback()

# =================================================
func _on_response(_r, code, _h, body):
	print("[GeminiRiddle] Response received. HTTP Code: ", code)
	
	if code != 200:
		push_warning("[GeminiRiddle] Server returned error code. Switching to fallback.")
		_use_fallback()
		return

	var text :String= body.get_string_from_utf8()
	var data = JSON.parse_string(text)

	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		push_error("[GeminiRiddle] Failed to parse JSON response.")
		_use_fallback()
		return

	# Logic for Lambda Response
	if data.has("riddle"):
		riddle_data = data
		_log_riddle_details(riddle_data)
		emit_signal("riddle_generated", riddle_data)
		return

	# Logic for Groq/OpenAI Response
	if data.has("choices"):
		var content :String = data["choices"][0]["message"]["content"]
		var parsed = JSON.parse_string(content)
		
		if typeof(parsed) == TYPE_DICTIONARY:
			riddle_data = parsed
			_log_riddle_details(riddle_data)
			emit_signal("riddle_generated", riddle_data)
		else:
			_use_fallback()
	else:
		_use_fallback()

# =================================================
func _use_fallback() -> void:
	print("[GeminiRiddle] ⚠️ ACTIVATING FALLBACK.")
	var random_entry = FALLBACK_RIDDLES.pick_random()
	riddle_data = random_entry.duplicate(true)
	
	_log_riddle_details(riddle_data) # <--- ADD THIS
	
	emit_signal("riddle_generated", riddle_data)


func _log_riddle_details(data: Dictionary) -> void:
	print("------------------------------------------")
	print("[GeminiRiddle] NEW RIDDLE GENERATED:")
	print("QUESTION: ", data.get("riddle", "N/A"))
	
	var hints = data.get("hints", [])
	for i in range(hints.size()):
		print("  HINT %d: %s" % [i + 1, hints[i]])
		
	print("ANSWER: ", data.get("solution", "N/A"))
	print("------------------------------------------")