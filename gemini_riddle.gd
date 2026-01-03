extends Node
class_name GeminiRiddle

# ================= GEMINI CONFIG =================
const GEMINI_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

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

# ================= STORED DATA =================
var riddle_data: Dictionary = {
	"riddle": "",
	"hints": [],
	"solution": ""
}

signal riddle_generated(data: Dictionary)

# =================================================
func _ready() -> void:
	var env: Dictionary = EnvLoader.load_env()
	api_key = env.get("GEMINI_API_KEY", "")

	if not has_node("HTTPRequest"):
		var new_http = HTTPRequest.new()
		add_child(new_http)
		http = new_http

	http.request_completed.connect(_on_response)

# =================================================
func generate_riddle() -> void:
	if api_key.is_empty():
		print("⚠️ Gemini API key missing — using fallback riddle")
		_use_fallback()
		return

	# 🔥 GEMINI MODE
	var prompt: String = """
Generate a riddle in STRICT JSON format only.

Structure:
{
  "riddle": "string",
  "hints": ["hint1", "hint2", "hint3", "hint4"],
  "solution": "string"
}

Rules:
- Technical question
- No markdown
- No explanation
- Valid JSON only
- solution should be a single word
"""

	var body: Dictionary = {
		"contents": [{"parts": [{"text": prompt}]}]
	}

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"x-goog-api-key: %s" % api_key
	]

	var err: int = http.request(GEMINI_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

	if err != OK:
		push_warning("❌ Gemini request failed — using fallback")
		_use_fallback()

# =================================================
func _on_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		_use_fallback()
		return

	var response_text: String = body.get_string_from_utf8()
	var parsed_var: Variant = JSON.parse_string(response_text)
	
	if parsed_var == null:
		_use_fallback()
		return

	var candidates: Array = parsed_var.get("candidates", [])
	if candidates.is_empty():
		_use_fallback()
		return

	var text_output: String = str(candidates[0].get("content", {}).get("parts", [{}])[0].get("text", ""))
	var riddle_var: Variant = JSON.parse_string(text_output)
	
	if riddle_var == null:
		_use_fallback()
		return

	riddle_data["riddle"] = str(riddle_var.get("riddle", ""))
	riddle_data["hints"] = riddle_var.get("hints", [])
	riddle_data["solution"] = str(riddle_var.get("solution", ""))

	emit_signal("riddle_generated", riddle_data)

# =================================================
func _use_fallback() -> void:
	# Randomly pick one of the 6 technical riddles
	var random_entry = FALLBACK_RIDDLES.pick_random()
	riddle_data = random_entry.duplicate(true)
	emit_signal("riddle_generated", riddle_data)
