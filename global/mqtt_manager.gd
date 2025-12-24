extends Node

# MQTT Manager - Handles MQTT connections for drug lab station system
# Manages game start, finish, timer updates, and leaderboard
# Configuration is loaded from ConfigManager (station_config.json)

# Signals
signal game_start_received()

# Configuration - loaded from ConfigManager
var BROKER_IP: String = "192.168.1.2"
var BROKER_PORT: int = 1883
var USE_WEBSOCKET: bool = false
var DEVICE_TYPE: String = "station"
var DEVICE_ID: String = "station-a"
var AUTO_CONNECT: bool = true

# MQTT Topics - Dynamically constructed based on device configuration
var topic_start: String = ""
var topic_finish: String = ""
var topic_timeleft: String = ""
const TOPIC_SCORES: String = "erd/drugslab/scores"
const TOPIC_IR_SENSOR: String = "sensor/ir/beam"  # IR break beam sensor

# State
var current_team_name: String = ""
var is_session_active: bool = false
var mqtt_connected: bool = false
var station_id: String = ""  # Extracted station ID (e.g., "station-a")

# MQTT client instance (using the real library)
var mqtt_client: Node = null


func _ready():
	# Load configuration from ConfigManager
	_load_config_from_manager()
	
	# Initialize device configuration
	_initialize_device_config()
	
	# Load the MQTT client scene from addons
	var mqtt_scene = load("res://addons/mqtt/mqtt.tscn")
	mqtt_client = mqtt_scene.instantiate()
	add_child(mqtt_client)
	
	# Configure client
	mqtt_client.client_id = "godot_%s_%d" % [DEVICE_ID, randi()]
	mqtt_client.verbose_level = 2  # 0=quiet, 1=connections, 2=all messages
	
	# Connect signals
	mqtt_client.broker_connected.connect(_on_mqtt_connected)
	mqtt_client.broker_disconnected.connect(_on_mqtt_disconnected)
	mqtt_client.received_message.connect(_on_mqtt_message_received)
	mqtt_client.broker_connection_failed.connect(_on_mqtt_error)
	
	print("MQTTManager initialized")
	print("  Device Type: %s" % DEVICE_TYPE)
	print("  Device ID: %s" % DEVICE_ID)
	if DEVICE_TYPE == "station":
		print("  Station ID: %s" % station_id)
	
	# Auto-connect if enabled
	if AUTO_CONNECT:
		connect_to_broker()


func _load_config_from_manager():
	"""Load configuration from ConfigManager singleton"""
	if ConfigManager:
		BROKER_IP = ConfigManager.get_mqtt_broker_ip()
		BROKER_PORT = ConfigManager.get_mqtt_broker_port()
		AUTO_CONNECT = ConfigManager.get_mqtt_auto_connect()
		USE_WEBSOCKET = ConfigManager.get_mqtt_use_websocket()
		DEVICE_TYPE = ConfigManager.get_device_type()
		DEVICE_ID = ConfigManager.get_device_id()
		print("MQTTManager: Loaded config from ConfigManager")
	else:
		print("MQTTManager: ConfigManager not available, using defaults")


func _initialize_device_config():
	"""Initialize topics and configuration based on device type"""
	if DEVICE_TYPE == "station":
		# For station devices, DEVICE_ID should be station-a, station-b, etc.
		station_id = DEVICE_ID
		topic_start = "erd/drugslab/%s/start" % station_id
		topic_finish = "erd/drugslab/%s/finish" % station_id
		topic_timeleft = "erd/drugslab/%s/timeleft" % station_id
	elif DEVICE_TYPE == "highscore":
		# For highscore displays, extract station from device ID if applicable
		# e.g., "highscore-station-a" -> subscribe to station-a topics
		if "station-a" in DEVICE_ID:
			station_id = "station-a"
		elif "station-b" in DEVICE_ID:
			station_id = "station-b"
		elif "station-c" in DEVICE_ID:
			station_id = "station-c"
		elif "station-d" in DEVICE_ID:
			station_id = "station-d"
		else:
			# For generic highscore displays (end, outside), don't subscribe to station topics
			station_id = ""
		
		# Highscore displays only listen, they don't need finish topic
		if station_id != "":
			topic_start = "erd/drugslab/%s/start" % station_id
			topic_timeleft = "erd/drugslab/%s/timeleft" % station_id
			topic_finish = "erd/drugslab/%s/finish" % station_id
	else:
		print("ERROR: Unknown DEVICE_TYPE: %s" % DEVICE_TYPE)


func connect_to_broker(custom_ip: String = "", custom_port: int = 0):
	"""Connect to the MQTT broker"""
	# Check if already connected or connecting
	if mqtt_client and mqtt_client.brokerconnectmode != 0:  # BCM_NOCONNECTION = 0
		print("MQTTManager: Already connecting or connected (state: %d)" % mqtt_client.brokerconnectmode)
		# If already connected, we're done
		if mqtt_connected:
			print("MQTTManager: Already connected!")
			return
		# If connecting, let it finish
		print("MQTTManager: Connection attempt already in progress...")
		return
	
	var ip = custom_ip if custom_ip != "" else BROKER_IP
	var port = custom_port if custom_port != 0 else BROKER_PORT
	
	# Build broker URL based on connection type
	var broker_url = ""
	if USE_WEBSOCKET:
		broker_url = "ws://%s:%d" % [ip, port]
	else:
		broker_url = "tcp://%s:%d" % [ip, port]
	
	print("MQTTManager: Connecting to %s" % broker_url)
	mqtt_client.connect_to_broker(broker_url)


func disconnect_from_broker():
	"""Disconnect from the MQTT broker"""
	print("MQTTManager: Disconnecting from broker")
	mqtt_client.disconnect_from_server()


func _on_mqtt_connected():
	"""Called when successfully connected to broker"""
	mqtt_connected = true
	print("MQTTManager: Connected to MQTT broker")
	print("  Client ID: %s" % mqtt_client.client_id)
	
	# Subscribe based on device type
	print("MQTTManager: Subscribing to topics...")
	
	# All devices subscribe to scores
	mqtt_client.subscribe(TOPIC_SCORES)
	print("  ✓ %s" % TOPIC_SCORES)
	
	# Station-specific subscriptions
	if station_id != "":
		mqtt_client.subscribe(topic_start)
		print("  ✓ %s" % topic_start)
		
		mqtt_client.subscribe(topic_timeleft)
		print("  ✓ %s" % topic_timeleft)
		
		# Only station devices (not highscore displays) need finish subscription for echo/confirmation
		if DEVICE_TYPE == "station":
			mqtt_client.subscribe(topic_finish)
			print("  ✓ %s (echo)" % topic_finish)
	
	# Only station devices with sensors subscribe to IR sensor topic
	if DEVICE_TYPE == "station":
		mqtt_client.subscribe(TOPIC_IR_SENSOR)
		print("  ✓ %s" % TOPIC_IR_SENSOR)
	
	print("MQTTManager: Subscription complete")


func _on_mqtt_disconnected():
	"""Called when disconnected from broker"""
	mqtt_connected = false
	print("MQTTManager: Disconnected from MQTT broker")


func _on_mqtt_error():
	"""Called when there's a connection error"""
	mqtt_connected = false
	print("MQTTManager: Connection failed!")


func get_connection_status() -> String:
	"""Get human-readable connection status"""
	if mqtt_connected:
		return "Connected (%s)" % DEVICE_ID
	else:
		return "Disconnected"


func _on_mqtt_message_received(topic: String, payload: String):
	"""Called when a message is received"""
	if mqtt_client.verbose_level >= 2:
		print("MQTTManager: [%s] %s" % [topic, payload])
	
	# Route to appropriate handler
	if topic == topic_start:
		_handle_start_message(payload)
	elif topic == topic_timeleft:
		_handle_timeleft_message(payload)
	elif topic == topic_finish:
		_handle_finish_message(payload)
	elif topic == TOPIC_SCORES:
		_handle_scores_message(payload)
	elif topic == TOPIC_IR_SENSOR:
		_handle_ir_sensor_message(payload)
	else:
		print("MQTTManager: Unknown topic: %s" % topic)


func _handle_start_message(payload: String):
	"""Handle game start message from server
	Format: {"team":{"name": "BadassTeam", "score": 1200}, "time": 180}
	"""
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse start message")
		return
	
	var data = json.data
	if data.has("team") and data.has("time"):
		var team_name = data.team.name if data.team.has("name") else "Unknown Team"
		var previous_score = data.team.score if data.team.has("score") else 0
		var time_seconds = data.time
		
		current_team_name = team_name
		is_session_active = true
		
		# Update GameManager
		GameManager.set_player_name(team_name)
		GameManager.set_score(previous_score)
		GameManager.start_timer(time_seconds)
		GameManager.start_game()
		
		print("MQTTManager: Game started for team '%s' with %d seconds" % [team_name, time_seconds])
		
		# Emit signal for setup screen or other listeners
		game_start_received.emit()


func _handle_timeleft_message(payload: String):
	"""Handle time remaining updates from server
	Format: seconds as string or number (e.g., "180" or 180)
	Server continuously updates seconds left, stays at 0 if no team present
	"""
	var time_left = int(payload)
	
	if time_left == 0 and is_session_active:
		# Time's up - end the game
		is_session_active = false
		GameManager.end_game()
		print("MQTTManager: Time's up! Game ended.")
	elif time_left > 0 and is_session_active:
		# Sync timer with server (optional - can be used to correct drift)
		# GameManager.time_remaining = time_left
		pass


func _handle_finish_message(payload: String):
	"""Handle finish message (echo from server or from other stations)
	Format: {"team": "BadassTeam", "score": 120}
	"""
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse finish message")
		return
	
	var data = json.data
	if data.has("team") and data.has("score"):
		var team_name = data.team
		var score = data.score
		print("MQTTManager: Team '%s' finished with score: %d" % [team_name, score])


func _handle_scores_message(payload: String):
	"""Handle leaderboard scores update from server
	Format: Array of team objects
	[
		{
			"name": "MaffiaBazen",
			"location": "finished",
			"scores": {"station-a": 800, "station-b": 750, "station-c": 600, "station-d": 800},
			"score": 2950
		},
		...
	]
	"""
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse scores message")
		return
	
	var scores_data = json.data
	if typeof(scores_data) != TYPE_ARRAY:
		print("MQTTManager: Invalid scores format (expected array)")
		return
	
	print("MQTTManager: Leaderboard updated - %d teams" % scores_data.size())
	
	# Emit signal or store for UI display
	# You can add a signal here if needed: emit_signal("leaderboard_updated", scores_data)


func _handle_ir_sensor_message(payload: String):
	"""Handle IR break beam sensor trigger
	Format: {"status": "triggered", "timestamp": "...", "sensor": "ir_beam"}
	"""
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse IR sensor message")
		return
	
	var data = json.data
	if data.has("status") and data.status == "triggered":
		print("MQTTManager: IR beam broken! Adding score...")
		# Add score to the game
		GameManager.add_score(1)  # Add 1 point per beam break


func publish_finish(final_score: int):
	"""Publish finish message when game completes
	Station sends: {"team": "BadassTeam", "score": 120}
	Only called by station devices, not highscore displays
	"""
	if DEVICE_TYPE != "station":
		print("MQTTManager: Only station devices can publish finish messages")
		return
	
	if not is_session_active or current_team_name == "":
		print("MQTTManager: Cannot publish finish - no active session")
		return
	
	if not mqtt_connected:
		print("MQTTManager: Cannot publish - not connected to broker")
		return
	
	var finish_data = {
		"team": current_team_name,
		"score": final_score
	}
	
	var json_string = JSON.stringify(finish_data)
	mqtt_client.publish(topic_finish, json_string)
	
	print("MQTTManager: Published finish to %s" % topic_finish)
	print("  Team: %s" % current_team_name)
	print("  Score: %d" % final_score)
	
	is_session_active = false


# ============================================================================
# Testing & Debug Functions
# ============================================================================

func test_start():
	"""Simulate a start message for testing"""
	var test_payload = '{"team":{"name":"TestTeam","score":500},"time":180}'
	print("\n=== TEST: Simulating start message ===")
	_handle_start_message(test_payload)


func test_finish():
	"""Simulate finishing the game"""
	print("\n=== TEST: Simulating game finish ===")
	if is_session_active:
		publish_finish(GameManager.score)
	else:
		print("No active session to finish")


func test_scores():
	"""Simulate a scores leaderboard update"""
	var test_payload = '''[
		{
			"name":"MaffiaBazen",
			"location":"finished",
			"scores":{"station-a":800,"station-b":750,"station-c":600,"station-d":800},
			"score":2950
		},
		{
			"name":"KoeleKikkers",
			"location":"station-b",
			"scores":{"station-a":1200,"station-b":800},
			"score":2000
		}
	]'''
	print("\n=== TEST: Simulating scores update ===")
	_handle_scores_message(test_payload)


func test_timeleft(seconds: int = 120):
	"""Simulate a time left update"""
	print("\n=== TEST: Simulating timeleft: %d seconds ===" % seconds)
	_handle_timeleft_message(str(seconds))


func test_add_score(points: int = 10):
	"""Add score for testing"""
	print("\n=== TEST: Adding %d points ===" % points)
	GameManager.add_score(points)


func print_status():
	"""Print current MQTT manager status"""
	print("\n=== MQTT Manager Status ===")
	print("Device Type: %s" % DEVICE_TYPE)
	print("Device ID: %s" % DEVICE_ID)
	print("Station ID: %s" % station_id)
	print("Connected: %s" % mqtt_connected)
	print("Session Active: %s" % is_session_active)
	print("Current Team: %s" % current_team_name)
	print("\nSubscribed Topics:")
	if station_id != "":
		print("  - %s" % topic_start)
		print("  - %s" % topic_timeleft)
		if DEVICE_TYPE == "station":
			print("  - %s" % topic_finish)
	print("  - %s" % TOPIC_SCORES)
	if DEVICE_TYPE == "station":
		print("  - %s" % TOPIC_IR_SENSOR)
	print("========================\n")
