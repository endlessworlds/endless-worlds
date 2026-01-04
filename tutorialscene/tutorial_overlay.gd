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
	timer.start()

func close():
	timer.stop()
	video.stop()
	visible = false

func _show_slide(i: int):
	var slide = slides[i]

	video.stop()
	video.stream = load(slide["video"])
	video.play()

	text.text = slide["text"]

func _next():
	index = (index + 1) % slides.size()
	_show_slide(index)

func _prev():
	index = (index - 1 + slides.size()) % slides.size()
	_show_slide(index)
