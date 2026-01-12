extends Node2D

# Memory Matching Game
# Remember pattern positions and match tiles of the same pattern

# CONFIGURATION CONSTANTS
const GRID_3X3_SIZE = 3  # Grid size for 3x3 mode
const GRID_4X4_SIZE = 4  # Grid size for 4x4 mode
const NUM_PATTERNS_3X3 = 3  # Number of different patterns in 3x3 mode
const NUM_PATTERNS_4X4 = 4  # Number of different patterns in 4x4 mode
const POINTS_3X3 = 100  # Points awarded for completing 3x3 grid
const POINTS_4X4 = 200  # Points awarded for completing 4x4 grid
const TIME_BONUS_MULTIPLIER = 5  # Multiplier for time bonus points
const NUM_3X3_ROUNDS = 2  # Number of 3x3 rounds before switching to 4x4
const FAILURES_BEFORE_DOWNGRADE = 3  # Number of failures in 4x4 before downgrading to 3x3

@onready var grid_container = %GridContainer

var is_game_active: bool = false
var tiles: Array = []  # Array of tile buttons
var tile_patterns: Array = []  # Pattern ID for each tile (0-3)
var tiles_face_up: bool = true  # Are tiles showing patterns?
var current_matching_pattern: int = -1  # Which pattern we're currently matching (-1 = none yet)
var matched_tiles_count: int = 0  # How many tiles of current pattern matched
var completed_patterns: Array = []  # Which patterns have been fully matched
var is_3x3_mode: bool = true  # Start with 3x3 grid
var completions_3x3: int = 0  # Track consecutive successful completions of 3x3
var failures_4x4: int = 0  # Track failures on 4x4 mode
var tiles_per_pattern: int = 3  # Number of tiles per pattern (3 for 3x3, 4 for 4x4)

# Textures set in editor
@export var hidden_texture: Texture  # Texture for card back (when flipped)
@export var pattern_texture_1: Texture
@export var pattern_texture_2: Texture
@export var pattern_texture_3: Texture
@export var pattern_texture_4: Texture

var pattern_textures: Array = []
var rounded_corner_material: ShaderMaterial  # Will be set from first TextureRect


func _ready():
	# Build pattern textures array from exported textures
	pattern_textures = [pattern_texture_1, pattern_texture_2, pattern_texture_3, pattern_texture_4]
	
	# Connect to GameManager's game_ended signal
	GameManager.game_ended.connect(_on_game_end)
	
	# Get all tile panels from the grid (should be 16 panels)
	for child in grid_container.get_children():
		if child is Panel:
			tiles.append(child)
			child.gui_input.connect(_on_tile_gui_input.bind(tiles.size() - 1))
			# Set pivot to center for scaling animation
			child.pivot_offset = child.size / 2.0
			
			# Set rounded corners on panel background
			var style_box = StyleBoxFlat.new()
			style_box.corner_radius_top_left = 16
			style_box.corner_radius_top_right = 16
			style_box.corner_radius_bottom_left = 16
			style_box.corner_radius_bottom_right = 16
			style_box.bg_color = Color.WHITE
			child.add_theme_stylebox_override("panel", style_box)
			
			# Get shader material from first TextureRect and apply to all
			var texture_rect = child.get_node("TextureRect")
			if texture_rect:
				if rounded_corner_material == null and texture_rect.material:
					# Save the material from the first TextureRect
					rounded_corner_material = texture_rect.material
				elif rounded_corner_material:
					# Apply saved material to other TextureRects
					texture_rect.material = rounded_corner_material
	
	# Verify we have exactly 16 tiles
	if tiles.size() != 16:
		push_error("Memory game needs exactly 16 tiles in the grid!")
	
	# Start game automatically in 4x4 mode
	is_3x3_mode = false
	tiles_per_pattern = GRID_4X4_SIZE
	grid_container.columns = GRID_4X4_SIZE
	grid_container.custom_minimum_size = Vector2(885, 885)
	
	# Generate and show initial 4x4 layout
	generate_new_layout()
	
	# Start the game
	_on_game_start()


func _on_game_start():
	"""Game start logic"""
	is_game_active = true
	# Don't reset score - continue from question round
	
	tiles_face_up = true
	current_matching_pattern = -1
	matched_tiles_count = 0
	completed_patterns.clear()
	is_3x3_mode = true
	completions_3x3 = 0
	failures_4x4 = 0
	tiles_per_pattern = 3
	
	# Set grid to 3x3 and adjust size for centering
	grid_container.columns = GRID_3X3_SIZE
	grid_container.custom_minimum_size = Vector2(660, 660)
	
	# Enable only the first tiles for 3x3 mode
	var tiles_needed = GRID_3X3_SIZE * GRID_3X3_SIZE
	for i in range(tiles.size()):
		if i < tiles_needed:
			tiles[i].mouse_filter = Control.MOUSE_FILTER_STOP
			tiles[i].visible = true
		else:
			tiles[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
			tiles[i].visible = false
	
	# Generate initial layout
	generate_new_layout()


func _on_game_end():
	"""Game end logic"""
	is_game_active = false
	
	# Disable all tiles
	for tile in tiles:
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Award time bonus based on GameManager's remaining time
	var time_remaining = int(GameManager.time_remaining)
	var time_bonus = time_remaining * TIME_BONUS_MULTIPLIER
	if time_bonus > 0:
		GameManager.add_score(time_bonus)
	
	# Go to GO screen (GameManager.end_game() is already called by GameManager itself)
	get_tree().change_scene_to_file("res://scenes/go_screen.tscn")


func _on_game_reset():
	"""Game reset logic - just stops the game without resetting score"""
	is_game_active = false
	
	tiles_face_up = false
	current_matching_pattern = -1
	matched_tiles_count = 0
	completed_patterns.clear()
	is_3x3_mode = true
	completions_3x3 = 0
	failures_4x4 = 0
	tiles_per_pattern = GRID_3X3_SIZE
	
	# Set grid back to 3x3 and adjust size for centering
	grid_container.columns = GRID_3X3_SIZE
	grid_container.custom_minimum_size = Vector2(660, 660)
	
	# Disable and clear all tiles
	var tiles_3x3 = GRID_3X3_SIZE * GRID_3X3_SIZE
	for i in range(tiles.size()):
		var tile = tiles[i]
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture_rect = tile.get_node("TextureRect")
		var label = tile.get_node("Label")
		texture_rect.texture = null
		texture_rect.modulate = Color.WHITE
		label.text = ""
		# Hide tiles beyond 3x3 grid for 3x3 mode
		if i >= tiles_3x3:
			tile.visible = false
		else:
			tile.visible = true


func generate_new_layout():
	"""Generate a new random layout of patterns"""
	tile_patterns.clear()
	
	if is_3x3_mode:
		# 3x3 mode: configurable patterns and grid size
		var tiles_needed = GRID_3X3_SIZE * GRID_3X3_SIZE
		for pattern_id in range(NUM_PATTERNS_3X3):
			for i in range(GRID_3X3_SIZE):
				tile_patterns.append(pattern_id)
		
		# Shuffle the patterns
		tile_patterns.shuffle()
		
		# Show patterns for first tiles_needed tiles only
		for i in range(tiles_needed):
			var pattern_id = tile_patterns[i]
			var texture_rect = tiles[i].get_node("TextureRect")
			var label = tiles[i].get_node("Label")
			texture_rect.texture = pattern_textures[pattern_id]
			label.text = ""
			tiles[i].mouse_filter = Control.MOUSE_FILTER_STOP
			tiles[i].visible = true
		
		# Hide remaining tiles
		for i in range(tiles_needed, tiles.size()):
			tiles[i].visible = false
			tiles[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		# 4x4 mode: configurable patterns and grid size
		for pattern_id in range(NUM_PATTERNS_4X4):
			for i in range(GRID_4X4_SIZE):
				tile_patterns.append(pattern_id)
		
		# Shuffle the patterns
		tile_patterns.shuffle()
		
		# Show all patterns face up and re-enable all tiles
		for i in range(tiles.size()):
			var pattern_id = tile_patterns[i]
			var texture_rect = tiles[i].get_node("TextureRect")
			var label = tiles[i].get_node("Label")
			texture_rect.texture = pattern_textures[pattern_id]
			label.text = ""
			tiles[i].mouse_filter = Control.MOUSE_FILTER_STOP
			tiles[i].visible = true
	
	tiles_face_up = true


func flip_tiles_face_down():
	"""Flip all tiles face down"""
	for tile in tiles:
		var texture_rect = tile.get_node("TextureRect")
		var label = tile.get_node("Label")
		texture_rect.texture = hidden_texture
		texture_rect.modulate = Color.WHITE
		label.text = ""
	
	tiles_face_up = false


func _on_tile_gui_input(event: InputEvent, tile_index: int):
	"""Called when a tile receives input"""
	# Only respond to mouse button press
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	
	# Play click sound
	SfxManager.play_click()
	
	# Animate tile press
	animate_tile_press(tiles[tile_index])
	
	var clicked_pattern = tile_patterns[tile_index]
	
	# First tile press starts the matching by flipping tiles down
	if tiles_face_up:
		flip_tiles_face_down()
		# Immediately reveal the clicked tile and start tracking
		current_matching_pattern = clicked_pattern
		matched_tiles_count = 1
		reveal_tile(tile_index)
		return
	
	# If this is the first tile clicked in a matching sequence
	if current_matching_pattern == -1:
		current_matching_pattern = clicked_pattern
		matched_tiles_count = 1
		reveal_tile(tile_index)
	
	# If clicking the same pattern we're currently matching
	elif clicked_pattern == current_matching_pattern:
		matched_tiles_count += 1
		reveal_tile(tile_index)
		
		# Check if we've matched all tiles of this pattern (3 for 3x3, 4 for 4x4)
		if matched_tiles_count == tiles_per_pattern:
			pattern_completed()
	
	# If clicking a different pattern - RESET!
	else:
		SfxManager.play_wrong_memory()  # Play wrong sound
		# No point penalty - time loss is the penalty
		flash_correct_pattern_then_reset()


func reveal_tile(tile_index: int):
	"""Reveal a single tile"""
	var pattern_id = tile_patterns[tile_index]
	var texture_rect = tiles[tile_index].get_node("TextureRect")
	var label = tiles[tile_index].get_node("Label")
	texture_rect.texture = pattern_textures[pattern_id]
	label.text = ""
	tiles[tile_index].mouse_filter = Control.MOUSE_FILTER_IGNORE  # Can't click again


func animate_tile_press(tile: Panel):
	"""Animate tile press with scale effect"""
	# Create a tween for smooth animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Scale down to 0.85 (centered)
	tween.tween_property(tile, "scale", Vector2(0.85, 0.85), 0.1)
	# Scale back up to 1.0
	tween.tween_property(tile, "scale", Vector2(1.0, 1.0), 0.15)


func pattern_completed():
	"""Called when a pattern is fully matched"""
	completed_patterns.append(current_matching_pattern)
	
	var num_patterns = NUM_PATTERNS_3X3 if is_3x3_mode else NUM_PATTERNS_4X4
	
	# Check if all patterns are completed
	if completed_patterns.size() == num_patterns:
		# Award points for completion
		if is_3x3_mode:
			SfxManager.play_success()  # Play success sound
			GameManager.add_score(POINTS_3X3)
			completions_3x3 += 1
			print("3x3 completion count: ", completions_3x3)
			
			# After configured number of 3x3 rounds, switch to 4x4
			if completions_3x3 >= NUM_3X3_ROUNDS:
				await get_tree().create_timer(0.5).timeout
				# Reset completions counter for next cycle
				completions_3x3 = 0
				switch_to_4x4()
				return
			else:
				# Continue with another 3x3 round
				await get_tree().create_timer(0.5).timeout
				reset_to_face_up()
				return
		else:
			SfxManager.play_success()  # Play success sound
			GameManager.add_score(POINTS_4X4)
			# Reset failure counter on successful 4x4 completion
			failures_4x4 = 0
			print("4x4 completed! Failure counter reset.")
			# Continue playing 4x4 until time runs out
			await get_tree().create_timer(0.5).timeout
			reset_to_face_up()
			return
	
	# Reset for next pattern
	current_matching_pattern = -1
	matched_tiles_count = 0


func flash_correct_pattern_then_reset():
	"""Flash ALL patterns for 1 second, then reset"""
	# Disable all tiles first
	for tile in tiles:
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Track failure based on mode
	var will_downgrade = false
	if is_3x3_mode:
		# In 3x3 mode, failure resets success counter
		completions_3x3 = 0
		print("3x3 failure - success counter reset to 0")
	else:
		# In 4x4 mode, track failures for downgrade
		failures_4x4 += 1
		print("4x4 failure count: ", failures_4x4)
		
		# Check if we need to downgrade back to 3x3
		if failures_4x4 >= FAILURES_BEFORE_DOWNGRADE:
			print("Too many 4x4 failures, downgrading to 3x3")
			will_downgrade = true
	
	# Show ALL tiles face up (only the ones that are in use)
	var num_tiles = (GRID_3X3_SIZE * GRID_3X3_SIZE) if is_3x3_mode else (GRID_4X4_SIZE * GRID_4X4_SIZE)
	for i in range(num_tiles):
		var pattern_id = tile_patterns[i]
		var texture_rect = tiles[i].get_node("TextureRect")
		var label = tiles[i].get_node("Label")
		texture_rect.texture = pattern_textures[pattern_id]
		label.text = ""
	
	# Wait to show all patterns
	await get_tree().create_timer(0.5).timeout
	
	if is_game_active:
		if will_downgrade:
			switch_to_3x3()
		else:
			reset_to_face_up()


func reset_to_face_up():
	"""Reset game - show all patterns again in new positions"""
	# Disable tiles briefly
	for tile in tiles:
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Wait a moment
	await get_tree().create_timer(0.5).timeout
	
	if is_game_active:
		# Reset matching state
		current_matching_pattern = -1
		matched_tiles_count = 0
		completed_patterns.clear()  # Clear completed patterns on reset!
		
		# Generate new layout (this will re-enable tiles)
		generate_new_layout()


func switch_to_4x4():
	"""Switch from 3x3 mode to 4x4 mode"""
	is_3x3_mode = false
	tiles_per_pattern = GRID_4X4_SIZE
	grid_container.columns = GRID_4X4_SIZE
	# Adjust custom_minimum_size for 4x4: 4 tiles * 210 + 3 gaps * 15 = 885
	grid_container.custom_minimum_size = Vector2(885, 885)
	
	# Show all 16 tiles
	for tile in tiles:
		tile.visible = true
	
	# Reset matching state
	current_matching_pattern = -1
	matched_tiles_count = 0
	completed_patterns.clear()
	# Reset failure counter when starting 4x4
	failures_4x4 = 0
	
	print("Switched to 4x4 mode")
	
	# Generate new 4x4 layout
	generate_new_layout()


func switch_to_3x3():
	"""Switch from 4x4 mode back to 3x3 mode"""
	is_3x3_mode = true
	tiles_per_pattern = GRID_3X3_SIZE
	grid_container.columns = GRID_3X3_SIZE
	# Adjust custom_minimum_size for 3x3: 3 tiles * 210 + 2 gaps * 15 = 660
	grid_container.custom_minimum_size = Vector2(660, 660)
	
	# Hide tiles beyond 3x3
	var tiles_3x3 = GRID_3X3_SIZE * GRID_3X3_SIZE
	for i in range(tiles.size()):
		if i < tiles_3x3:
			tiles[i].visible = true
		else:
			tiles[i].visible = false
	
	# Reset matching state
	current_matching_pattern = -1
	matched_tiles_count = 0
	completed_patterns.clear()
	# Reset both counters
	completions_3x3 = 0
	failures_4x4 = 0
	
	print("Switched to 3x3 mode")
	
	# Generate new 3x3 layout
	generate_new_layout()
