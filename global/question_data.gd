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
@export var hint_sequence: Array[int] = []  # Indices of filled boxes to highlight green (in order). Empty = auto-generate
@export var hint_show_pairs: bool = false  # True = show hints 2 at a time, False = show one at a time
@export var vertical_layout: bool = false  # True = rijen van boven naar beneden, False = horizontaal
@export var single_row: bool = false  # True = één enkele horizontale rij zonder groepering
@export var dpad_layout: bool = false  # True = D-pad/cross layout (top, left, right, bottom per group)
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
	p_dpad_layout: bool = false,
	p_uses_numbers: bool = false,
	p_hint_sequence: Array[int] = [],
	p_hint_show_pairs: bool = false
):
	question_id = p_id
	sequence = p_sequence
	blank_positions = p_blank_positions
	correct_answers = p_correct_answers
	difficulty = p_difficulty
	hint = p_hint
	vertical_layout = p_vertical_layout
	single_row = p_single_row
	dpad_layout = p_dpad_layout
	uses_numbers = p_uses_numbers
	hint_sequence = p_hint_sequence
	hint_show_pairs = p_hint_show_pairs
