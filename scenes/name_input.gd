extends Control

# Name Input - Kies een random groepsnaam

signal name_confirmed(player_name: String)

@onready var buttons_container = $VBoxContainer/ButtonsContainer

var word_list_1 = [
	"Snelle", "Slimme", "Sterke", "Stoere", "Dappere", 
	"Grappige", "Wilde", "Coole", "Vrolijke", "Geweldige"
]

var word_list_2 = [
	"Agenten", "Helden", "Champions", "Detectives", "Experts",
	"Tigers", "Eagles", "Ninjas", "Dragons", "Warriors"
]

var generated_names: Array[String] = []


func _ready():
	_generate_names()
	_create_buttons()


func _generate_names():
	"""Genereer 5 random groepsnamen"""
	generated_names.clear()
	
	# Shuffle de lijsten
	var shuffled_1 = word_list_1.duplicate()
	var shuffled_2 = word_list_2.duplicate()
	shuffled_1.shuffle()
	shuffled_2.shuffle()
	
	# Maak 5 unieke combinaties
	for i in range(5):
		var name = shuffled_1[i % shuffled_1.size()] + " " + shuffled_2[i % shuffled_2.size()]
		generated_names.append(name)


func _create_buttons():
	"""Maak buttons voor elke groepsnaam"""
	for name in generated_names:
		var button = Button.new()
		button.text = name
		button.custom_minimum_size = Vector2(0, 60)
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(_on_name_selected.bind(name))
		buttons_container.add_child(button)


func _on_name_selected(selected_name: String):
	GameManager.set_player_name(selected_name)
	name_confirmed.emit(selected_name)
	queue_free()
