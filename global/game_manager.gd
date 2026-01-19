extends Node

# GameManager - Central game state management
# Handles score, timer, player info, and game flow

# Signals
signal score_changed(new_score: int)
signal timer_updated(time_left: float)
signal game_started()
signal game_ended()
signal player_name_changed(new_name: String)

# Game state
var score: int = 0  # Total score (includes other stations)
var station_score: int = 0  # This station's score only
var player_name: String = "PLAYER"
var game_time: float = 0.0
var is_game_active: bool = false

# Timer
var timer_running: bool = false
var time_remaining: float = 0.0
var mqtt_publish_timer: float = 0.0  # Timer for MQTT updates


func _ready():
	print("GameManager initialized")


func _process(delta: float):
	if timer_running and time_remaining > 0:
		time_remaining -= delta
		timer_updated.emit(time_remaining)
		
		# Publish timeleft to MQTT every second
		mqtt_publish_timer += delta
		if mqtt_publish_timer >= 1.0:
			mqtt_publish_timer = 0.0
			if has_node("/root/MQTTManager"):
				get_node("/root/MQTTManager").publish_timeleft(int(time_remaining))
		
		if time_remaining <= 0:
			time_remaining = 0
			timer_running = false
			end_game()


func _input(event: InputEvent):
	if event.is_action_pressed("close"):
		print("Close input detected - quitting game")
		get_tree().quit()


func start_game():
	"""Start a new game"""
	is_game_active = true
	game_started.emit()
	print("Game started")


func end_game():
	"""End the current game"""
	is_game_active = false
	timer_running = false
	game_ended.emit()
	print("Game ended - Final score: ", score, " (Station score: ", station_score, ")")
	
	# Publish finish to MQTT with station's own score (not the total)
	if has_node("/root/MQTTManager"):
		get_node("/root/MQTTManager").publish_finish(station_score)


func reset_game():
	"""Reset all game state"""
	score = 0
	station_score = 0
	time_remaining = 0.0
	timer_running = false
	is_game_active = false
	score_changed.emit(score)
	timer_updated.emit(time_remaining)
	print("Game reset")


func add_score(points: int = 1):
	"""Add points to the score"""
	if is_game_active:
		score += points
		station_score += points
		score_changed.emit(score)
		
		# Publish station's own score to MQTT (not the total)
		if has_node("/root/MQTTManager"):
			get_node("/root/MQTTManager").publish_stationscore(station_score)
		
		# Play coin sound effect
		if has_node("/root/SfxManager"):
			get_node("/root/SfxManager").play_coin_sound()
		
		print("Score added: +%d (Total: %d, Station: %d)" % [points, score, station_score])
	else:
		print("Cannot add score - game not active")


func set_score(new_score: int):
	"""Set the score directly"""
	score = new_score
	score_changed.emit(score)


func set_player_name(new_name: String):
	"""Set the player name"""
	player_name = new_name
	player_name_changed.emit(new_name)


func start_timer(duration: float):
	"""Start a countdown timer"""
	time_remaining = duration
	timer_running = true
	timer_updated.emit(time_remaining)


func stop_timer():
	"""Stop the timer"""
	timer_running = false
