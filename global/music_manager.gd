extends Node

# Music Manager - Handles all background music in the game

@onready var audio_player = $AudioStreamPlayer
@onready var audio_player2 = $AudioStreamPlayer2
@onready var audio_player3 = $AudioStreamPlayer3

# Current music state
var current_player = null
var is_playing = false


func _ready():
	print("MusicManager initialized")


func play_tense_music():
	"""Play the tense background music on loop"""
	play_music(Constants.tense_music, true)


func play_music(music: AudioStream, loop: bool = true):
	"""Play background music"""
	if current_player and current_player.playing:
		current_player.stop()
	
	current_player = audio_player
	current_player.stream = music
	
	# Note: For looping in Godot 4, you need to set it on the AudioStream itself
	# This is typically done in the import settings, but we set the player here
	current_player.play()
	is_playing = true


func stop_music():
	"""Stop the currently playing music"""
	if current_player:
		current_player.stop()
		is_playing = false


func pause_music():
	"""Pause the currently playing music"""
	if current_player and current_player.playing:
		current_player.stream_paused = true
		is_playing = false


func resume_music():
	"""Resume the paused music"""
	if current_player:
		current_player.stream_paused = false
		is_playing = true


func set_volume(volume_db: float):
	"""Set the music volume in decibels"""
	if current_player:
		current_player.volume_db = volume_db
