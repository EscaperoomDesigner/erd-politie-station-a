extends Node

# SFX Manager - Handles all sound effects in the game

@onready var audio_player = $AudioStreamPlayer
@onready var audio_player2 = $AudioStreamPlayer2
@onready var audio_player3 = $AudioStreamPlayer3

# Pool of audio players for overlapping sounds
var audio_players = []
var current_player_index = 0


func _ready():
	# Initialize audio player pool
	audio_players = [audio_player, audio_player2, audio_player3]
	print("SFXManager initialized")


func play_coin_sound():
	"""Play the coin collection sound"""
	play_sound(Constants.coin_sfx)


func play_hint_sound():
	"""Play the hint sound"""
	play_sound(Constants.hint_sfx)


func play_success():
	"""Play the success sound"""
	play_sound(Constants.success_sfx)

func play_wrong_memory():
	"""Play the wrong memory sound"""
	play_sound(Constants.wrong_memory_sfx)

func play_click():
	"""Play the click sound"""
	play_sound(Constants.click_sfx)


func stop_all_sounds():
	"""Stop all currently playing sounds"""
	for player in audio_players:
		if player.playing:
			player.stop()


func play_sound(sound: AudioStream):
	"""Play a sound effect using the next available audio player"""
	# Get next player in rotation
	var player = audio_players[current_player_index]
	current_player_index = (current_player_index + 1) % audio_players.size()
	
	# Play the sound
	player.stream = sound
	player.play()
