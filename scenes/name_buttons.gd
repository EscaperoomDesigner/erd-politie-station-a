extends VBoxContainer

# Name Buttons Component - Generates and displays name selection buttons

signal name_selected(selected_name: String)

# Word lists for generating random names
var word_list_1 = [
	"Snelle", "Slimme", "Sterke", "Stoere", "Dappere", 
	"Grappige", "Wilde", "Coole", "Vrolijke", "Geweldige"
]

var word_list_2 = [
	"Agenten", "Helden", "Champions", "Detectives", "Experts",
	"Tigers", "Eagles", "Ninjas", "Dragons", "Warriors"
]

# Button appearance settings - easily adjustable
@export var button_min_width: float = 0.0
@export var button_min_height: float = 60.0
@export var button_font_size: int = 24
@export var number_of_names: int = 5

var generated_names: Array[String] = []


func _ready():
	_generate_names()
	_create_buttons()


func _generate_names():
	"""Generate random group names"""
	generated_names.clear()
	
	# Shuffle the lists
	var shuffled_1 = word_list_1.duplicate()
	var shuffled_2 = word_list_2.duplicate()
	shuffled_1.shuffle()
	shuffled_2.shuffle()
	
	# Create unique combinations
	for i in range(number_of_names):
		var name = shuffled_1[i % shuffled_1.size()] + " " + shuffled_2[i % shuffled_2.size()]
		generated_names.append(name)


func _create_buttons():
	"""Create buttons for each group name"""
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	
	# Create new buttons
	for name in generated_names:
		var button = Button.new()
		button.text = name
		button.custom_minimum_size = Vector2(button_min_width, button_min_height)
		button.add_theme_font_size_override("font_size", button_font_size)
		button.pressed.connect(_on_button_pressed.bind(name))
		add_child(button)


func _on_button_pressed(selected_name: String):
	"""Emit signal when a name is selected"""
	name_selected.emit(selected_name)


func get_random_name() -> String:
	"""Get a random name from the generated names"""
	if generated_names.is_empty():
		return ""
	return generated_names.pick_random()
