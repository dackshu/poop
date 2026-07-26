class_name KillZone
extends Area2D

@onready var timer: Timer = $Timer

func _ready() -> void:
	# 1. Connect signals programmatically when the spike loads
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	if timer and not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

func _on_body_entered(body: Node2D) -> void:
	# 2. Check if the touching object is the player
	if body.is_in_group("player") or body.name == "player" or body.has_method("die"):
		print("You Died!")
		
		# If your player script has a die function, call it, otherwise start the timer
		if body.has_method("die"):
			body.die()
		elif timer:
			timer.start()

func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
