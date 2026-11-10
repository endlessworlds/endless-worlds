extends CanvasLayer
class_name TutorialOverlay

@onready var video: VideoStreamPlayer = $Root/Panel/VBoxContainer/SlideArea/VideoPlayer
@onready var text: Label = $Root/Panel/VBoxContainer/SlideText
@onready var left_btn: Button = $Root/Panel/VBoxContainer/SlideArea/LeftArrow
@onready var right_btn: Button = $Root/Panel/VBoxContainer/SlideArea/RightArrow
@onready var close_btn: Button = $Root/Panel/VBoxContainer/CloseButton

const SLIDE_TIME := 15.0

var slides := [
	{ "video": "res://assets/tutorial/slide1.ogv", "text": "Type any topic or subject of your choice" },
	{ "video": "res://assets/tutorial/slide2.ogv", "text": "Click on the magnifying glass to show the question" },
	{ "video": "res://assets/tutorial/slide3.ogv", "text": "Collect Hint Bulbs by moving on them" },
	{ "video": "res://assets/tutorial/slide4.ogv", "text": "Hover on each lit bulb to show the hint" },
	{ "video": "res://assets/tutorial/slide5.ogv", "text": "Go near a well to open and type out the ANSWER and close" },
	{ "video": "res://assets/tutorial/slide6.ogv", "text": "Player can take damage . Have Fun Playing and Learning" }
]

var index := 0
var timer: Timer

func _ready():
	layer = 60  # above the home UI (2), HUD (2-3), multiplayer (15) and Bolt (20) layers
	visible = false

	left_btn.pressed.connect(_prev)
	right_btn.pressed.connect(_next)
	close_btn.pressed.connect(close)

	timer = Timer.new()
	timer.wait_time = SLIDE_TIME
	timer.timeout.connect(_next)
	add_child(timer)

	video.loop = true

func open():
	visible = true
	index = 0
	_show_slide(index)
	# No need to start timer here if it's the first slide 
	# and you want user to manual click, but keeping it per your original logic:
	timer.start()

func close():
	timer.stop()
	video.stop()
	queue_free()  # the tutorial button creates a fresh overlay on every open

func _show_slide(i: int):
	# Update index
	index = i
	var slide = slides[index]

	# Update Content
	video.stop()
	video.stream = load(slide["video"])
	video.play()
	text.text = slide["text"]

	# --- Handle Button Visibility ---
	# Hide left button if on first slide
	left_btn.visible = (index > 0)
	
	# Hide right button if on last slide
	right_btn.visible = (index < slides.size() - 1)
	
	# Restart timer for the new slide
	timer.start()

func _next():
	if index < slides.size() - 1:
		_show_slide(index + 1)
	else:
		timer.stop() # Stop auto-sliding at the end

func _prev():
	if index > 0:
		_show_slide(index - 1)
