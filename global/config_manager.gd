extends Node

# Global Configuration Manager
# Loads station_config.json and provides access to all settings

var config_data: Dictionary = {}
var config_loaded: bool = false

func _ready():
	load_config()

func load_config() -> bool:
	"""Load configuration from station_config.json"""
	var config_path = ""
	
	# Priority 1: External config file next to executable (for exported builds only)
	# Check if NOT running in editor (more reliable than checking for "standalone")
	if not OS.has_feature("editor"):
		var exe_path = OS.get_executable_path()
		var exe_dir = exe_path.get_base_dir()
		
		print("ConfigManager: Running as exported build (not in editor)")
		print("ConfigManager: Executable path: ", exe_path)
		print("ConfigManager: Executable directory: ", exe_dir)
		print("ConfigManager: Current working directory: ", OS.get_environment("PWD"))
		
		# Try multiple path variations for external config
		var paths_to_try = [
			exe_dir.path_join("station_config.json"),
			exe_dir + "/station_config.json",
			OS.get_environment("PWD") + "/station_config.json",
			"./station_config.json"
		]
		
		for path in paths_to_try:
			print("ConfigManager: Checking external path: ", path)
			var exists = FileAccess.file_exists(path)
			print("ConfigManager:   -> exists: ", exists)
			if exists:
				config_path = path
				print("ConfigManager: ✓ Found external config at: ", path)
				break
	
	# Priority 2: Bundled resource (fallback for builds, primary for editor)
	if config_path == "":
		if FileAccess.file_exists("res://station_config.json"):
			config_path = "res://station_config.json"
			print("ConfigManager: Using bundled config from res://")
		else:
			print("ConfigManager: No bundled config found at res://station_config.json")
	
	# Priority 3: User data directory (last resort)
	if config_path == "":
		if FileAccess.file_exists("user://station_config.json"):
			config_path = "user://station_config.json"
			print("ConfigManager: Using user directory config")
	
	if config_path == "":
		print("ConfigManager: ERROR - No config file found in any location!")
		print("ConfigManager: Using default values")
		_set_defaults()
		return false
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		print("ConfigManager: Failed to open config file")
		_set_defaults()
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		print("ConfigManager: Failed to parse config: ", json.get_error_message())
		_set_defaults()
		return false
	
	config_data = json.data
	config_loaded = true
	
	print("ConfigManager: Loaded configuration from %s" % config_path)
	_apply_display_settings()
	return true


func _set_defaults():
	"""Set default configuration values"""
	config_data = {
		"mqtt": {
			"broker_ip": "127.0.0.1",
			"broker_port": 1883,
			"auto_connect": true,
			"use_websocket": false
		},
		"device": {
			"type": "station",
			"id": "station-b"
		},
		"display": {
			"fullscreen": true,
			"width": 1080,
			"height": 1920,
			"vsync": true
		},
		"game": {
			"default_time": 180,
			"question_timer": 30.0,
			"hint_delay": 15.0,
			"points_per_question": 100,
			"points_memory_3x3": 100,
			"points_memory_4x4": 200,
			"time_bonus_multiplier": 5
		}
	}


func _apply_display_settings():
	"""Apply display settings from config"""
	if !config_data.has("display"):
		return
	
	var display = config_data.display
	
	if display.has("fullscreen"):
		if display.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	if display.has("width") and display.has("height"):
		DisplayServer.window_set_size(Vector2i(display.width, display.height))
	
	if display.has("vsync"):
		if display.vsync:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


# Helper functions to get config values
func get_mqtt_broker_ip() -> String:
	return config_data.get("mqtt", {}).get("broker_ip", "127.0.0.1")

func get_mqtt_broker_port() -> int:
	return config_data.get("mqtt", {}).get("broker_port", 1883)

func get_mqtt_auto_connect() -> bool:
	return config_data.get("mqtt", {}).get("auto_connect", true)

func get_mqtt_use_websocket() -> bool:
	return config_data.get("mqtt", {}).get("use_websocket", false)

func get_device_type() -> String:
	return config_data.get("device", {}).get("type", "station")

func get_device_id() -> String:
	return config_data.get("device", {}).get("id", "station-b")

func get_default_game_time() -> int:
	return config_data.get("game", {}).get("default_time", 180)

func get_question_timer() -> float:
	return config_data.get("game", {}).get("question_timer", 30.0)

func get_hint_delay() -> float:
	return config_data.get("game", {}).get("hint_delay", 15.0)

func get_points_per_question() -> int:
	return config_data.get("game", {}).get("points_per_question", 100)

func get_points_memory_3x3() -> int:
	return config_data.get("game", {}).get("points_memory_3x3", 100)

func get_points_memory_4x4() -> int:
	return config_data.get("game", {}).get("points_memory_4x4", 200)

func get_time_bonus_multiplier() -> int:
	return config_data.get("game", {}).get("time_bonus_multiplier", 5)

func get_go_screen_time() -> float:
	return config_data.get("game", {}).get("go_screen_time", 10.0)

func get_display_width() -> int:
	return config_data.get("display", {}).get("width", 1080)

func get_display_height() -> int:
	return config_data.get("display", {}).get("height", 1920)

func is_fullscreen() -> bool:
	return config_data.get("display", {}).get("fullscreen", true)

func print_config():
	"""Print current configuration"""
	print("\n=== Configuration ===")
	print("MQTT Broker: %s:%d" % [get_mqtt_broker_ip(), get_mqtt_broker_port()])
	print("Device: %s (%s)" % [get_device_id(), get_device_type()])
	print("Display: %dx%d (Fullscreen: %s)" % [get_display_width(), get_display_height(), is_fullscreen()])
	print("Game Time: %ds" % get_default_game_time())
	print("Question Timer: %ds" % get_question_timer())
	print("Scoring: Question=%d, Memory 3x3=%d, Memory 4x4=%d, Time Bonus x%d" % [get_points_per_question(), get_points_memory_3x3(), get_points_memory_4x4(), get_time_bonus_multiplier()])
	print("===================\n")
