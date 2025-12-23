extends Node

# QuestionManager - Beheert alle vragen voor de cognitietest
# Voeg hier gemakkelijk nieuwe vragen toe!

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
	all_questions.append(QuestionData.new(
		"q1",
		["M", "G", "N", "G", "O", "G", "", ""],
		[6, 7],
		["P", "G"],
		1,
		"Let op het patroon: elke tweede letter is een G"
	))
	
	# Vraag 2: A, C, E, _, I, _
	# Patroon: Overslaan van 1 letter
	all_questions.append(QuestionData.new(
		"q2",
		["A", "C", "E", "", "I", ""],
		[3, 5],
		["G", "K"],
		1,
		"Spring telkens een letter over"
	))
	
	# Vraag 3: Z, Y, X, _, V, _
	# Patroon: Alfabetisch achteruit
	all_questions.append(QuestionData.new(
		"q3",
		["Z", "Y", "X", "", "V", ""],
		[3, 5],
		["W", "U"],
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
	all_questions.append(QuestionData.new(
		"q4",
		["W", "P", "S", "L", "O", "H", "", ""],
		[6, 7],
		["K", "D"],
		2,
		"Lees elke kolom van boven naar beneden",
		true  # vertical_layout = true
	))
	
	# SECTIE 2: Herhalings patronen
	
	# Vraag 5: A, B, B, C, C, C, _, _, _, _
	# Patroon: A 1x, B 2x, C 3x, D 4x
	all_questions.append(QuestionData.new(
		"q5",
		["A", "B", "B", "C", "C", "C", "", "", "", ""],
		[6, 7, 8, 9],
		["D", "D", "D", "D"],
		2,
		"Elke letter verschijnt vaker dan de vorige"
	))
	
	# SECTIE 3: Cijfer patronen
	
	# Vraag 6: 1, 1, 2, 3, 5, _, 13, _
	# Patroon: Fibonacci (elke getal is som van vorige twee)
	all_questions.append(QuestionData.new(
		"q6",
		["1", "1", "2", "3", "5", "", "13", ""],
		[5, 7],
		["8", "21"],
		3,
		"Som van de twee vorige getallen",
		false,  # vertical_layout
		false,  # single_row
		true    # uses_numbers = true
	))
	
	# Vraag 7: H i j ? en t s r ?
	# Rij 1 (vooruit): H, i, j, k
	# Rij 2 (achteruit): t, s, r, q
	all_questions.append(QuestionData.new(
		"q7",
		["H", "T", "I", "S", "J", "R", "", ""],
		[6, 7],
		["K", "Q"],
		2,
		"Bovenste rij: vooruit, onderste rij: achteruit",
		false  # vertical_layout = true
	))
	
	# Vraag 8: egiywuk -> k, u, _, y, _, g, e
	# Toon eerst het woord, dan de puzzel (gespiegeld)
	all_questions.append(QuestionData.new(
		"q8",
		["E", "G", "I", "Y", "W", "U", "K", "   ", "K", "U", "", "Y", "", "G", "E"],
		[10, 12],
		["W", "I"],
		2,
		"Spiegel het woord naar rechts",
		false,  # vertical_layout
		true,   # single_row = true voor één lange rij
		false   # uses_numbers
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
