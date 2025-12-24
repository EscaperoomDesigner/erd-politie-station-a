extends Control

# Pattern Test - Patroonherkenningstest
# Toont een sequentie met lege vakjes en een alfabet keyboard

@onready var sequence_container = %SequenceContainer
@onready var keyboard_container = %KeyboardContainer
@onready var hint_label = %HintLabel
@onready var feedback_label = %FeedbackLabel
@onready var keyboard_row1 = %Row1
@onready var keyboard_row2 = %Row2
@onready var keyboard_row3 = %Row3
@onready var timer_progress_bar = %TimerProgressBar

var current_question: QuestionData
var user_answers: Array[String] = []
var current_blank_index: int = 0
var selected_blank_index: int = -1  # Welk leeg vakje is geselecteerd
var sequence_boxes: Array = []
var current_input: String = ""  # Voor meerdere cijfers
var input_cooldown: bool = false  # Voorkom spam
var is_answering: bool = false  # Of we in feedback mode zijn

# Timer variables
var question_timer: float = 30.0
var time_remaining: float = 30.0
var timer_active: bool = false

# Hint variables
var hint_delay: float = 15.0
var hint_timer: float = 0.0
var current_hint_index: int = 0
var hint_sequence: Array[int] = []  # Indices of filled boxes to highlight in sequence
var hint_active: bool = false

const NAME_INPUT_SCENE = preload("uid://c8k5xm6yl7wvh")
const PATTERN_BOX_SCENE = preload("uid://c7kqvp4x7ejyh")

func _ready():
	# Load timer configuration
	question_timer = ConfigManager.get_question_timer()
	hint_delay = ConfigManager.get_hint_delay()
	time_remaining = question_timer
	_show_name_input()


func _process(delta: float):
	"""Update timer every frame"""
	if timer_active and not is_answering:
		time_remaining -= delta
		
		# Update progress bar (1.0 = full, 0.0 = empty)
		if timer_progress_bar:
			timer_progress_bar.value = time_remaining / question_timer
			
			# Change color based on time remaining
			if time_remaining <= question_timer * 0.25:
				# Red when less than 25% time left
				timer_progress_bar.modulate = Color(1.0, 0.3, 0.3)
			elif time_remaining <= question_timer * 0.5:
				# Yellow when less than 50% time left
				timer_progress_bar.modulate = Color(1.0, 1.0, 0.3)
			else:
				# Green when more than 50% time left
				timer_progress_bar.modulate = Color(0.3, 1.0, 0.3)
		
		# Update hint timer
		if not hint_active:
			hint_timer += delta
			if hint_timer >= hint_delay:
				_start_hint_sequence()
		
		# Time's up!
		if time_remaining <= 0:
			_on_timer_expired()


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
		# Game finished - transition to GO screen
		feedback_label.text = "Test voltooid! Alle vragen beantwoord.\nJe score: €" + str(GameManager.score)
		feedback_label.add_theme_color_override("font_color", Color.GOLD)
		keyboard_container.visible = false
		hint_label.text = ""
		timer_active = false
		if timer_progress_bar:
			timer_progress_bar.visible = false
		GameManager.end_game()
		
		# Wait 2 seconds to show final score, then go to GO screen
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/go_screen.tscn")
		return
	
	user_answers.clear()
	current_blank_index = 0
	selected_blank_index = -1
	current_input = ""
	is_answering = false  # Reset feedback mode
	feedback_label.text = ""
	hint_label.text = current_question.hint
	
	# Reset hint system
	hint_timer = 0.0
	current_hint_index = 0
	hint_active = false
	_build_hint_sequence()
	
	# Start timer
	time_remaining = question_timer
	timer_active = true
	if timer_progress_bar:
		timer_progress_bar.value = 1.0
		timer_progress_bar.modulate = Color(0.3, 1.0, 0.3)
		timer_progress_bar.visible = true
	
	# Toon alleen relevante keyboard rijen
	if current_question.uses_numbers:
		keyboard_row1.visible = false
		keyboard_row2.visible = false
		keyboard_row3.visible = true
	else:
		keyboard_row1.visible = true
		keyboard_row2.visible = true
		keyboard_row3.visible = false
	
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
	if current_question.dpad_layout:
		_setup_dpad_sequence()
	elif current_question.vertical_layout:
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
		# Check for space marker - add spacer and skip
		if current_question.sequence[i] == QuestionManager.SPACE_MARKER:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(40, 70)
			hbox.add_child(spacer)
			sequence_boxes[i] = null
			i += 1
			continue
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		hbox.add_child(vbox)
		
		for j in range(2):
			if i + j < current_question.sequence.size():
				# Check for space marker in the pair
				if current_question.sequence[i + j] == QuestionManager.SPACE_MARKER:
					sequence_boxes[i + j] = null
					break
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
		# Skip space marker entries (whitespace gaps)
		if current_question.sequence[i] == QuestionManager.SPACE_MARKER:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(40, 70)
			hbox.add_child(spacer)
			sequence_boxes[i] = null
		else:
			var box = _create_pattern_box(i)
			hbox.add_child(box)
			sequence_boxes[i] = box


func _setup_vertical_sequence():
	"""Maak verticale sequentie (rijen van boven naar beneden)"""
	# Maak een VBoxContainer voor de rijen
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	sequence_container.add_child(vbox)
	
	# Initialize sequence_boxes array with correct size
	sequence_boxes.resize(current_question.sequence.size())
	
	# Groepeer de letters per 2 (horizontaal in rijen)
	var i = 0
	while i < current_question.sequence.size():
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 120)
		vbox.add_child(hbox)
		
		for j in range(2):
			if i + j < current_question.sequence.size():
				var box = _create_pattern_box(i + j)
				hbox.add_child(box)
				sequence_boxes[i + j] = box
		
		i += 2


func _setup_dpad_sequence():
	"""Maak D-pad/cross layout (4 items per dpad: top, left, right, bottom)"""
	var main_hbox = HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 10)
	sequence_container.add_child(main_hbox)
	
	# Initialize sequence_boxes array with correct size
	sequence_boxes.resize(current_question.sequence.size())
	
	# Groepeer per 4 items (een D-pad groep)
	var i = 0
	while i < current_question.sequence.size():
		# Check for space marker - add spacer and skip
		if current_question.sequence[i] == QuestionManager.SPACE_MARKER:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(60, 70)
			main_hbox.add_child(spacer)
			sequence_boxes[i] = null
			i += 1
			continue
		
		# Create one D-pad group (cross shape)
		var dpad_container = VBoxContainer.new()
		dpad_container.alignment = BoxContainer.ALIGNMENT_CENTER
		dpad_container.add_theme_constant_override("separation", 10)
		main_hbox.add_child(dpad_container)
		
		# Row 1: Top (center aligned)
		var top_row = HBoxContainer.new()
		top_row.alignment = BoxContainer.ALIGNMENT_CENTER
		dpad_container.add_child(top_row)
		if i < current_question.sequence.size():
			var top_box = _create_pattern_box(i)
			top_row.add_child(top_box)
			sequence_boxes[i] = top_box
			i += 1
		
		# Row 2: Left, Spacer, Right
		var middle_row = HBoxContainer.new()
		middle_row.alignment = BoxContainer.ALIGNMENT_CENTER
		middle_row.add_theme_constant_override("separation", 10)
		dpad_container.add_child(middle_row)
		
		# Left
		if i < current_question.sequence.size():
			var left_box = _create_pattern_box(i)
			middle_row.add_child(left_box)
			sequence_boxes[i] = left_box
			i += 1
		
		# Center spacer (invisible, same size as box)
		var center_spacer = Control.new()
		center_spacer.custom_minimum_size = Vector2(96, 96)
		middle_row.add_child(center_spacer)
		
		# Right
		if i < current_question.sequence.size():
			var right_box = _create_pattern_box(i)
			middle_row.add_child(right_box)
			sequence_boxes[i] = right_box
			i += 1
		
		# Row 3: Bottom (center aligned)
		var bottom_row = HBoxContainer.new()
		bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
		dpad_container.add_child(bottom_row)
		if i < current_question.sequence.size():
			var bottom_box = _create_pattern_box(i)
			bottom_row.add_child(bottom_box)
			sequence_boxes[i] = bottom_box
			i += 1


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
				if button is Button:
					button.pressed.connect(_on_letter_pressed.bind(button.text))


func _select_blank(_box: PatternBox, blank_index: int):
	"""Selecteer een leeg vakje om in te vullen"""
	if input_cooldown or is_answering or current_question == null:
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
		# Alleen deselect als het nog een vraagteken is (nog niet bevestigd met Enter)
		if old_box.label.text == "?":
			old_box.set_selected(false)
		# Als het een ingevulde waarde heeft die al is bevestigd, behoud de filled style
		elif selected_blank_index < user_answers.size() and user_answers[selected_blank_index] != "":
			old_box.set_to_filled()
		else:
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
			
			# Check if this is q5 (abbcccdddd) - it has multiple blanks so don't auto-submit
			var is_multi_blank_question = current_question.question_id == "q5"
			
			# Auto-submit na 1 of 2 cijfers indien dit GEEN multi-blank vraag is
			if not is_multi_blank_question:
				# Submit immediately for single-digit or when 2 digits entered
				input_cooldown = true
				box.set_to_filled()
				
				# Sla antwoord op voor dit vakje
				while user_answers.size() <= selected_blank_index:
					user_answers.append("")
				user_answers[selected_blank_index] = current_input
				current_input = ""
				
				# Korte delay voordat we naar volgende gaan
				await get_tree().create_timer(0.2).timeout
				input_cooldown = false
				
				# Check of alle vakjes zijn ingevuld
				var all_filled = true
				for i in range(current_question.blank_positions.size()):
					if i >= user_answers.size() or user_answers[i].is_empty():
						all_filled = false
						break
				
				if all_filled:
					_check_answer()
				else:
					# Selecteer volgende lege vakje
					var next_empty = _find_next_empty_blank()
					if next_empty >= 0:
						var next_blank_pos = current_question.blank_positions[next_empty]
						var next_box = sequence_boxes[next_blank_pos] as PatternBox
						_select_blank(next_box, next_empty)
			else:
				# Voor multi-blank vraag (q5): handmatige submit na alle vakjes ingevuld
				# Check if we've filled all blanks
				var all_filled = true
				for i in range(current_question.blank_positions.size()):
					if i == selected_blank_index:
						continue  # Skip current one being filled
					if i >= user_answers.size() or user_answers[i].is_empty():
						all_filled = false
						break
				
				# Save current answer
				while user_answers.size() <= selected_blank_index:
					user_answers.append("")
				user_answers[selected_blank_index] = current_input
				box.set_to_filled()
				current_input = ""
				
				if all_filled:
					# All blanks filled, check answer
					input_cooldown = true
					await get_tree().create_timer(0.2).timeout
					input_cooldown = false
					_check_answer()
				else:
					# Move to next blank
					var next_empty = _find_next_empty_blank()
					if next_empty >= 0:
						var next_blank_pos = current_question.blank_positions[next_empty]
						var next_box = sequence_boxes[next_blank_pos] as PatternBox
						_select_blank(next_box, next_empty)
	else:
		# Voor letters: direct invullen (1 letter per blank)
		input_cooldown = true
		box.update_value(letter)
		box.set_to_filled()
		
		# Sla antwoord op voor dit vakje
		while user_answers.size() <= selected_blank_index:
			user_answers.append("")
		user_answers[selected_blank_index] = letter
		
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
			_check_answer()


func _find_next_empty_blank() -> int:
	"""Vind de volgende lege blank positie"""
	for i in range(current_question.blank_positions.size()):
		if i >= user_answers.size() or user_answers[i].is_empty():
			return i
	return -1


func _check_answer():
	"""Check of het antwoord correct is"""
	is_answering = true  # Blokkeer input tijdens feedback
	timer_active = false  # Stop timer
	
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
		# No negative points - just move to next question
	
	# Wacht 1.5 seconden en ga dan naar volgende vraag
	await get_tree().create_timer(1.5).timeout
	is_answering = false  # Herblokkeer voor volgende vraag
	load_next_question()


func _on_timer_expired():
	"""Called when timer runs out"""
	timer_active = false
	is_answering = true
	
	feedback_label.text = "Tijd op! Het juiste antwoord was: " + ", ".join(current_question.correct_answers)
	feedback_label.add_theme_color_override("font_color", Color.ORANGE)
	
	# No penalty for timeout, just move to next question
	await get_tree().create_timer(1.5).timeout
	is_answering = false
	load_next_question()


func _build_hint_sequence():
	"""Build the sequence of filled boxes to highlight as hints"""
	hint_sequence.clear()
	
	if current_question == null:
		return
	
	# Check if question has custom hint sequence
	if not current_question.hint_sequence.is_empty():
		# Use custom hint sequence from question
		hint_sequence = current_question.hint_sequence.duplicate()
		return
	
	# Otherwise, auto-generate: find all filled (non-blank) boxes in order
	for i in range(current_question.sequence.size()):
		# Skip if this is a blank position or space marker
		if i in current_question.blank_positions:
			continue
		if current_question.sequence[i] == QuestionManager.SPACE_MARKER:
			continue
		
		# Add this filled box to the hint sequence
		hint_sequence.append(i)


func _start_hint_sequence():
	"""Start showing hints by highlighting filled boxes in sequence"""
	if hint_active or hint_sequence.is_empty():
		return
	
	hint_active = true
	current_hint_index = 0
	_show_next_hint()


func _show_next_hint():
	"""Show the next hint by turning the next filled box green"""
	if current_hint_index >= hint_sequence.size():
		return  # All hints shown
	
	var box_index = hint_sequence[current_hint_index]
	
	# Check if this is a special "force single" marker (next value is -1)
	var force_single = false
	if current_hint_index + 1 < hint_sequence.size() and hint_sequence[current_hint_index + 1] == -1:
		force_single = true
	
	var box = sequence_boxes[box_index] as PatternBox
	
	if box != null:
		box.set_hint_color()
	
	current_hint_index += 1
	
	# Skip the -1 marker if present
	if force_single:
		current_hint_index += 1
	# Otherwise, check if we should show pairs (2 at once) based on question flag
	elif current_hint_index < hint_sequence.size() and current_question != null and current_question.hint_show_pairs:
		var next_box_index = hint_sequence[current_hint_index]
		
		# Don't pair if next is also a -1 marker
		if next_box_index != -1:
			var next_box = sequence_boxes[next_box_index] as PatternBox
			
			if next_box != null:
				next_box.set_hint_color()
				current_hint_index += 1
	
	# Schedule next hint (1 second interval between each green highlight)
	if current_hint_index < hint_sequence.size():
		await get_tree().create_timer(1.0).timeout
		_show_next_hint()
