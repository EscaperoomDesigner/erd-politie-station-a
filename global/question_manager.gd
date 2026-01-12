extends Node

# QuestionManager - Beheert alle vragen voor de cognitietest
# Voeg hier gemakkelijk nieuwe vragen toe!

const SPACE_MARKER = "__SPACE__"  # Special marker voor whitespace gaps

var all_questions: Array[QuestionData] = []
var available_questions: Array[QuestionData] = []
var current_question_index: int = 0


func _ready():
	_load_questions()
	_reset_available_questions()


func _load_questions():
	"""Hier voeg je alle vragen toe - super makkelijk!"""
	all_questions.clear()
	
	# SECTIE 1: Eenvoudige patronen
	
	# Vraag 1: M, G, N, G, O, G, _, _
	# Patroon: Oneven posities = M,N,O,P,Q... / Even posities = altijd G
	# Hint: Show progressing letters first (M,N,O), then the constant G's
	all_questions.append(QuestionData.new(
		"q1",
		["M", "G", SPACE_MARKER, "N", "G", SPACE_MARKER, "O", "G", SPACE_MARKER, "", ""],
		[9, 10],
		["P", "G"],
		1,
		"Let op het patroon: elke tweede letter is een G",
		false,  # vertical_layout
		false,  # single_row
		false,  # dpad_layout
		false,  # uses_numbers
		[0, 3, 6, 1, 4, 7]  # hint_sequence: First show M,N,O (0,3,6), then G's (1,4,7)
	))
	
	# Vraag 2: A, C, E, _, I, _
	# Patroon: Overslaan van 1 letter
	all_questions.append(QuestionData.new(
		"q2",
		["A", "C", "E", "G", "I", ""],
		[5],
		["K"],
		1,
		"Spring telkens een letter over",
		false,  # vertical_layout
		true    # single_row
	))
	
	# Vraag 3: Z, Y, X, _, V, _
	# Patroon: Alfabetisch achteruit
	all_questions.append(QuestionData.new(
		"q3",
		["Z", "Y", SPACE_MARKER, "X", "W", SPACE_MARKER, "V", ""],
		[7],
		["U"],
		1,
		"Het alfabet achterstevoren"
	))
	
	# Vraag 4: Verticaal patroon in 2 kolommen
	# Kolom 1 (boven naar beneden): W -> S -> O -> K (telkens -4)
	# Kolom 2 (boven naar beneden): P -> L -> H -> D (telkens -4)
	# Visueel:  W  P
	#           S  L
	#           O  H
	#           ?  ?
	# Hint: Show left column top to bottom, then right column top to bottom
	all_questions.append(QuestionData.new(
		"q4",
		["W", "P", "S", "L", "O", "H", "K", ""],
		[7],
		["D"],
		2,
		"Lees elke kolom van boven naar beneden",
		true,   # vertical_layout = true
		false,  # single_row
		false,  # dpad_layout
		false,  # uses_numbers
		[0, 2, 4, 6, 1, 3, 5]  # hint_sequence: Left column (W,S,O,K), then right column (P,L,H)
	))
	
	# SECTIE 2: Herhalings patronen
	
	# Vraag 5: A, B, B, C, C, C, _, _, _, _
	# Patroon: A 1x, B 2x, C 3x, D 4x
	# Hint: Show each unique letter with a different color (A=color1, B=color2, C=color3, D=color4)
	all_questions.append(QuestionData.new(
		"q5",
		["A", "B", "B", "C", "C", "C", "D", "", "", ""],
		[7, 8, 9],
		["D", "D", "D"],
		2,
		"Elke letter verschijnt vaker dan de vorige",
		false,  # vertical_layout
		false,  # single_row
		false,  # dpad_layout
		false,  # uses_numbers
		[0, 1, 2, 3, 4, 5, 6],  # hint_sequence: Show all in order
		false,  # hint_show_pairs
		false,  # hint_flash_back
		true    # hint_color_per_value = change color when value changes
	))
	
	# SECTIE 3: Cijfer patronen
	
	# Vraag 6: 1, 1, 2, 3, 5, _, 13, 21
	# Patroon: Fibonacci (elke getal is som van vorige twee)
	# Hint: Show pairs that add up: 1+1 (green), 1+2 (cyan), 2+3 (yellow), 3+5 (magenta)
	all_questions.append(QuestionData.new(
		"q6",
		["1", "1", "2", "3", "5", "", "13", "21"],
		[5],
		["8"],
		3,
		"Som van de twee vorige getallen",
		false,  # vertical_layout
		true,   # single_row
		false,  # dpad_layout
		true,   # uses_numbers
		[0, 1, 1, 2, 2, 3, 3, 4],  # hint_sequence: Show pairs: 1+1 (green), 1+2 (cyan), 2+3 (yellow), 3+5 (magenta)
		true    # hint_show_pairs = show additions in pairs with different colors
	))
	
	# Vraag 7: H i j ? en t s r ?
	# Rij 1 (vooruit): H, i, j, k
	# Rij 2 (achteruit): t, s, r, q
	# Hint: Show top row first (H,I,J,K forward), then bottom row (T,S,R backward)
	all_questions.append(QuestionData.new(
		"q7",
		["H", "T", "I", "S", "J", "R", "K", ""],
		[7],
		["Q"],
		2,
		"Bovenste rij: vooruit, onderste rij: achteruit",
		false,  # vertical_layout = true
		false,  # single_row
		false,  # dpad_layout
		false,  # uses_numbers
		[0, 2, 4, 6, 1, 3, 5]  # hint_sequence: Top row (H,I,J,K), then bottom row (T,S,R)
	))
	
	# Vraag 8: egiywuk -> k, u, w, y, _, g, e
	# Toon eerst het woord, dan de puzzel (gespiegeld)
	# Hint: Show pairs simultaneously - both K's, then both U's, etc. (mirror pattern)
	all_questions.append(QuestionData.new(
		"q8",
		["E", "G", "I", "Y", "W", "U", "K", SPACE_MARKER, "K", "U", "W", "Y", "", "G", "E"],
		[12],
		["I"],
		2,
		"Spiegel het woord naar rechts",
		false,  # vertical_layout
		true,   # single_row = true voor één lange rij
		false,  # dpad_layout
		false,  # uses_numbers
		[6, 8, 5, 9, 4, 10, 3, 11, 2, -1, 1, 13, 0, 14],  # hint_sequence: K-K, U-U, W-W, Y-Y, I(alone with -1 marker), G-G, E-E
		true    # hint_show_pairs = true (show 2 at once, except for I which has -1 marker)
	))
	
	# Vraag 9: C F / T R, H K / O M, M ? / J ?
	# Patroon in squares: Top row: +3, +2, +3, +2 = C(2), F(5), H(7), K(10), M(12), P(15)
	# Bottom row: -2, -3, -2, -3 = T(19), R(17), O(14), M(12), J(9), H(7)
	# Hint: Show top row sequence, then bottom row to reveal both patterns
	all_questions.append(QuestionData.new(
		"q9",
		["C", "T", "F", "R", SPACE_MARKER, "H", "O", "K", "M", SPACE_MARKER, "M", "J", "P", ""],
		[13],
		["H"],
		3,
		"Zoek het patroon in de rijen van elk vierkant",
		false,  # vertical_layout
		false,  # single_row
		false,  # dpad_layout
		false,  # uses_numbers
		[0, 2, 5, 7, 10, 12, 1, 3, 6, 8, 11]  # hint_sequence: Top row (C,F,H,K,M,P), then bottom row (T,R,O,M,J)
	))
	
	# Vraag 10: 3, 5, 7, 9, 11, _
	# Patroon: +2 elke keer (oneven getallen)
	# Hint: Flash each number twice to emphasize the +2 pattern
	all_questions.append(QuestionData.new(
		"q10",
		["3", "5", "7", "", "11", "13"],
		[3],
		["9"],
		1,
		"Telkens +2",
		false,  # vertical_layout
		true,   # single_row = true
		false,  # dpad_layout
		true,   # uses_numbers = true
		[0, 0, 1, 1, 2, 2, 4, 4, 5, 5],  # hint_sequence: Flash each number twice
		false,   # hint_show_pairs = true (show 2 at once - each number will blink twice)
		true    # hint_flash_back = true (hints flash back to white for blink effect)
	))
	
	# Vraag 11: D-pad pattern - Left = Top × Right × Bottom
	# First dpad: 24 = 4 × 3 × 2
	# Second dpad: 42 = 7 × 2 × 3
	# Third dpad: ? = 3 × 2 × 1 = 6
	# Hint: Show operands (bottom, right, top) in green, then result (center) in different color
	all_questions.append(QuestionData.new(
		"q11",
		["4", "24", "3", "2", SPACE_MARKER, "7", "42", "2", "3", SPACE_MARKER, "3", "", "2", "1"],
		[11],
		["6"],
		3,
		"Links = Boven × Rechts × Beneden",
		false,  # vertical_layout
		false,  # single_row
		true,   # dpad_layout = true
		true,   # uses_numbers
		[3, 2, 0, 1, 8, 7, 5, 6, 13, 12, 10],  # hint_sequence: bottom, right, top, center for each dpad
		false,  # hint_show_pairs
		false,  # hint_flash_back
		false,  # hint_color_per_value
		[3, 1, 3, 1, 3]  # hint_color_groups: 3 operands (green), 1 result (cyan), repeat for each dpad
	))
	
	# Vraag 12: Twee rijen - onderste is bovenste × 11
	# Boven: 3, 5, 8, 4, 1, 9, ?
	# Onder: 33, 55, 88, 44, 11, 99, 77
	# Patroon: elk getal boven wordt × 11 (gedupliceerd) onder
	all_questions.append(QuestionData.new(
		"q12",
		["3", "33", "5", "55", "8", "88", "4", "44", "1", "11", "9", "99", "", "77"],
		[12],
		["7"],
		2,
		"Vergelijk de bovenste en onderste rij",
		false,  # vertical_layout
		false,  # single_row
		false,  # dpad_layout
		true    # uses_numbers
	))
	
	# Vraag 13: A C B D, H O K M, I K ? ?
	# Patroon in squares: EACH SQUARE ABCD EFGH IJKL
	# Hint: Show top row sequence, then bottom row to reveal both patterns
	all_questions.append(QuestionData.new(
		"q9",
		["A", "D", "C", "B", SPACE_MARKER, "E", "H", "G", "F", SPACE_MARKER, "I", "L", "K", ""],
		[13],
		["J"],
		3,
		"Combineer de patronen in elk vierkant",
		false,  # vertical_layout
		false,  # single_row
		false,  # dpad_layout
		false,  # uses_numbers
		[0, 3, 2, 1, 5, 8, 7, 6, 10, -1, 12, 11] 
	))

	print("Loaded ", all_questions.size(), " questions")


func get_question(index: int) -> QuestionData:
	"""Haal een specifieke vraag op"""
	if index >= 0 and index < all_questions.size():
		return all_questions[index]
	return null


func get_random_question() -> QuestionData:
	"""Haal een willekeurige vraag op die nog niet is geweest"""
	if available_questions.is_empty():
		# Alle vragen zijn beantwoord - geef null terug
		return null
	
	# Kies random vraag uit beschikbare vragen
	var random_index = randi() % available_questions.size()
	var question = available_questions[random_index]
	
	# Verwijder deze vraag uit beschikbare vragen
	available_questions.remove_at(random_index)
	
	return question


func _reset_available_questions():
	"""Reset de beschikbare vragen lijst"""
	available_questions.clear()
	available_questions = all_questions.duplicate()
	print("Questions reset - ", available_questions.size(), " questions available")


func get_next_question() -> QuestionData:
	"""Haal de volgende vraag op (sequentieel)"""
	var question = get_question(current_question_index)
	current_question_index = (current_question_index + 1) % all_questions.size()
	return question


func get_questions_by_difficulty(difficulty: int) -> Array[QuestionData]:
	"""Haal alle vragen van een bepaalde moeilijkheidsgraad"""
	var filtered: Array[QuestionData] = []
	for q in all_questions:
		if q.difficulty == difficulty:
			filtered.append(q)
	return filtered


func reset():
	"""Reset de vraag index en beschikbare vragen"""
	current_question_index = 0
	_reset_available_questions()


# ======================================
# HOE NIEUWE VRAGEN TOEVOEGEN:
# ======================================
# 
# all_questions.append(QuestionData.new(
#     "unieke_id",                    # Een unieke ID voor de vraag
#     ["A", "B", "", "D"],            # De sequentie (gebruik "" voor lege vakjes)
#     [2],                            # Welke posities leeg zijn (0-based index)
#     ["C"],                          # De juiste antwoorden
#     1,                              # Moeilijkheid (1=makkelijk, 2=normaal, 3=moeilijk)
#     "Een optionele hint"            # Hint tekst
# ))
#
