extends CanvasLayer

# Overlay that displays score, timer, and player name
# This is part of the framework and stays consistent across all games

@onready var score_label = %ScoreLabel
@onready var team_name_label = %TeamNameLabel
@onready var timer_label = %TimerLabel
@onready var timer_node: Timer = %GameTimer
@onready var top_bar = $TopBar

# Score animation variables
var displayed_score: int = 0
var target_score: int = 0
var score_tween: Tween


func _ready():
	# Connect to GameManager signals
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.timer_updated.connect(_on_timer_updated)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.player_name_changed.connect(_on_player_name_changed)
	
	# Initialize display
	update_score(GameManager.score)
	update_player_name(GameManager.player_name)


func set_topbar_visible(visible: bool):
	"""Show or hide the top bar (for setup/finish screens)"""
	if top_bar:
		top_bar.visible = visible



func _on_score_changed(new_score: int):
	animate_score(new_score)


func _on_timer_updated(time_left: float):
	update_timer(time_left)


func _on_player_name_changed(new_name: String):
	update_player_name(new_name)


func animate_score(new_score: int):
	"""Animate the score counting up from current to new value"""
	# Kill existing tween if any
	if score_tween:
		score_tween.kill()
	
	target_score = new_score
	
	# Create a new tween
	score_tween = create_tween()
	score_tween.set_ease(Tween.EASE_OUT)
	score_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate from current displayed score to target score
	# Duration depends on score difference (faster for small changes)
	var score_diff = abs(new_score - displayed_score)
	var duration = min(0.5, score_diff * 0.01 + 0.2)  # 0.2 to 0.5 seconds
	
	score_tween.tween_method(_update_score_display, displayed_score, new_score, duration)
	score_tween.finished.connect(func(): displayed_score = target_score)


func _update_score_display(value: float):
	"""Update the score label during animation"""
	displayed_score = int(value)
	score_label.text = "$%d" % displayed_score


func update_score(score: int):
	"""Update the score display instantly (no animation)"""
	displayed_score = score
	target_score = score
	score_label.text = "$%d" % score


func update_player_name(player_name: String):
	"""Update the player name display"""
	team_name_label.text = player_name


func update_timer(time_seconds: float):
	"""Update the timer display (mm:ss format)"""
	var minutes = int(time_seconds / 60)
	var seconds = int(time_seconds) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func set_timer_visible(should_show: bool = true):
	"""Show or hide the timer"""
	timer_label.visible = should_show


func _on_game_ended():
	"""Game has ended - hide reset button and reset timer display"""
	# Note: Reset button visibility is managed by main.gd to ensure it's hidden on start screen
	# but visible on input name and games screens
	update_timer(0.0)
