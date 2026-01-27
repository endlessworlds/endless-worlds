extends Node
class_name GeminiRiddle

# ================= SCRAPING CONFIG =================
const DEBUG_FILE: String = "user://debug_scrape.txt"

# ================= FALLBACK RIDDLES =================
const FALLBACK_RIDDLES: Array[Dictionary] = [
	{
		"riddle": "I repeat a block of code until a condition becomes false. What am I?",
		"options": ["Loop", "Variable", "Function", "Array"],
		"solution": "Loop",
		"hints": ["Used for repetition", "Can be while or for", "Avoid infinite use", "Common control structure"],
		"fact_reference": "Loops are fundamental for iterating through data.",
		"source": "fallback"
	},
	{
		"riddle": "I store a value that can change while the program runs. What am I?",
		"options": ["Constant", "Variable", "Integer", "String"],
		"solution": "Variable",
		"hints": ["Holds data", "Can be int or string", "Declared before use", "Changes over time"],
		"fact_reference": "Variables allow programs to store and manipulate dynamic data.",
		"source": "fallback"
	}
]

@onready var http_search: HTTPRequest = HTTPRequest.new()
@onready var http_scrape: HTTPRequest = HTTPRequest.new()
@onready var http_groq: HTTPRequest = HTTPRequest.new()

# ================= STORED DATA =================
var riddle_data: Dictionary = {
	"riddle": "",
	"options": [],
	"solution": "",
	"hints": [],
	"fact_reference": "",
	"source": ""
}

var current_topic: String = ""
var current_difficulty: String = ""
var scrape_target_url: String = ""
var web_data: String = ""

signal riddle_generated(data: Dictionary)

# =================================================
func _ready() -> void:
	print("[GeminiRiddle] Initializing...")
	
	# Add HTTP nodes
	add_child(http_search)
	add_child(http_scrape)
	add_child(http_groq)
	
	# Connect signals
	http_search.request_completed.connect(_on_search_response)
	http_scrape.request_completed.connect(_on_scrape_response)
	http_groq.request_completed.connect(_on_groq_response)

# =================================================
func generate_riddle() -> void:
	# Fetching difficulty and topic from your existing Global/Map logic
	current_difficulty = "Easy" 
	if has_node("/root/Map/DifficultyRL"):
		current_difficulty = get_node("/root/Map/DifficultyRL").choose_difficulty()
		
	current_topic = Global.selected_topic if "selected_topic" in Global else "Programming"
	
	print("[GeminiRiddle] Requesting Riddle. Topic: %s | Difficulty: %s" % [current_topic, current_difficulty])
	
	# Start the scraping process
	_scrape_universal(current_topic)

# ================= UNIVERSAL SEARCH & SCRAPE =================
func _scrape_universal(topic: String) -> void:
	# Initialize debug file
	var file := FileAccess.open(DEBUG_FILE, FileAccess.WRITE)
	if file:
		file.store_string("--- SCRAPE LOG FOR TOPIC: %s ---\n\n" % topic)
		file.close()
	
	print("\n--- Searching Serper.dev for: %s ---" % topic)
	
	# Load API key from environment
	var env := EnvLoader.load_env("res://.env")
	var serper_api_key :Variant= env.get("SERPER_API_KEY", "")
	
	if serper_api_key.is_empty():
		push_error("[GeminiRiddle] SERPER_API_KEY not found in .env file")
		_handle_scrape_fallback("SERPER_API_KEY not found")
		return
	
	# Prepare Serper API request
	var search_body := {
		"q": "%s quiz questions and answers" % topic
	}
	
	var headers: PackedStringArray = [
		"X-API-KEY: %s" % serper_api_key,
		"Content-Type: application/json"
	]
	
	var err := http_search.request(
		"https://google.serper.dev/search",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(search_body)
	)
	
	if err != OK:
		push_error("[GeminiRiddle] Serper search request failed to start.")
		_handle_scrape_fallback("Search request failed to start")

# =================================================
func _on_search_response(_result, code, _headers, body) -> void:
	if code != 200:
		_handle_scrape_fallback("Search returned code %d" % code)
		return
	
	var search_json: String = body.get_string_from_utf8()
	var search_data: Variant = JSON.parse_string(search_json)
	
	if typeof(search_data) != TYPE_DICTIONARY:
		_handle_scrape_fallback("Invalid Serper API response")
		return
	
	# Get the first organic result link
	if not search_data.has("organic") or not search_data["organic"] is Array:
		_handle_scrape_fallback("No organic results in Serper response")
		return
	
	var organic_results: Array = search_data["organic"]
	if organic_results.size() == 0:
		_handle_scrape_fallback("Empty organic results")
		return
	
	# Find first non-PDF result
	scrape_target_url = ""
	for result in organic_results:
		if typeof(result) != TYPE_DICTIONARY or not result.has("link"):
			continue
		
		var url: String = result["link"]
		# Skip PDF files and other non-HTML formats
		if url.to_lower().ends_with(".pdf") or url.to_lower().ends_with(".doc") or url.to_lower().ends_with(".docx"):
			print("Skipping non-HTML file: %s" % url)
			continue
		
		scrape_target_url = url
		break
	
	if scrape_target_url.is_empty():
		_handle_scrape_fallback("No suitable HTML results found (all PDFs/docs)")
		return
	
	print("Scraping: %s" % scrape_target_url)
	
	# Append to debug file
	var file := FileAccess.open(DEBUG_FILE, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string("SOURCE URL: %s\n\n" % scrape_target_url)
		file.close()
	
	# Now scrape the target page
	var headers: PackedStringArray = [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
	]
	var err := http_scrape.request(scrape_target_url, headers, HTTPClient.METHOD_GET)
	
	if err != OK:
		_handle_scrape_fallback("Scrape request failed to start")

# =================================================
func _on_scrape_response(_result, code, _headers, body) -> void:
	if code != 200:
		_handle_scrape_fallback("Scrape returned code %d" % code)
		return
	
	var page_html: String = body.get_string_from_utf8()
	var cleaned_text: String = _extract_text_from_html(page_html)
	
	# Limit to 5000 characters
	web_data = cleaned_text.substr(0, 5000)
	
	# Append to debug file
	var file := FileAccess.open(DEBUG_FILE, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string(web_data)
		file.close()
	
	# Now call Groq API with the web data
	print("[GeminiRiddle] Scraped %d characters of text" % web_data.length())
	_call_groq_api(web_data)

# =================================================
func _extract_text_from_html(html: String) -> String:
	# Basic HTML tag removal and text extraction
	# This is a simplified version - removes common tags
	var text := html
	
	# Remove script, style, nav, footer tags and their content
	var tags_to_remove := ["script", "style", "nav", "footer", "iframe"]
	for tag in tags_to_remove:
		var pattern_start := "<%s" % tag
		var pattern_end := "</%s>" % tag
		var start_pos := 0
		
		while true:
			start_pos = text.find(pattern_start, start_pos)
			if start_pos == -1:
				break
			var end_pos := text.find(pattern_end, start_pos)
			if end_pos == -1:
				break
			text = text.substr(0, start_pos) + text.substr(end_pos + pattern_end.length())
	
	# Remove all remaining HTML tags
	var result := ""
	var in_tag := false
	
	for i in range(text.length()):
		var c := text[i]
		if c == '<':
			in_tag = true
		elif c == '>':
			in_tag = false
		elif not in_tag:
			result += c
	
	# Clean up whitespace
	result = result.replace("\n", " ").replace("\r", " ").replace("\t", " ")
	
	# Reduce multiple spaces to single space
	while result.find("  ") != -1:
		result = result.replace("  ", " ")
	
	return result.strip_edges()

# =================================================
func _handle_scrape_fallback(error_msg: String) -> void:
	var fallback_msg := "Scraping failed (%s). Falling back to LLM internal knowledge." % error_msg
	print("[GeminiRiddle] %s" % fallback_msg)
	
	# Append to debug file
	var file := FileAccess.open(DEBUG_FILE, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_string("\n\nFALLBACK TRIGGERED: %s" % fallback_msg)
		file.close()
	
	# Call Groq API without web data (null)
	_call_groq_api("")

# =================================================
func _call_groq_api(web_data_param: String) -> void:
	# Load API key from environment
	var env := EnvLoader.load_env("res://.env")
	var api_key :Variant= env.get("GROQ_API_KEY", "")
	
	if api_key.is_empty():
		push_error("[GeminiRiddle] GROQ_API_KEY not found in .env file")
		_use_fallback()
		return
	
	print("[GeminiRiddle] Calling Groq API...")
	
	# Dynamic Prompt logic based on whether web_data exists
	var source_context: String
	if web_data_param.is_empty():
		source_context = 'No web data available. Use your internal knowledge about "%s".' % current_topic
	else:
		source_context = "SOURCE MATERIAL FROM WEB:\n%s" % web_data_param
	
	var web_data_condition := "" if web_data_param.is_empty() else 'Base it on the SOURCE MATERIAL provided.'
	var source_type := "internal_knowledge" if web_data_param.is_empty() else "web"
	
	var prompt := """
	SYSTEM: You are a technical riddle creator. 
	CRITICAL: The "solution" MUST be exactly one of the items in the "options" array.
	%s

	TASK:
	1. Create a riddle about "%s". %s
	2. The "solution" MUST be a single word.
	3. Generate 4 "options" for the user to choose from.
	4. CRITICAL: The "solution" MUST be exactly one of the items in the "options" array.
	5. Difficulty: %s.
	6. Provide 4 hints exactly.
	7. Topic is given by user so dont make answer as topic itself
	8. insert a new line if the question is longer than 10 words
	9. keep question length less than 50 words
	10.keep the output logically correct
	
	OUTPUT STRICT JSON:
	{
	  "riddle": "string",
	  "options": ["opt1", "opt2", "opt3", "opt4"],
	  "solution": "string",
	  "hints": ["hint1", "hint2", "hint3", "hint4"],
	  "fact_reference": "Short sentence explaining the fact used",
	  "source": "%s"
	}""" % [source_context, current_topic, web_data_condition, current_difficulty, source_type]
	
	print("[GeminiRiddle] Prompt length: %d characters" % prompt.length())
	
	var request_body := {
		"model": "llama-3.1-8b-instant",
		"messages": [{"role": "user", "content": prompt}],
		"temperature": 0.5,
		"response_format": {"type": "json_object"}
	}
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key
	]
	
	var err := http_groq.request(
		"https://api.groq.com/openai/v1/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)
	
	if err != OK:
		push_error("[GeminiRiddle] Groq API request failed to start.")
		_use_fallback()

# =================================================
func _on_groq_response(_result, code, _headers, body) -> void:
	print("[GeminiRiddle] Groq Response received. Code: ", code)
	
	if code != 200:
		var error_text: String = body.get_string_from_utf8()
		push_warning("[GeminiRiddle] Groq API error (code %d): %s" % [code, error_text])
		_use_fallback()
		return
	
	var text: String = body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	
	if typeof(data) != TYPE_DICTIONARY or not data.has("choices"):
		push_error("[GeminiRiddle] Invalid Groq API response structure.")
		_use_fallback()
		return
	
	var content: String = data["choices"][0]["message"]["content"]
	
	# Sanitize to prevent JSON parse errors from control characters
	var sanitized_content: String = _remove_control_characters(content)
	var final_riddle: Variant = JSON.parse_string(sanitized_content)
	
	if typeof(final_riddle) == TYPE_DICTIONARY and final_riddle.has("riddle"):
		riddle_data = final_riddle
		
		# Append to debug file
		var file := FileAccess.open(DEBUG_FILE, FileAccess.READ_WRITE)
		if file:
			file.seek_end()
			file.store_string("\n\n--- LLM FINAL OUTPUT ---\n%s" % JSON.stringify(riddle_data, "\t"))
			file.close()
		
		print("Riddle generated via %s." % riddle_data.get("source", "unknown"))
		_log_riddle_details(riddle_data)
		emit_signal("riddle_generated", riddle_data)
	else:
		push_error("[GeminiRiddle] Received invalid JSON structure from LLM.")
		_use_fallback()

# =================================================
func _remove_control_characters(text: String) -> String:
	var result := ""
	for i in range(text.length()):
		var c := text[i]
		var code := c.unicode_at(0)
		# Remove control characters (0x00-0x1F and 0x7F-0x9F)
		if (code >= 0x20 and code < 0x7F) or code >= 0xA0:
			result += c
	return result

# =================================================
func _use_fallback() -> void:
	print("[GeminiRiddle] ⚠️ ACTIVATING FALLBACK.")
	riddle_data = FALLBACK_RIDDLES.pick_random().duplicate(true)
	_log_riddle_details(riddle_data)
	emit_signal("riddle_generated", riddle_data)

# =================================================
func _log_riddle_details(data: Dictionary) -> void:
	print("------------------------------------------")
	print("[GeminiRiddle] DATA SOURCE: ", data.get("source", "unknown"))
	print("QUESTION: ", data.get("riddle", "N/A"))
	print("OPTIONS: ", data.get("options", []))
	print("ANSWER: ", data.get("solution", "N/A"))
	print("FACT: ", data.get("fact_reference", "N/A"))
	print("------------------------------------------")
