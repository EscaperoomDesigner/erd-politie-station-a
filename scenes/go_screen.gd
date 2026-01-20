extends Control

# GO GO GO screen shown after game ends (matching Station-B finish state)
# Displays team name, timer (00:00), and score in topbar
# Auto-returns to setup screen after 60 seconds if no new game starts

@onready var go_label: Label = %GoLabel
@onready var timer_label: Label = %TimerLabel
@onready var go_timer: Timer = %GoTimer

var elapsed_time: float = 0.0
var timeout_duration: float = 60.0  # 60 seconds to match Station-B


func _ready():
	print("GoScreen: Initialized")
	
	# Show overlay topbar on GO screen with team/score/timer info
	if has_node("/root/Overlay"):
		get_node("/root/Overlay").set_topbar_visible(true)
	
	# Reset elapsed time
	elapsed_time = 0.0
	
	# Configure and start GOTimer (for MQTT start detection, not for timeout)
	if go_timer:
		# We'll handle timeout ourselves in _process
		go_timer.stop()
	
	# Connect to MQTTManager signals to listen for new game start
	if MQTTManager:
		MQTTManager.game_start_received.connect(_on_mqtt_start_received)
		print("GoScreen: Connected to MQTT start signal")
	else:
		print("GoScreen: ERROR - MQTTManager not found!")
	
	# Update timer display to show 00:00
	if timer_label:
		timer_label.text = "00:00"


func _process(delta: float):
	# Update elapsed time
	elapsed_time += delta
	
	# Check for timeout (60 seconds)
	if elapsed_time >= timeout_duration:
		print("GoScreen: 60 second timeout reached - returning to setup screen")
		_return_to_setup()


func _return_to_setup():
	"""Return to setup screen to wait for next game"""
	print("GoScreen: Returning to setup screen")
	
	# Disconnect from MQTT signal before changing scene
	if MQTTManager and MQTTManager.game_start_received.is_connected(_on_mqtt_start_received):
		MQTTManager.game_start_received.disconnect(_on_mqtt_start_received)
	
	# Reset game manager
	GameManager.reset_game()
	
	# Reset questions so they can be used again and randomized
	QuestionManager.reset()
	
	# Change to setup screen
	get_tree().change_scene_to_file("uid://c8l3yqs7hfmxr")


func _on_mqtt_start_received():
	"""Called when MQTT start message is received during go screen"""
	print("GoScreen: Start message received! Starting new game immediately...")
	
	# Stop the countdown timer
	if go_timer:
		go_timer.stop()
	
	# Disconnect from MQTT signal before changing scene
	if MQTTManager and MQTTManager.game_start_received.is_connected(_on_mqtt_start_received):
		MQTTManager.game_start_received.disconnect(_on_mqtt_start_received)
	
	# Reset questions so they can be used again and randomized
	QuestionManager.reset()
	
	# Note: Don't reset GameManager here - MQTT manager already configured it with the start data!
	# The MQTT handler already called start_game(), set_player_name(), set_score(), and start_timer()
	# Change to game scene immediately with the data already configured
	get_tree().change_scene_to_file("uid://bo3qkm2gv7u7v")
