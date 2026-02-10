extends Node

# MQTT Manager - Handles MQTT connections for drug lab station system
# Manages game start, finish, timer updates, and leaderboard
# Configuration is loaded from ConfigManager (station_config.json)

# Signals
signal game_start_received()
signal server_command_received(command: String)
signal team_updated(team_data: Dictionary)

# Configuration - loaded from ConfigManager
var BROKER_IP: String = "192.168.1.2"
var BROKER_PORT: int = 1883
var USE_WEBSOCKET: bool = false
var DEVICE_TYPE: String = "station"
var DEVICE_ID: String = "station-a"
var AUTO_CONNECT: bool = true

# MQTT Topics - Dynamically constructed based on device configuration
# Control Panel → Station (Subscribe)
var topic_start: String = ""  # QoS 1 (spec says 2, but library doesn't support it)
var topic_server_command: String = ""  # QoS 1 (spec says 2, but library doesn't support it)
var topic_team: String = ""  # QoS 1, Retained (spec says 2, but library doesn't support it)

# Station → Control Panel (Publish)
var topic_finish: String = ""  # QoS 1 (spec says 2, but library doesn't support it)
var topic_timeleft: String = ""  # QoS 0, Retained
var topic_stationscore: String = ""  # QoS 0, Retained
var topic_changename: String = ""  # QoS 1 (spec says 2, but library doesn't support it)

# Global topics
const TOPIC_HIGHSCORES: String = "erd/drugslab/highscores"  # Scoreboard (retained)
const TOPIC_STATION_FINISHED: String = "erd/drugslab/station-finished/team"  # Team completion status (retained)

# Legacy topics
const TOPIC_SCORES: String = "erd/drugslab/scores"

# State
var current_team_name: String = ""
var is_session_active: bool = false
var mqtt_connected: bool = false
var station_id: String = ""  # Extracted station ID (e.g., "station-a")
var name_suggestions: Array = []  # Name suggestions from start message

# Auto-reconnection settings
var auto_reconnect: bool = true
var reconnect_interval: float = 5.0  # Try to reconnect every 5 seconds (matching station-b)
var reconnect_timer: float = 0.0
var is_reconnecting: bool = false
var connection_timeout: float = 10.0  # Timeout for connection attempts
var connection_start_time: float = 0.0
var last_error: bool = false  # Track if last connection attempt failed

# MQTT client instance (using the real library)
var mqtt_client: Node = null


func _ready():
	# Wait for next frame to ensure ConfigManager has loaded its config
	await get_tree().process_frame
	
	# Load configuration from ConfigManager
	_load_config_from_manager()
	
	# Initialize device configuration
	_initialize_device_config()
	
	# Load the MQTT client scene from addons
	var mqtt_scene = load("res://addons/mqtt/mqtt.tscn")
	mqtt_client = mqtt_scene.instantiate()
	add_child(mqtt_client)
	
	# Configure client
	mqtt_client.client_id = "%s" % DEVICE_ID
	mqtt_client.verbose_level = 0  # 0=quiet (suppress "bad senddata packet" errors from broken sockets)
	
	# Connect signals
	mqtt_client.broker_connected.connect(_on_mqtt_connected)
	mqtt_client.broker_disconnected.connect(_on_mqtt_disconnected)
	mqtt_client.received_message.connect(_on_mqtt_message_received)
	mqtt_client.broker_connection_failed.connect(_on_mqtt_error)
	
	print("MQTTManager initialized")
	print("  Broker: %s:%d" % [BROKER_IP, BROKER_PORT])
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
		# Subscribe topics (from Control Panel)
		topic_start = "erd/drugslab/%s/start" % station_id
		topic_server_command = "erd/drugslab/%s/server_command" % station_id
		topic_team = "erd/drugslab/%s/team" % station_id
		# Publish topics (to Control Panel)
		topic_finish = "erd/drugslab/%s/finish" % station_id
		topic_timeleft = "erd/drugslab/%s/timeleft" % station_id
		topic_stationscore = "erd/drugslab/%s/stationscore" % station_id
		topic_changename = "erd/drugslab/%s/changename" % station_id
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
			topic_server_command = "erd/drugslab/%s/server_command" % station_id
			topic_team = "erd/drugslab/%s/team" % station_id
			topic_timeleft = "erd/drugslab/%s/timeleft" % station_id
			topic_stationscore = "erd/drugslab/%s/stationscore" % station_id
			topic_finish = "erd/drugslab/%s/finish" % station_id
	else:
		print("ERROR: Unknown DEVICE_TYPE: %s" % DEVICE_TYPE)


func connect_to_broker(custom_ip: String = "", custom_port: int = 0):
	"""Connect to the MQTT broker"""
	# Check if mqtt_client exists
	if not mqtt_client or not is_instance_valid(mqtt_client):
		print("MQTTManager: Cannot connect - mqtt_client not available")
		is_reconnecting = false
		return
	
	# Check if already connected or connecting
	if mqtt_client.brokerconnectmode != 0:  # BCM_NOCONNECTION = 0
		print("MQTTManager: Already connecting or connected (state: %d)" % mqtt_client.brokerconnectmode)
		# If already connected, we're done
		if mqtt_connected:
			print("MQTTManager: Already connected!")
			is_reconnecting = false
			return
		# If connecting but we're not aware of it, wait for it to complete
		if is_reconnecting:
			# Connection attempt already in progress
			print("MQTTManager: Connection attempt already in progress...")
			return
		else:
			# State mismatch - client is connecting but we didn't initiate it
			# Force disconnect and let the auto-reconnect logic handle it
			print("MQTTManager: State mismatch - forcing disconnect for clean state...")
			mqtt_client.disconnect_from_server()
			# Don't set is_reconnecting = false here, let the disconnect callback handle it
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
	is_reconnecting = true
	connection_start_time = Time.get_ticks_msec() / 1000.0
	mqtt_client.connect_to_broker(broker_url)


func disconnect_from_broker():
	"""Disconnect from the MQTT broker"""
	if not mqtt_client or not is_instance_valid(mqtt_client):
		print("MQTTManager: Cannot disconnect - mqtt_client not available")
		return
	
	print("MQTTManager: Disconnecting from broker")
	mqtt_client.disconnect_from_server()


func _on_mqtt_connected():
	"""Called when successfully connected to broker"""
	mqtt_connected = true
	is_reconnecting = false
	reconnect_timer = 0.0
	connection_start_time = 0.0
	last_error = false
	print("MQTTManager: Connected to MQTT broker")
	print("  Client ID: %s" % mqtt_client.client_id)
	
	# Subscribe based on device type
	print("MQTTManager: Subscribing to topics...")
	
	# All devices subscribe to global topics
	mqtt_client.subscribe(TOPIC_SCORES)
	print("  ✓ %s" % TOPIC_SCORES)
	
	mqtt_client.subscribe(TOPIC_HIGHSCORES)
	print("  ✓ %s (Retained)" % TOPIC_HIGHSCORES)
	
	mqtt_client.subscribe(TOPIC_STATION_FINISHED)
	print("  ✓ %s (Retained)" % TOPIC_STATION_FINISHED)
	
	# Station-specific subscriptions
	if station_id != "":
		# Subscribe to Control Panel → Station topics
		mqtt_client.subscribe(topic_start, 1)  # QoS 1 (library doesn't support QoS 2)
		print("  ✓ %s (QoS 1)" % topic_start)
		
		mqtt_client.subscribe(topic_server_command, 1)  # QoS 1 (library doesn't support QoS 2)
		print("  ✓ %s (QoS 1)" % topic_server_command)
		
		mqtt_client.subscribe(topic_team, 1)  # QoS 1, Retained (library doesn't support QoS 2)
		print("  ✓ %s (QoS 1, Retained)" % topic_team)
		
		mqtt_client.subscribe(topic_timeleft)  # QoS 0
		print("  ✓ %s (QoS 0)" % topic_timeleft)
		
		mqtt_client.subscribe(topic_stationscore)  # QoS 0
		print("  ✓ %s (QoS 0)" % topic_stationscore)
		
		# Only station devices (not highscore displays) need finish subscription for echo/confirmation
		if DEVICE_TYPE == "station":
			mqtt_client.subscribe(topic_finish, 1)  # QoS 1 (library doesn't support QoS 2)
			print("  ✓ %s (QoS 1, echo)" % topic_finish)
	
	print("MQTTManager: Subscription complete")


func _on_mqtt_disconnected():
	"""Called when disconnected from broker"""
	mqtt_connected = false
	is_reconnecting = false
	reconnect_timer = 0.0  # Reset timer to attempt reconnection immediately
	last_error = false  # Clean disconnect, not an error
	print("MQTTManager: Disconnected from MQTT broker - will attempt reconnection")


func _on_mqtt_error():
	"""Called when there's a connection error"""
	mqtt_connected = false
	last_error = true
	is_reconnecting = false  # Reset to allow new reconnection attempts
	reconnect_timer = 0.0  # Reset timer to attempt reconnection immediately
	print("MQTTManager: Connection failed - will attempt reconnection")


func _process(delta):
	"""Monitor connection and handle auto-reconnection"""
	# Always monitor connection state, even if auto_reconnect is disabled
	if mqtt_client and is_instance_valid(mqtt_client):
		# Sync our connection state with the actual client state
		var actual_connection_mode = mqtt_client.brokerconnectmode
		
		# BCM_NOCONNECTION = 0, BCM_FAILED_CONNECTION = 5, BCM_CONNECTED = 20
		# Detect if client is in disconnected or failed state
		if (actual_connection_mode == 0 or actual_connection_mode == 5) and mqtt_connected:
			# We think we're connected but client says we're not
			print("MQTTManager: Detected disconnection (state mismatch - mode: %d)" % actual_connection_mode)
			mqtt_connected = false
			is_reconnecting = false
			reconnect_timer = 0.0
		elif (actual_connection_mode == 0 or actual_connection_mode == 5) and is_reconnecting:
			# We think we're reconnecting but client is in disconnected state
			# This can happen when WiFi is unavailable and connection fails immediately
			print("MQTTManager: Reconnection failed immediately (mode: %d) - will retry" % actual_connection_mode)
			is_reconnecting = false
			reconnect_timer = 0.0
		elif actual_connection_mode == 20 and mqtt_connected:
			# Client thinks it's connected - verify socket is actually healthy
			if not _is_socket_healthy():
				print("MQTTManager: Socket broken despite connected state - forcing reconnect")
				mqtt_client.disconnect_from_server()
				mqtt_connected = false
				is_reconnecting = false
				reconnect_timer = 0.0
		elif actual_connection_mode != 0 and not mqtt_connected and not is_reconnecting:
			# Client is in connecting/connected state but we don't know about it
			# This shouldn't normally happen, but let's handle it
			print("MQTTManager: Client state sync - appears to be connecting/connected")
	
	if not auto_reconnect:
		return
	
	# Check for connection timeout
	if is_reconnecting and mqtt_client and is_instance_valid(mqtt_client):
		var current_time = Time.get_ticks_msec() / 1000.0
		if connection_start_time > 0 and mqtt_client.brokerconnectmode != 0 and (current_time - connection_start_time) > connection_timeout:
			print("MQTTManager: Connection attempt timed out after %.1f seconds" % connection_timeout)
			print("MQTTManager: Broker state was: %d" % mqtt_client.brokerconnectmode)
			# Force disconnect to reset state
			mqtt_client.disconnect_from_server()
			is_reconnecting = false
			mqtt_connected = false
			reconnect_timer = 0.0
			connection_start_time = 0.0
			last_error = true
	
	# Check if we should attempt reconnection
	if not mqtt_connected and not is_reconnecting:
		reconnect_timer += delta
		if reconnect_timer >= reconnect_interval:
			reconnect_timer = 0.0
			_attempt_reconnection()


func _attempt_reconnection():
	"""Attempt to reconnect to MQTT broker"""
	# Check if mqtt_client is available
	if mqtt_client == null:
		print("MQTTManager: Cannot reconnect - mqtt_client not initialized")
		return
	
	# Check if mqtt_client is valid
	if not is_instance_valid(mqtt_client):
		print("MQTTManager: Cannot reconnect - mqtt_client is invalid")
		return
	
	# If broker state is stuck (not disconnected but we're not connected), force disconnect
	if mqtt_client.brokerconnectmode != 0:  # BCM_NOCONNECTION = 0
		if not mqtt_connected and not is_reconnecting:
			print("MQTTManager: Broker state stuck (mode: %d), forcing disconnect..." % mqtt_client.brokerconnectmode)
			mqtt_client.disconnect_from_server()
			# Will try again on next reconnect interval
			return
		# Connection attempt already in progress
		return
	
	is_reconnecting = true
	print("MQTTManager: Attempting to reconnect to broker...")
	connect_to_broker()


func _is_socket_healthy() -> bool:
	"""Quietly check if the underlying socket connection is still healthy"""
	if not mqtt_client or not is_instance_valid(mqtt_client):
		return false
	
	# Check TCP socket status
	if mqtt_client.socket and is_instance_valid(mqtt_client.socket):
		var socket_status = mqtt_client.socket.get_status()
		# STATUS_NONE = 0, STATUS_CONNECTING = 1, STATUS_CONNECTED = 2, STATUS_ERROR = 3
		if socket_status != 2:  # Not STATUS_CONNECTED
			return false
	
	# Check SSL socket status if using SSL
	if mqtt_client.sslsocket and is_instance_valid(mqtt_client.sslsocket):
		var ssl_status = mqtt_client.sslsocket.get_status()
		# STATUS_DISCONNECTED = 0, STATUS_HANDSHAKING = 1, STATUS_CONNECTED = 2, STATUS_ERROR = 3, STATUS_ERROR_HOSTNAME_MISMATCH = 4
		if ssl_status != 2:  # Not STATUS_CONNECTED
			return false
	
	# Check WebSocket status if using WebSocket
	if mqtt_client.websocket and is_instance_valid(mqtt_client.websocket):
		var ws_state = mqtt_client.websocket.get_ready_state()
		# STATE_CONNECTING = 0, STATE_OPEN = 1, STATE_CLOSING = 2, STATE_CLOSED = 3
		if ws_state != 1:  # Not STATE_OPEN
			return false
	
	return true


func _check_socket_health() -> bool:
	"""Check if the underlying socket connection is still healthy"""
	if not mqtt_client or not is_instance_valid(mqtt_client):
		return false
	
	# Check TCP socket status
	if mqtt_client.socket and is_instance_valid(mqtt_client.socket):
		var socket_status = mqtt_client.socket.get_status()
		# STATUS_NONE = 0, STATUS_CONNECTING = 1, STATUS_CONNECTED = 2, STATUS_ERROR = 3
		if socket_status != 2:  # Not STATUS_CONNECTED
			print("MQTTManager: Socket not connected (status: %d)" % socket_status)
			return false
	
	# Check SSL socket status if using SSL
	if mqtt_client.sslsocket and is_instance_valid(mqtt_client.sslsocket):
		var ssl_status = mqtt_client.sslsocket.get_status()
		# STATUS_DISCONNECTED = 0, STATUS_HANDSHAKING = 1, STATUS_CONNECTED = 2, STATUS_ERROR = 3
		if ssl_status != 2:  # Not STATUS_CONNECTED
			print("MQTTManager: SSL socket not connected (status: %d)" % ssl_status)
			return false
	
	# Check WebSocket status if using WebSocket
	if mqtt_client.websocket and is_instance_valid(mqtt_client.websocket):
		var ws_state = mqtt_client.websocket.get_ready_state()
		# STATE_CONNECTING = 0, STATE_OPEN = 1, STATE_CLOSING = 2, STATE_CLOSED = 3
		if ws_state != 1:  # Not STATE_OPEN
			print("MQTTManager: WebSocket not open (state: %d)" % ws_state)
			return false
	
	return true


func get_connection_status() -> String:
	"""Get human-readable connection status"""
	# Double-check actual client state
	if mqtt_client and is_instance_valid(mqtt_client):
		if mqtt_client.brokerconnectmode == 0:
			# Actually disconnected regardless of what we think
			if mqtt_connected:
				# Force update our state
				mqtt_connected = false
			if is_reconnecting:
				return "Reconnecting..."
			elif not auto_reconnect:
				if last_error:
					return "Connection Failed (auto-reconnect disabled)"
				else:
					return "Disconnected (auto-reconnect disabled)"
			elif last_error and reconnect_timer < 1.0:
				# Show error state briefly after failure
				return "Connection Failed (retrying in %.1fs)" % max(0.0, reconnect_interval - reconnect_timer)
			else:
				return "Disconnected (will retry in %.1fs)" % max(0.0, reconnect_interval - reconnect_timer)
		else:
			# Client thinks it's connecting or connected
			if mqtt_connected:
				return "Connected (%s)" % DEVICE_ID
			else:
				return "Connecting..."
	
	# Fallback if client not available
	if mqtt_connected:
		return "Connected (%s)" % DEVICE_ID
	elif is_reconnecting:
		return "Reconnecting..."
	elif not auto_reconnect:
		if last_error:
			return "Connection Failed (auto-reconnect disabled)"
		else:
			return "Disconnected (auto-reconnect disabled)"
	elif last_error and reconnect_timer < 1.0:
		return "Connection Failed (retrying in %.1fs)" % max(0.0, reconnect_interval - reconnect_timer)
	else:
		return "Disconnected (will retry in %.1fs)" % max(0.0, reconnect_interval - reconnect_timer)


func set_auto_reconnect(enabled: bool):
	"""Enable or disable automatic reconnection"""
	auto_reconnect = enabled
	print("MQTTManager: Auto-reconnect %s" % ("enabled" if enabled else "disabled"))


func _on_mqtt_message_received(topic: String, payload: String):
	"""Called when a message is received"""
	if mqtt_client and is_instance_valid(mqtt_client) and mqtt_client.verbose_level >= 2:
		print("MQTTManager: [%s] %s" % [topic, payload])
	
	# Route to appropriate handler
	if topic == topic_start:
		_handle_start_message(payload)
	elif topic == topic_server_command:
		_handle_server_command_message(payload)
	elif topic == topic_team:
		_handle_team_message(payload)
	elif topic == topic_timeleft:
		_handle_timeleft_message(payload)
	elif topic == topic_stationscore:
		_handle_stationscore_message(payload)
	elif topic == topic_finish:
		_handle_finish_message(payload)
	elif topic == TOPIC_SCORES:
		_handle_scores_message(payload)
	elif topic == TOPIC_HIGHSCORES:
		_handle_highscores_message(payload)
	elif topic == TOPIC_STATION_FINISHED:
		_handle_station_finished_message(payload)
	else:
		print("MQTTManager: Unknown topic: %s" % topic)


func _handle_start_message(payload: String):
	"""Handle game start message from server
	Format: {"team":{"name": "BadassTeam", "score": 1200}, "time": 180}
	"""
	print("MQTTManager: Raw payload bytes: ", payload.to_utf8_buffer())
	print("MQTTManager: Payload length: ", payload.length())
	
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse start message. Error code: ", error)
		print("MQTTManager: Error at line: ", json.get_error_line())
		print("MQTTManager: Error message: ", json.get_error_message())
		return
	
	var data = json.data
	if data.has("team") and data.has("time"):
		var team_name = data.team.name if data.team.has("name") else "Unknown Team"
		var previous_score = data.team.score if data.team.has("score") else 0
		var time_seconds = data.time
		
		# Extract name suggestions if provided
		if data.has("namesuggestions"):
			name_suggestions = data.namesuggestions
			print("MQTTManager: Received %d name suggestions" % name_suggestions.size())
		else:
			name_suggestions = []
		
		# BUGFIX: If there's already an active session, end it first to clean up state
		if is_session_active:
			print("MQTTManager: Previous session still active - cleaning up before starting new session")
			is_session_active = false
			GameManager.end_game()
		
		# BUGFIX: Always reset game state before starting a new session
		# This ensures timers, scores, and other state are properly cleared
		GameManager.reset_game()
		
		# BUGFIX: Reset questions so they can be used again
		if has_node("/root/QuestionManager"):
			get_node("/root/QuestionManager").reset()
		
		current_team_name = team_name
		is_session_active = true
		
		# Update GameManager with new session data
		GameManager.set_player_name(team_name)
		GameManager.set_score(previous_score)  # Set total score (includes other stations)
		GameManager.station_score = 0  # Reset this station's score to 0
		GameManager.start_timer(time_seconds)  # This will now publish timeleft immediately
		GameManager.start_game()
		
		# Publish initial station score to MQTT (clear retained value for new team)
		publish_stationscore(0)
		
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


func _handle_server_command_message(payload: String):
	"""Handle server command message
	Format: "stop" or "restart" (string payload)
	"""
	var command = payload.strip_edges().trim_prefix('"').trim_suffix('"')  # Remove quotes if present
	print("MQTTManager: Server command received: %s" % command)
	
	if command == "stop":
		print("MQTTManager: Stop command - ending game and returning to setup")
		is_session_active = false
		GameManager.end_game()
		# Publish 0 to clear retained values
		publish_timeleft(0)
		publish_stationscore(0)
		# Return to setup screen
		get_tree().change_scene_to_file("res://scenes/setup_screen.tscn")
		
	elif command == "restart":
		print("MQTTManager: Restart command - resetting game and returning to setup")
		is_session_active = false
		GameManager.reset_game()
		# Publish 0 to clear retained values
		publish_timeleft(0)
		publish_stationscore(0)
		# Return to setup screen
		get_tree().change_scene_to_file("res://scenes/setup_screen.tscn")
	else:
		print("MQTTManager: Unknown command: %s" % command)
	
	server_command_received.emit(command)


func _handle_team_message(payload: String):
	"""Handle team update message
	Format: {"name": "...", "scores": {"station-a": 100, "station-b": 200, ...}}
	"""
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse team message")
		return
	
	var data = json.data
	if data.has("name"):
		var team_name = data.name
		
		# Ignore empty team messages (cleared by control panel) when no session is active
		if team_name == "" and not is_session_active:
			print("MQTTManager: Ignoring empty team message (no active session)")
			return
		
		var scores = data.scores if data.has("scores") else {}
		print("MQTTManager: Team update - Name: %s" % team_name)
		if scores:
			print("MQTTManager: Team scores: %s" % str(scores))
		
		# Update current team if game is active
		if is_session_active:
			current_team_name = team_name
			GameManager.set_player_name(team_name)
		
		team_updated.emit(data)


func _handle_stationscore_message(payload: String):
	"""Handle station score update (retained)
	Format: number as string (e.g., "850")
	"""
	var score = int(payload)
	print("MQTTManager: Station score update: %d" % score)
	# This is typically published by us, but can be used for sync if needed


func _handle_finish_message(payload: String):
	"""Handle finish message (echo from server or from other stations)
	Format: {"team": "...", "stationscore": 1200}
	"""
	# Ignore finish messages when no session is active (stale or echo from previous session)
	if not is_session_active:
		print("MQTTManager: Ignoring finish message (no active session)")
		return
	
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse finish message")
		return
	
	var data = json.data
	if data.has("team") and data.has("stationscore"):
		var team_name = data.team
		var score = data.stationscore
		print("MQTTManager: Team '%s' finished with station score: %d" % [team_name, score])


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


func _handle_highscores_message(payload: String):
	"""Handle highscores/scoreboard update from server
	Format: Array of team objects (retained)
	[
		{
			"name": "TeamName",
			"location": "finished",
			"scores": {"station-a": 800, "station-b": 750, ...},
			"score": 2950
		},
		...
	]
	"""
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse highscores message")
		return
	
	var highscores_data = json.data
	if typeof(highscores_data) != TYPE_ARRAY:
		print("MQTTManager: Invalid highscores format (expected array)")
		return
	
	print("MQTTManager: Highscores updated - %d teams" % highscores_data.size())
	
	# Store or emit signal for UI display
	# You can add a signal here if needed: emit_signal("highscores_updated", highscores_data)


func _handle_station_finished_message(payload: String):
	"""Handle station completion status update
	Format: Team completion status per station (retained)
	{
		"team-name": {
			"station-a": true,
			"station-b": true,
			"station-c": false,
			"station-d": false
		}
	}
	"""
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error != OK:
		print("MQTTManager: Failed to parse station-finished message")
		return
	
	var finished_data = json.data
	print("MQTTManager: Station finished status updated")
	print("  Data: %s" % str(finished_data))
	
	# Store or emit signal for UI display
	# You can add a signal here if needed: emit_signal("station_finished_updated", finished_data)


func publish_finish(final_score: int):
	"""Publish finish message when game completes
	Station sends: {"team": "...", "stationscore": 1200}
	QoS 1, Not retained (spec says QoS 2, but library doesn't support it)
	Only called by station devices, not highscore displays
	"""
	if DEVICE_TYPE != "station":
		print("MQTTManager: Only station devices can publish finish messages")
		return
	
	if current_team_name == "":
		print("MQTTManager: Cannot publish finish - no team name set")
		return
	
	if not mqtt_connected:
		print("MQTTManager: Cannot publish - not connected to broker")
		return
	
	if not mqtt_client or not is_instance_valid(mqtt_client):
		print("MQTTManager: Cannot publish - mqtt_client not available")
		return
	
	var finish_data = {
		"team": current_team_name,
		"stationscore": final_score
	}
	
	var json_string = JSON.stringify(finish_data)
	mqtt_client.publish(topic_finish, json_string, false, 1)  # QoS 1, Not retained
	
	print("MQTTManager: Published finish to %s: %s" % [topic_finish, json_string])
	print("  Team: %s" % current_team_name)
	print("  Station Score: %d" % final_score)
	
	# Mark session as inactive after finishing
	is_session_active = false
	
	# Clear retained values
	publish_timeleft(0)
	publish_stationscore(0)


func publish_timeleft(seconds: int):
	"""Publish time left update
	Station sends: number (e.g., 180)
	QoS 0, Retained
	"""
	if DEVICE_TYPE != "station":
		print("MQTTManager: Only station devices can publish timeleft")
		return
	
	if not mqtt_connected:
		print("MQTTManager: Cannot publish - not connected to broker")
		return
	
	if not mqtt_client or not is_instance_valid(mqtt_client):
		print("MQTTManager: Cannot publish - mqtt_client not available")
		return
	
	mqtt_client.publish(topic_timeleft, str(seconds), true, 0)  # QoS 0, Retained


func publish_stationscore(score: int):
	"""Publish station score update
	Station sends: number (e.g., 850)
	QoS 0, Retained
	"""
	if DEVICE_TYPE != "station":
		print("MQTTManager: Only station devices can publish stationscore")
		return
	
	if not mqtt_connected:
		print("MQTTManager: Cannot publish - not connected to broker")
		return
	
	if not mqtt_client or not is_instance_valid(mqtt_client):
		print("MQTTManager: Cannot publish - mqtt_client not available")
		return
	
	mqtt_client.publish(topic_stationscore, str(score), true, 0)  # QoS 0, Retained


func publish_changename(old_name: String, new_name: String):
	"""Publish name change request
	Station sends: {"oldname": "???", "newname": "..."}
	QoS 1, Not retained (spec says QoS 2, but library doesn't support it)
	"""
	if DEVICE_TYPE != "station":
		print("MQTTManager: Only station devices can publish changename")
		return
	
	if not mqtt_connected:
		print("MQTTManager: Cannot publish - not connected to broker")
		return
	
	if not mqtt_client or not is_instance_valid(mqtt_client):
		print("MQTTManager: Cannot publish - mqtt_client not available")
		return
	
	var changename_data = {
		"oldname": old_name,
		"newname": new_name
	}
	
	var json_string = JSON.stringify(changename_data)
	mqtt_client.publish(topic_changename, json_string, false, 1)  # QoS 1, Not retained
	
	print("MQTTManager: Published changename to %s" % topic_changename)
	print("  Old Name: %s" % old_name)
	print("  New Name: %s" % new_name)
	
	# Update local team name
	current_team_name = new_name
	GameManager.set_player_name(new_name)


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
	print("Auto-reconnect: %s" % auto_reconnect)
	if not mqtt_connected and auto_reconnect:
		print("Reconnection in: %.1fs" % (reconnect_interval - reconnect_timer))
	print("Session Active: %s" % is_session_active)
	print("Current Team: %s" % current_team_name)
	print("\nSubscribed Topics (Control Panel → Station):")
	if station_id != "":
		print("  - %s (QoS 1)" % topic_start)
		print("  - %s (QoS 1)" % topic_server_command)
		print("  - %s (QoS 1, Retained)" % topic_team)
		print("  - %s (QoS 0, Retained)" % topic_timeleft)
		print("  - %s (QoS 0, Retained)" % topic_stationscore)
		if DEVICE_TYPE == "station":
			print("  - %s (QoS 1)" % topic_finish)
	print("\nPublish Topics (Station → Control Panel):")
	if DEVICE_TYPE == "station" and station_id != "":
		print("  - %s (QoS 1)" % topic_finish)
		print("  - %s (QoS 0, Retained)" % topic_timeleft)
		print("  - %s (QoS 0, Retained)" % topic_stationscore)
		print("  - %s (QoS 1)" % topic_changename)
	print("\nGlobal Topics:")
	print("  - %s (Retained)" % TOPIC_HIGHSCORES)
	print("  - %s (Retained)" % TOPIC_STATION_FINISHED)
	print("\nLegacy Topics:")
	print("  - %s" % TOPIC_SCORES)
	print("========================\n")
