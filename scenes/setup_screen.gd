extends Control

# Setup screen that waits for MQTT start message (matching Station-B waiting state)

@onready var status_label: Label = %StatusLabel
@onready var waiting_label: Label = %WaitingLabel
@onready var spinner_drawer: Control = %SpinnerDrawer
@onready var test_start_button: Button = %Button

# Spinner animation
var loading_angle: float = 0.0


func _ready():
	print("SetupScreen: Initialized")
	
	# Hide the overlay topbar on the setup screen
	if has_node("/root/Overlay"):
		get_node("/root/Overlay").set_topbar_visible(false)
	
	# Connect to MQTTManager signals
	if MQTTManager:
		MQTTManager.game_start_received.connect(_on_mqtt_start_received)
	else:
		print("SetupScreen: ERROR - MQTTManager not found!")

	# Connect test start button
	if test_start_button:
		test_start_button.pressed.connect(_on_test_start_pressed)
	
	# Connect spinner drawer's draw function
	if spinner_drawer:
		spinner_drawer.draw.connect(_draw_spinner)
	
	# Force initial update
	_update_connection_status()


func _process(delta: float):
	# Update loading spinner rotation (180 degrees per second)
	loading_angle += 180.0 * delta
	if loading_angle >= 360.0:
		loading_angle -= 360.0
	
	# Update connection status
	if MQTTManager:
		_update_connection_status()
	
	# Trigger redraw for spinner animation
	if spinner_drawer:
		spinner_drawer.queue_redraw()


func _update_connection_status():
	if not MQTTManager:
		return
	
	var is_connected = MQTTManager.mqtt_connected
	
	if status_label:
		if is_connected:
			status_label.text = "Station A - Verbonden"
		else:
			status_label.text = "Station A - Verbroken"
		status_label.modulate = Color.WHITE
	
	if waiting_label:
		if is_connected:
			waiting_label.text = "wachten op start signaal..."
		else:
			waiting_label.text = "verbinding maken..."
		waiting_label.visible = true
		waiting_label.modulate = Color.WHITE


func _draw_spinner():
	"""Draw the loading spinner (only when connected)"""
	if waiting_label and waiting_label.visible:
		# Get center position below waiting text
		var center_x = spinner_drawer.size.x / 2
		var center_y = spinner_drawer.size.y / 2 + 120
		
		# Spinner properties (matching Station-B)
		var radius = 40
		var thickness = 6
		var num_segments = 30
		
		var start_angle_rad = deg_to_rad(loading_angle)
		var end_angle_rad = deg_to_rad(loading_angle + 270)
		
		var points: PackedVector2Array = []
		for i in range(num_segments + 1):
			var t = float(i) / float(num_segments)
			var angle = start_angle_rad + (end_angle_rad - start_angle_rad) * t
			var x = center_x + radius * cos(angle)
			var y = center_y + radius * sin(angle)
			points.append(Vector2(x, y))
		
		if points.size() > 1:
			spinner_drawer.draw_polyline(points, Color.WHITE, thickness)


func _on_test_start_pressed():
	"""Manually trigger game start for testing"""
	print("SetupScreen: Test start button pressed")
	GameManager.reset_game()
	GameManager.set_player_name("Test Team")
	GameManager.start_timer(20.0)
	GameManager.start_game()
	if MQTTManager:
		MQTTManager.game_start_received.emit()


func _on_mqtt_start_received():
	"""Called when MQTT start message is received"""
	print("SetupScreen: Start message received! Transitioning to game...")
	
	# Change to game scene
	get_tree().change_scene_to_file("uid://bo3qkm2gv7u7v")
