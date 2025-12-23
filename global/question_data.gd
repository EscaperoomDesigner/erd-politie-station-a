extends Resource
class_name QuestionData

# Question data structure voor patroonherkenning vragen
# Gebruik dit om gemakkelijk nieuwe vragen toe te voegen

@export var question_id: String = ""
@export var sequence: Array[String] = []  # De getoonde letters/cijfers
@export var blank_positions: Array[int] = []  # Welke posities leeg zijn (0-based)
@export var correct_answers: Array[String] = []  # De juiste antwoorden voor de lege posities
@export var difficulty: int = 1  # 1 = makkelijk, 2 = normaal, 3 = moeilijk
@export var hint: String = ""  # Optionele hint
@export var vertical_layout: bool = false  # True = rijen van boven naar beneden, False = horizontaal
@export var single_row: bool = false  # True = één enkele horizontale rij zonder groepering
@export var uses_numbers: bool = false  # True = toon alleen cijfers, False = toon alleen letters


func _init(
	p_id: String = "",
	p_sequence: Array[String] = [],
	p_blank_positions: Array[int] = [],
	p_correct_answers: Array[String] = [],
	p_difficulty: int = 1,
	p_hint: String = "",
	p_vertical_layout: bool = false,
	p_single_row: bool = false,
	p_uses_numbers: bool = false
):
	question_id = p_id
	sequence = p_sequence
	blank_positions = p_blank_positions
	correct_answers = p_correct_answers
	difficulty = p_difficulty
	hint = p_hint
	vertical_layout = p_vertical_layout
	single_row = p_single_row
	uses_numbers = p_uses_numbers
