extends Control

# Setup screen that waits for MQTT start message
# Also includes test button to manually trigger start

@onready var status_label: Label = %StatusLabel
@onready var waiting_label: Label = %WaitingLabel
@onready var test_button: Button = %TestButton
@onready var skip_button: Button = %SkipButton
@onready var connect_button: Button = %ConnectButton
@onready var connection_label: Label = %ConnectionLabel


var waiting_dots: int = 0
var dot_timer: float = 0.0


func _ready():
	print("SetupScreen: Initialized")
	
	# Connect to MQTTManager signals
	if MQTTManager:
		MQTTManager.game_start_received.connect(_on_mqtt_start_received)
		_update_connection_status()
	else:
		print("SetupScreen: ERROR - MQTTManager not found!")
	
	# Connect buttons
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_button_pressed)
	if connect_button:
		connect_button.pressed.connect(_on_connect_button_pressed)


func _process(delta: float):
	# Animate waiting dots
	dot_timer += delta
	if dot_timer >= 0.5:
		dot_timer = 0.0
		waiting_dots = (waiting_dots + 1) % 4
		_update_waiting_text()
	
	# Update connection status
	if MQTTManager:
		_update_connection_status()


func _update_waiting_text():
	if waiting_label:
		var dots = ".".repeat(waiting_dots)
		waiting_label.text = "Wachten op start signaal" + dots


func _update_connection_status():
	if connection_label and MQTTManager:
		if MQTTManager.mqtt_connected:
			connection_label.text = "MQTT: ✓ Verbonden (%s:%d)" % [MQTTManager.BROKER_IP, MQTTManager.BROKER_PORT]
			connection_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			connection_label.text = "MQTT: ✗ Niet verbonden (probeer: %s:%d)" % [MQTTManager.BROKER_IP, MQTTManager.BROKER_PORT]
			connection_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		
		# Enable test button only when connected
		if test_button:
			test_button.disabled = not MQTTManager.mqtt_connected
		
		# Show/hide connect button based on connection
		if connect_button:
			connect_button.visible = not MQTTManager.mqtt_connected


func _on_mqtt_start_received():
	"""Called when MQTT start message is received"""
	print("SetupScreen: Start message received! Transitioning to game...")
	
	# Change to game scene
	get_tree().change_scene_to_file("uid://bo3qkm2gv7u7v")


func _on_test_button_pressed():
	"""Test button to manually send MQTT start message"""
	print("SetupScreen: Test button pressed - sending start message")
	
	if MQTTManager and MQTTManager.mqtt_connected:
		# Send a test start message
		var test_payload = {
			"team": {
				"name": "Test Team",
				"score": 0
			},
			"time": ConfigManager.get_default_game_time()
		}
		var json_payload = JSON.stringify(test_payload)
		
		# Publish to the start topic
		MQTTManager.mqtt_client.publish(MQTTManager.topic_start, json_payload)
		print("SetupScreen: Test start message sent")
	else:
		print("SetupScreen: Cannot send test message - not connected to MQTT")


func _on_skip_button_pressed():
	"""Skip button to directly start the game without MQTT"""
	print("SetupScreen: Skip button pressed - starting game directly")
	
	# Set up GameManager with default values
	GameManager.set_player_name("Test Team")
	GameManager.set_score(0)
	GameManager.start_timer(ConfigManager.get_default_game_time())
	GameManager.start_game()
	
	# Change to game scene
	get_tree().change_scene_to_file("uid://bo3qkm2gv7u7v")


func _on_connect_button_pressed():
	"""Connect button to manually trigger MQTT connection"""
	print("SetupScreen: Connect button pressed - attempting MQTT connection")
	
	if MQTTManager:
		MQTTManager.connect_to_broker()
		connection_label.text = "MQTT: Verbinding maken..."
	else:
		print("SetupScreen: ERROR - MQTTManager not found!")
