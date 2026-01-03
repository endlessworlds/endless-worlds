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
	api_key = env.get("LLM_API_KEY", "")

	if not has_node("HTTPRequest"):
		var new_http = HTTPRequest.new()
		add_child(new_http)
		http = new_http

	http.request_completed.connect(_on_response)

# =================================================
func generate_riddle() -> void:
	if api_key.is_empty():
		print("⚠️ LLM API key missing — using fallback riddle")
		_use_fallback()
		return

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

	var body := {
		"model": "llama-3.1-8b-instant",
		"messages": [
			{ "role": "user", "content": prompt }
		],
		"temperature": 0.5,
		"max_tokens": 256,
		"top_p": 0.9
	}

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key
	]

	var err := http.request(
		LLM_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if err != OK:
		push_warning("❌ LLM request failed — using fallback")
		_use_fallback()

# =================================================
func _on_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("HTTP:", response_code)
	print("RAW RESPONSE:")
	print(body.get_string_from_utf8())

	if response_code != 200:
		print("❌ Non-200 response, fallback")
		_use_fallback()
		return

	var response_text: String = body.get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(response_text)

	if parsed.is_empty():
		print("❌ Failed to parse top-level JSON")
		_use_fallback()
		return

	# ✅ GROQ / OpenAI FORMAT
	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		print("❌ No choices in response")
		_use_fallback()
		return

	var message: Dictionary = choices[0].get("message", {})
	var content: String = str(message.get("content", ""))

	print("LLM CONTENT:")
	print(content)

	# content itself is JSON → parse again
	var riddle_var: Dictionary = JSON.parse_string(content)
	if riddle_var.is_empty():
		print("❌ Riddle JSON invalid")
		_use_fallback()
		return

	# ✅ SUCCESS
	riddle_data["riddle"] = str(riddle_var.get("riddle", ""))
	riddle_data["hints"] = riddle_var.get("hints", [])
	riddle_data["solution"] = str(riddle_var.get("solution", ""))

	print("✅ USING LLM RIDDLE")
	emit_signal("riddle_generated", riddle_data)

# =================================================
func _use_fallback() -> void:
	# Randomly pick one of the 6 technical riddles
	var random_entry = FALLBACK_RIDDLES.pick_random()
	riddle_data = random_entry.duplicate(true)
	emit_signal("riddle_generated", riddle_data)
