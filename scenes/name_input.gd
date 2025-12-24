extends Control

# Name Input - Kies een random groepsnaam

signal name_confirmed(player_name: String)

@onready var name_buttons = $VBoxContainer/NameButtons
@onready var timer_progress_bar = %TimerProgressBar

# Timer variables
var name_timer: float = 10.0
var time_remaining: float = 10.0
var timer_active: bool = false


func _ready():
	# Start playing tense music
	MusicManager.play_tense_music()
	
	# Connect to name_buttons signal
	if name_buttons:
		name_buttons.name_selected.connect(_on_name_selected)
	
	# Start the timer
	time_remaining = name_timer
	timer_active = true
	if timer_progress_bar:
		timer_progress_bar.value = 1.0
		timer_progress_bar.modulate = Color(0.3, 1.0, 0.3)


func _process(delta: float):
	"""Update timer every frame"""
	if timer_active:
		time_remaining -= delta
		
		# Update progress bar (1.0 = full, 0.0 = empty)
		if timer_progress_bar:
			timer_progress_bar.value = time_remaining / name_timer
			
			# Change color based on time remaining
			if time_remaining <= name_timer * 0.25:
				# Red when less than 25% time left
				timer_progress_bar.modulate = Color(1.0, 0.3, 0.3)
			elif time_remaining <= name_timer * 0.5:
				# Yellow when less than 50% time left
				timer_progress_bar.modulate = Color(1.0, 1.0, 0.3)
			else:
				# Green when more than 50% time left
				timer_progress_bar.modulate = Color(0.3, 1.0, 0.3)
		
		# Time's up! Select random name
		if time_remaining <= 0:
			timer_active = false
			_on_timer_expired()


func _on_timer_expired():
	"""Called when timer runs out - select random name"""
	if name_buttons:
		var random_name = name_buttons.get_random_name()
		if random_name:
			_on_name_selected(random_name)


func _on_name_selected(selected_name: String):
	timer_active = false
	GameManager.set_player_name(selected_name)
	name_confirmed.emit(selected_name)
	queue_free()
