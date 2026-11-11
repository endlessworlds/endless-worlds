extends Node2D
class_name Treasure

# A small treasure chest on the riddle island: walk into it for bonus score and a few
# coins for the Survival armory. Purely a bonus (each player has their own chests).
#   Treasure.scatter(map, tilemap, player, 4)

const SCORE := 10
const COINS := 5

var map: Node
var player: Node2D
var _t := randf() * 6.0
var _opened := false


static func scatter(p_map: Node2D, tilemap: TileMapLayer, p_player: Node2D, count: int) -> void:
	var land: Array[Vector2i] = []
	for cell in tilemap.get_used_cells():
		if tilemap.get_cell_atlas_coords(cell) in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:   # grass, dirt, sand
			land.append(cell)
	if land.is_empty():
		return
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < count and tries < 400:
		tries += 1
		var at: Vector2 = tilemap.map_to_local(land.pick_random())
		if at.distance_to(p_map.to_local(p_player.global_position)) < 220.0:
			continue
		if placed.any(func(q): return q.distance_to(at) < 260.0):
			continue
		placed.append(at)
		var t := Treasure.new()
		t.map = p_map
		t.player = p_player
		t.position = at
		p_map.add_child(t)
		t.z_index = int(t.global_position.y / 4.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _opened or not is_instance_valid(player):
		return
	if player.global_position.distance_to(global_position) < 34.0:
		_opened = true
		map.add_score(SCORE)
		SurvivalArsenal.add_coins(COINS)
		Global.save_game()
		var l := PixelUI.label("+%d score  +%d coins" % [SCORE, COINS], 22, PixelUI.GOLD)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 5)
		l.scale = Vector2(0.5, 0.5)
		l.position = Vector2(-45, -26)
		l.size = Vector2(180, 24)
		l.z_index = 50
		add_child(l)
		var tw := create_tween().set_parallel()
		tw.tween_property(l, "position:y", -44.0, 1.2)
		tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.4)
		tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var wood := Color(0.55, 0.33, 0.15)
	var dark := Color(0.32, 0.18, 0.08)
	var gold := Color(1.0, 0.8, 0.25)
	draw_rect(Rect2(-7, -8, 14, 9), dark)
	draw_rect(Rect2(-6, -7, 12, 7), wood)
	if _opened:
		draw_rect(Rect2(-7, -13, 14, 4), dark)           # lid thrown back
		draw_rect(Rect2(-5, -8, 10, 2), gold)            # treasure inside
	else:
		draw_rect(Rect2(-7, -11, 14, 4), dark)
		draw_rect(Rect2(-6, -10, 12, 2), wood)
		draw_rect(Rect2(-1, -8, 2, 3), gold)             # lock
		# a sparkle so it can be spotted from a distance
		var k := absf(sin(_t * 2.5))
		var c := Vector2(5, -13)
		draw_line(c + Vector2(-3, 0) * k, c + Vector2(3, 0) * k, Color(1, 1, 0.8, k), 1.0)
		draw_line(c + Vector2(0, -3) * k, c + Vector2(0, 3) * k, Color(1, 1, 0.8, k), 1.0)
