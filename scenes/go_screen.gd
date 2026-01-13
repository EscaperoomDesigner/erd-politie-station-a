extends Control

# GO GO GO screen shown after game ends
# Displays for 10 seconds then returns to setup screen

@onready var go_label: Label = %GoLabel
@onready var timer_label: Label = %TimerLabel

var countdown_time: float = 10.0


func _ready():
	print("GoScreen: Initialized")
	# Start countdown


func _process(delta: float):
	if countdown_time > 0:
		countdown_time -= delta
		
		# Update timer label if it exists
		if timer_label:
			timer_label.text = "Volgende ronde begint over: %d" % ceil(countdown_time)
		
		# When time is up, go to setup screen
		if countdown_time <= 0:
			_return_to_setup()


func _return_to_setup():
	"""Return to setup screen to wait for next game"""
	print("GoScreen: Returning to setup screen")
	
	# Reset game manager
	GameManager.reset_game()
	
	# Reset questions so they can be used again and randomized
	QuestionManager.reset()
	
	# Change to setup screen
	get_tree().change_scene_to_file("uid://c8l3yqs7hfmxr")
