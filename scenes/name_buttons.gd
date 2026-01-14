extends VBoxContainer

# Name Buttons Component - Displays name selection buttons from MQTT name suggestions

signal name_selected(selected_name: String)

# Preload the button scene
const NameButtonScene = preload("res://scenes/name_button.tscn")

# Button appearance settings - easily adjustable
@export var button_min_width: float = 0.0
@export var button_min_height: float = 60.0
@export var button_font_size: int = 24

var generated_names: Array[String] = []


func _ready():
	_load_names_from_mqtt()
	_create_buttons()


func _load_names_from_mqtt():
	"""Load name suggestions from MQTTManager"""
	generated_names.clear()
	
	# Get name suggestions from MQTTManager
	if MQTTManager and MQTTManager.name_suggestions.size() > 0:
		for name in MQTTManager.name_suggestions:
			generated_names.append(str(name))
		print("NameButtons: Loaded %d name suggestions from MQTT" % generated_names.size())
	else:
		print("NameButtons: No name suggestions available from MQTT")
		# Fallback to placeholder if no suggestions
		generated_names = ["Team 1", "Team 2", "Team 3", "Team 4", "Team 5"]


func _create_buttons():
	"""Create buttons for each group name"""
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	
	# Create new buttons from scene
	for name in generated_names:
		var button = NameButtonScene.instantiate()
		button.text = name
		button.custom_minimum_size = Vector2(button_min_width, button_min_height)
		button.add_theme_font_size_override("font_size", button_font_size)
		button.focus_mode = Control.FOCUS_NONE  # Disable focus
		button.pressed.connect(_on_button_pressed.bind(name))
		add_child(button)


func _on_button_pressed(selected_name: String):
	"""Emit signal when a name is selected"""
	SfxManager.play_click()
	name_selected.emit(selected_name)


func get_random_name() -> String:
	"""Get a random name from the generated names"""
	if generated_names.is_empty():
		return ""
	return generated_names.pick_random()
