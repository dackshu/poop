# victory_screen.gd
extends Control

func _on_button_pressed() -> void:
	# Unpause the game tree before restarting
	get_tree().paused = false
	# Reload your main game level (replace path with your level scene)
	get_tree().change_scene_to_file("res://main/game.tscn")
