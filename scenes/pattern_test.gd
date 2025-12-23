extends Control

# Pattern Test - Patroonherkenningstest
# Toont een sequentie met lege vakjes en een alfabet keyboard

@onready var sequence_container = %SequenceContainer
@onready var keyboard_container = %KeyboardContainer
@onready var hint_label = %HintLabel
@onready var feedback_label = %FeedbackLabel
@onready var next_button = %NextButton
@onready var reset_button = %ResetButton
@onready var keyboard_row1 = %Row1
@onready var keyboard_row2 = %Row2
@onready var keyboard_row3 = %Row3
@onready var enter_button = %EnterButton

var current_question: QuestionData
var user_answers: Array[String] = []
var current_blank_index: int = 0
var selected_blank_index: int = -1  # Welk leeg vakje is geselecteerd
var sequence_boxes: Array = []
var current_input: String = ""  # Voor meerdere cijfers
var input_cooldown: bool = false  # Voorkom spam
var is_answering: bool = false  # Of we in feedback mode zijn

const NAME_INPUT_SCENE = preload("uid://c8k5xm6yl7wvh")
const PATTERN_BOX_SCENE = preload("uid://c7kqvp4x7ejyh")

func _ready():
	next_button.pressed.connect(_on_next_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	_show_name_input()


func _show_name_input():
	"""Toon het naam invoer scherm"""
	visible = false
	var name_input = NAME_INPUT_SCENE.instantiate()
	name_input.name_confirmed.connect(_on_name_confirmed)
	get_parent().add_child.call_deferred(name_input)


func _on_name_confirmed(_player_name: String):
	"""Start de test nadat naam is ingevuld"""
	visible = true
	GameManager.start_game()  # Start de game
	_setup_keyboard()
	load_next_question()


func load_next_question():
	"""Laad de volgende vraag"""
	current_question = QuestionManager.get_random_question()
	
	if current_question == null:
		feedback_label.text = "Test voltooid! Alle vragen beantwoord.\nJe score: " + str(GameManager.score)
		feedback_label.add_theme_color_override("font_color", Color.GOLD)
		keyboard_container.visible = false
		hint_label.text = ""
		GameManager.end_game()
		return
	
	user_answers.clear()
	current_blank_index = 0
	selected_blank_index = -1
	current_input = ""
	is_answering = false  # Reset feedback mode
	feedback_label.text = ""
	reset_button.visible = false
	next_button.visible = false
	hint_label.text = current_question.hint
	
	# Toon alleen relevante keyboard rijen
	if current_question.uses_numbers:
		keyboard_row1.visible = false
		keyboard_row2.visible = false
		keyboard_row3.visible = true
		if enter_button:
			enter_button.visible = true
	else:
		keyboard_row1.visible = true
		keyboard_row2.visible = true
		keyboard_row3.visible = false
		if enter_button:
			enter_button.visible = false
	
	_setup_sequence()
	
	# Selecteer automatisch eerste lege vakje
	if not current_question.blank_positions.is_empty():
		var first_blank_pos = current_question.blank_positions[0]
		var first_box = sequence_boxes[first_blank_pos] as PatternBox
		_select_blank(first_box, 0)


func _setup_sequence():
	"""Maak de sequentie boxes"""
	# Clear oude boxes
	for child in sequence_container.get_children():
		child.queue_free()
	sequence_boxes.clear()
	
	# Check of deze vraag verticaal moet worden weergegeven
	if current_question.vertical_layout:
		_setup_vertical_sequence()
	elif current_question.single_row:
		_setup_single_row_sequence()
	else:
		_setup_horizontal_sequence()


func _setup_horizontal_sequence():
	"""Maak horizontale sequentie (standaard)"""
	# Maak een HBoxContainer voor de kolommen
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	sequence_container.add_child(hbox)
	
	# Initialize sequence_boxes array with correct size
	sequence_boxes.resize(current_question.sequence.size())
	
	# Groepeer de letters per 2 (verticaal in kolommen)
	var i = 0
	while i < current_question.sequence.size():
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		hbox.add_child(vbox)
		
		for j in range(2):
			if i + j < current_question.sequence.size():
				var box = _create_pattern_box(i + j)
				vbox.add_child(box)
				sequence_boxes[i + j] = box
		
		i += 2


func _setup_single_row_sequence():
	"""Maak één enkele horizontale rij zonder groepering"""
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	sequence_container.add_child(hbox)
	
	# Initialize sequence_boxes array with correct size
	sequence_boxes.resize(current_question.sequence.size())
	
	# Voeg alle boxes toe in één enkele rij
	for i in range(current_question.sequence.size()):
		var box = _create_pattern_box(i)
		hbox.add_child(box)
		sequence_boxes[i] = box


func _setup_vertical_sequence():
	"""Maak verticale sequentie (rijen van boven naar beneden)"""
	# Maak een VBoxContainer voor de rijen
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	sequence_container.add_child(vbox)
	
	# Initialize sequence_boxes array with correct size
	sequence_boxes.resize(current_question.sequence.size())
	
	# Groepeer de letters per 2 (horizontaal in rijen)
	var i = 0
	while i < current_question.sequence.size():
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(hbox)
		
		for j in range(2):
			if i + j < current_question.sequence.size():
				var box = _create_pattern_box(i + j)
				hbox.add_child(box)
				sequence_boxes[i + j] = box
		
		i += 2


func _create_pattern_box(index: int) -> PatternBox:
	"""Maak een box voor een letter in de sequentie"""
	var box = PATTERN_BOX_SCENE.instantiate() as PatternBox
	
	# Check of dit een lege positie is
	if index in current_question.blank_positions:
		box.setup_as_blank(index)
		var blank_idx = current_question.blank_positions.find(index)
		box.box_pressed.connect(_select_blank.bind(blank_idx))
	else:
		box.setup_as_filled(index, current_question.sequence[index])
	
	return box


func _setup_keyboard():
	"""Setup keyboard button connections"""
	# Verbind alle letter buttons
	for child in keyboard_container.get_children():
		if child is HBoxContainer:
			for button in child.get_children():
				if button is Button and button != enter_button:
					button.pressed.connect(_on_letter_pressed.bind(button.text))
	
	# Verbind enter button
	if enter_button:
		enter_button.pressed.connect(_on_enter_pressed)


func _select_blank(_box: PatternBox, blank_index: int):
	"""Selecteer een leeg vakje om in te vullen"""
	if input_cooldown or is_answering:
		return  # Voorkom spam tijdens input of feedback
	
	if blank_index < 0 or blank_index >= current_question.blank_positions.size():
		return
	
	# Als dit vakje al geselecteerd is, doe niks
	if selected_blank_index == blank_index:
		return
	
	# Update oude selectie terug naar normale style
	if selected_blank_index >= 0:
		var old_pos = current_question.blank_positions[selected_blank_index]
		var old_box = sequence_boxes[old_pos] as PatternBox
		if old_box.label.text == "?" or current_question.uses_numbers:
			old_box.set_selected(false)
	
	# Selecteer nieuwe
	selected_blank_index = blank_index
	current_input = ""
	
	# Highlight geselecteerde box met dikke groene border
	var blank_pos = current_question.blank_positions[blank_index]
	var box = sequence_boxes[blank_pos] as PatternBox
	box.set_selected(true)
	
	# Reset de text als het een cijfer vraag is
	if current_question.uses_numbers:
		box.update_value("?")
		# Verberg OK knop totdat er iets is ingevuld
		if enter_button:
			enter_button.visible = false


func _on_letter_pressed(letter: String):
	"""Wanneer een letter/cijfer wordt gekozen"""
	if input_cooldown or is_answering:
		return  # Voorkom spam of input tijdens feedback
	
	if selected_blank_index < 0 or selected_blank_index >= current_question.blank_positions.size():
		return  # Geen vakje geselecteerd
	
	var blank_pos = current_question.blank_positions[selected_blank_index]
	var box = sequence_boxes[blank_pos] as PatternBox
	
	if current_question.uses_numbers:
		# Voor cijfers: voeg toe aan huidige input (max 2 cijfers)
		if current_input.length() < 2:
			current_input += letter
			box.update_value(current_input)
			
			reset_button.visible = true
			
			# Toon OK knop alleen als alle vakjes een waarde hebben
			_update_enter_button_visibility()
	else:
		# Voor letters: direct invullen (1 letter per blank)
		input_cooldown = true
		box.update_value(letter)
		box.set_to_filled()
		
		# Sla antwoord op voor dit vakje
		while user_answers.size() <= selected_blank_index:
			user_answers.append("")
		user_answers[selected_blank_index] = letter
		
		reset_button.visible = true
		
		# Korte delay voordat we naar volgende gaan (voorkom spam)
		await get_tree().create_timer(0.2).timeout
		input_cooldown = false
		
		# Selecteer volgende lege vakje of check antwoorden
		var next_empty = _find_next_empty_blank()
		if next_empty >= 0:
			var next_blank_pos = current_question.blank_positions[next_empty]
			var next_box = sequence_boxes[next_blank_pos] as PatternBox
			_select_blank(next_box, next_empty)
		else:
			reset_button.visible = false
			_check_answer()


func _find_next_empty_blank() -> int:
	"""Vind de volgende lege blank positie"""
	for i in range(current_question.blank_positions.size()):
		if i >= user_answers.size() or user_answers[i].is_empty():
			return i
	return -1


func _update_enter_button_visibility():
	"""Update OK knop zichtbaarheid - toon alleen als er input is"""
	if not current_question.uses_numbers or not enter_button:
		return
	
	# Toon OK knop als huidige vakje niet leeg is
	if not current_input.is_empty():
		enter_button.visible = true
	else:
		enter_button.visible = false


func _on_enter_pressed():
	"""Wanneer ENTER/OK wordt ingedrukt voor cijfers"""
	if not current_question.uses_numbers:
		return  # Alleen voor cijfer vragen
	
	if selected_blank_index < 0 or current_input.is_empty():
		return  # Niets ingevuld
	
	if input_cooldown or is_answering:
		return
	
	# Sla antwoord op voor dit vakje
	while user_answers.size() <= selected_blank_index:
		user_answers.append("")
	user_answers[selected_blank_index] = current_input
	
	var blank_pos = current_question.blank_positions[selected_blank_index]
	var box = sequence_boxes[blank_pos] as PatternBox
	box.set_to_filled()
	
	# Selecteer volgende lege vakje of check antwoorden
	var next_empty = _find_next_empty_blank()
	if next_empty >= 0:
		var next_blank_pos = current_question.blank_positions[next_empty]
		var next_box = sequence_boxes[next_blank_pos] as PatternBox
		_select_blank(next_box, next_empty)
	else:
		reset_button.visible = false
		_check_answer()


func _on_reset_button_pressed():
	"""Reset ALLE vakjes naar de beginstate"""
	# Clear alle antwoorden
	user_answers.clear()
	current_input = ""
	
	# Reset alle lege vakjes terug naar vraagteken
	for blank_idx in range(current_question.blank_positions.size()):
		var blank_pos = current_question.blank_positions[blank_idx]
		var box = sequence_boxes[blank_pos] as PatternBox
		box.reset_to_blank()
	
	# Selecteer eerste vakje opnieuw
	if not current_question.blank_positions.is_empty():
		var first_blank_pos = current_question.blank_positions[0]
		var first_box = sequence_boxes[first_blank_pos] as PatternBox
		_select_blank(first_box, 0)


func _check_answer():
	"""Check of het antwoord correct is"""
	is_answering = true  # Blokkeer input tijdens feedback
	
	var correct = true
	
	for i in range(user_answers.size()):
		if user_answers[i] != current_question.correct_answers[i]:
			correct = false
			break
	
	if correct:
		feedback_label.text = "Correct!"
		feedback_label.add_theme_color_override("font_color", Color.GREEN)
		GameManager.add_score(100)
	else:
		feedback_label.text = "Fout! Het juiste antwoord was: " + ", ".join(current_question.correct_answers)
		feedback_label.add_theme_color_override("font_color", Color.RED)
		GameManager.add_score(-50)
	
	# Wacht 1.5 seconden en ga dan naar volgende vraag
	await get_tree().create_timer(1.5).timeout
	is_answering = false  # Herblokkeer voor volgende vraag
	load_next_question()


func _on_next_button_pressed():
	"""Ga naar de volgende vraag"""
	load_next_question()
