extends Area2D

func _ready() -> void:
	# Connect the body_entered signal automatically when the scene loads
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check if the object entering the spikes is the player
	if body.has_method("die"):
		body.die() # Directly triggers the player's death & scene reload
