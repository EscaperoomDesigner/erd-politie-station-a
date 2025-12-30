extends PanelContainer
class_name PatternBox

# Pattern box component voor sequentie weergave

signal box_pressed(box: PatternBox)

var label: Label
var button: Button

var sequence_index: int = -1
var is_blank: bool = false
var is_selected: bool = false

# Styles
var blank_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var filled_style: StyleBoxFlat

# Theme colors
var blank_text_color: Color = Color(0.5, 0.5, 0.5)
var filled_text_color: Color = Color.WHITE


func _ready():
	# Get node references
	label = $Label if has_node("Label") else null
	button = $Button if has_node("Button") else null
	
	# Load styles from theme or create defaults
	_load_theme_styles()
	
	# Connect button if it exists
	if button:
		button.pressed.connect(_on_button_pressed)



func _load_theme_styles():
	"""Load styles from theme or use defaults"""
	# Try to get styles from theme first
	if has_theme_stylebox("blank", "PatternBox"):
		blank_style = get_theme_stylebox("blank", "PatternBox")
	else:
		blank_style = _create_blank_style()
	
	if has_theme_stylebox("selected", "PatternBox"):
		selected_style = get_theme_stylebox("selected", "PatternBox")
	else:
		selected_style = _create_selected_style()
	
	if has_theme_stylebox("filled", "PatternBox"):
		filled_style = get_theme_stylebox("filled", "PatternBox")
	else:
		filled_style = _create_filled_style()
	
	# Load colors from theme
	if has_theme_color("blank_text_color", "PatternBox"):
		blank_text_color = get_theme_color("blank_text_color", "PatternBox")
	
	if has_theme_color("filled_text_color", "PatternBox"):
		filled_text_color = get_theme_color("filled_text_color", "PatternBox")


func setup_as_blank(index: int):
	"""Setup als leeg vakje (vraagteken)"""
	sequence_index = index
	is_blank = true
	
	if not label:
		label = $Label
	if not button:
		button = $Button
	
	# Zorg dat styles geïnitialiseerd zijn
	if not blank_style:
		blank_style = _create_blank_style()
		selected_style = _create_selected_style()
		filled_style = _create_filled_style()
	
	label.text = "?"
	label.add_theme_color_override("font_color", blank_text_color)
	add_theme_stylebox_override("panel", blank_style)
	
	if button:
		button.visible = true


func setup_as_filled(index: int, value: String):
	"""Setup als gevuld vakje met waarde"""
	sequence_index = index
	is_blank = false
	
	if not label:
		label = $Label
	if not button:
		button = $Button
	
	# Zorg dat styles geïnitialiseerd zijn
	if not filled_style:
		blank_style = _create_blank_style()
		selected_style = _create_selected_style()
		filled_style = _create_filled_style()
	
	label.text = value
	label.add_theme_color_override("font_color", filled_text_color)
	add_theme_stylebox_override("panel", filled_style)
	
	if button:
		button.visible = false


func set_selected(selected: bool):
	"""Zet selectie status"""
	is_selected = selected
	if selected:
		add_theme_stylebox_override("panel", selected_style)
	else:
		add_theme_stylebox_override("panel", blank_style)


func update_value(value: String):
	"""Update de waarde in het vakje"""
	label.text = value
	if value == "?":
		label.add_theme_color_override("font_color", blank_text_color)
	else:
		label.add_theme_color_override("font_color", filled_text_color)


func set_hint_color(color: Color = Color.GREEN):
	"""Set the label color to specified color for visual hint"""
	label.add_theme_color_override("font_color", color)


func reset_hint_color():
	"""Reset the label color back to white after hint"""
	label.add_theme_color_override("font_color", filled_text_color)


func set_to_filled():
	"""Verander naar gevulde style"""
	add_theme_stylebox_override("panel", filled_style)


func reset_to_blank():
	"""Reset naar lege style"""
	label.text = "?"
	label.add_theme_color_override("font_color", blank_text_color)
	add_theme_stylebox_override("panel", blank_style)


func _on_button_pressed():
	"""Wanneer button wordt geklikt"""
	box_pressed.emit(self)


func _create_blank_style() -> StyleBoxFlat:
	"""Style voor lege vakjes"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color.YELLOW
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _create_selected_style() -> StyleBoxFlat:
	"""Style voor geselecteerd vakje"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color.GREEN
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _create_filled_style() -> StyleBoxFlat:
	"""Style voor gevulde vakjes"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.6)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.5, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
