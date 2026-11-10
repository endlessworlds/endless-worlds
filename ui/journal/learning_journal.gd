extends CanvasLayer
class_name LearningJournal

# Learning Journal page (pixel style): solved riddles and learned facts.

var _tabs: Array[Button] = []
var _list: VBoxContainer


func open() -> void:
	var v := PixelUI.page(self, "📖 Learning Journal", 820, close)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var j: Dictionary = Global.learning_journal
	for spec in [["✅ Solved riddles (%d)" % j.solved_riddles.size(), 0], ["💡 Facts learned (%d)" % j.concepts.size(), 1]]:
		var b := PixelUI.button(spec[0], _show.bind(spec[1]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_tabs.append(b)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_show(0)


func close() -> void:
	queue_free()


func _show(tab: int) -> void:
	for i in _tabs.size():
		_tabs[i].add_theme_stylebox_override("normal", PixelUI.box(PixelUI.FRAME_ACTIVE if i == tab else PixelUI.FRAME, 18, 4))
	for c in _list.get_children():
		c.queue_free()
	var entries: Array = Global.learning_journal.get("solved_riddles" if tab == 0 else "concepts", []).duplicate()
	entries.reverse()  # newest first
	if entries.is_empty():
		_list.add_child(PixelUI.label("\nNothing here yet.\nSolve a riddle to fill this page!", 28, PixelUI.MUTED))
		return
	for e in entries:
		var topic := str(e.get("topic", "")).capitalize()
		if tab == 0:
			_entry(str(e.get("question", "?")).replace("\n", " "), "Answer: " + str(e.get("answer", "?")).capitalize(), topic)
		else:
			_entry(str(e.get("definition", e.get("name", ""))), "", topic)


func _entry(text: String, answer: String, topic: String) -> void:
	var p := PixelUI.panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	p.add_child(box)
	var body := PixelUI.label(text, 24, PixelUI.CREAM, false)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(700, 0)
	box.add_child(body)
	var foot := HBoxContainer.new()
	box.add_child(foot)
	var a := PixelUI.label(answer, 24, PixelUI.GOLD, false)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(a)
	if not topic.is_empty():
		foot.add_child(PixelUI.label(topic, 20, PixelUI.MUTED))
	_list.add_child(p)
