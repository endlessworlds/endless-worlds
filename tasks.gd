extends Node2D
class_name Tasks

@export var hint_pickup_scene: PackedScene
var total_hints: int = 0
var collected_hints: int = 0

signal hint_collected
signal all_hints_collected

func spawn_hints(count: int, tilemap: TileMapLayer, water_border: int, width: int, height: int) -> void:
	if hint_pickup_scene == null:
		push_error("Tasks.spawn_hints: hint_pickup_scene is not assigned!")
		return

	# FORCE 6 HINTS to make the game easier
	total_hints = 6 
	collected_hints = 0
	
	var WATER_COORDS = Vector2i(3, 1)
	var placed_positions: Array[Vector2i] = [] # To keep track of where we put hints
	var min_distance = 15 # Minimum tiles between hints
	
	var placed = 0
	var attempts = 0
	
	while placed < total_hints and attempts < 3000:
		attempts += 1
		
		var tx = randi_range(water_border, width - water_border)
		var ty = randi_range(water_border, height - water_border)
		var tile_pos = Vector2i(tx, ty)
		
		# 1. Check if it's on land
		var current_tile = tilemap.get_cell_atlas_coords(tile_pos)
		if current_tile != WATER_COORDS and current_tile != Vector2i(-1, -1):
			
			# 2. Check if it's too close to another hint
			var too_close = false
			for p in placed_positions:
				if tile_pos.distance_to(p) < min_distance:
					too_close = true
					break
			
			if not too_close:
				var pickup = hint_pickup_scene.instantiate()
				add_child(pickup)
				
				pickup.position = tilemap.map_to_local(tile_pos)
				placed_positions.append(tile_pos)
				
				if pickup.has_signal("collected"):
					pickup.collected.connect(_on_hint_collected)
				
				placed += 1

func _on_hint_collected() -> void:
	collected_hints += 1
	emit_signal("hint_collected")
	if collected_hints >= total_hints:
		emit_signal("all_hints_collected")
