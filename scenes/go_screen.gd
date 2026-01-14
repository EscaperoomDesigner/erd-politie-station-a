extends Control

# GO GO GO screen shown after game ends
# Displays for 10 seconds then returns to setup screen

@onready var go_label: Label = %GoLabel
@onready var timer_label: Label = %TimerLabel
@onready var go_timer: Timer = %GoTimer

var countdown_duration: float = 10.0


func _ready():
	print("GoScreen: Initialized")
	# Get go screen time from config
	countdown_duration = ConfigManager.get_go_screen_time()
	print("GoScreen: Duration set to %d seconds" % countdown_duration)
	
	# Configure and start GOTimer
	if go_timer:
		go_timer.wait_time = countdown_duration
		go_timer.one_shot = true
		go_timer.timeout.connect(_return_to_setup)
		go_timer.start()
	
	# Connect to MQTTManager signals to listen for new game start
	if MQTTManager:
		MQTTManager.game_start_received.connect(_on_mqtt_start_received)
		print("GoScreen: Connected to MQTT start signal")
	else:
		print("GoScreen: ERROR - MQTTManager not found!")


func _process(_delta: float):
	# Update timer label with remaining time
	if go_timer and go_timer.time_left > 0 and timer_label:
		timer_label.text = "Volgende ronde begint over: %d" % ceil(go_timer.time_left)


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
	
	# Reset game manager
	GameManager.reset_game()
	
	# Reset questions so they can be used again and randomized
	QuestionManager.reset()
	
	# Change to game scene immediately
	get_tree().change_scene_to_file("uid://bo3qkm2gv7u7v")
