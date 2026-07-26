extends CharacterBody2D


const SPEED = 120.0
const JUMP_VELOCITY = -330.0

#attack & roll variables
var is_attacking: bool = false
var is_rolling: bool = false

# Heart Variables
@export var max_health: int = 4 # Represents your total number of hearts
var current_health: int = max_health

# Get the gravity from the ProjectSettings to be synced with the RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $AnimatedSprite2D
# Hearts Container ref
@onready var hearts_container = $HeartsContainer 


# Ready function to initialize hearts
func _ready() -> void:
	update_hearts()
	# Connects animation finished signal to reset attack
	animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Flip the Sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	
	# Handles attack input (and no attacking while rolling)
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling:
		attack()
	
	# Handles roll input (stops rolling while attacking, only on floor)
	if Input.is_action_just_pressed("roll") and not is_rolling and not is_attacking and is_on_floor():
		roll()
	
	# Play animations
	# Start animations in an 'if not is_attacking and not is_rolling' check
	if not is_attacking and not is_rolling:
		if is_on_floor():
			if direction == 0:
				animated_sprite.play("idle")
			else:
				animated_sprite.play("run")
		else:
			animated_sprite.play("jump")
	
	
	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

# Function to handle attacking
func attack() -> void:
	is_attacking = true
	animated_sprite.play("attack")
	# note to self: add logic for spawning an attack hitbox or dealing damage here later!

# --- NEW: Function to handle rolling ---
func roll() -> void:
	is_rolling = true
	animated_sprite.play("roll")
	# can add code here later to temp. increase speed or make the player invincible.

# Reset attack state when animation finishes
func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack":
		is_attacking = false
	elif animated_sprite.animation == "roll":
		is_rolling = false

# Function to handle taking damage
func take_damage(amount: int) -> void:
	current_health -= amount
	# clamp ensures health doesn't drop below 0 or go above max_health
	current_health = clamp(current_health, 0, max_health) 
	
	update_hearts()
		
	if current_health <= 0:
		die()

# Function to visually update the hearts
func update_hearts() -> void:
	if not hearts_container:
		return
		
	# Get all the TextureRects inside the container
	var hearts = hearts_container.get_children()
	
	for i in range(hearts.size()):
		# If the index is less than current_health, heart stays visible
		if i < current_health:
			hearts[i].show()
		else:
			# Else hide the heart (a lost heart)
			hearts[i].hide() 

# Function to handle death
func die() -> void:
	print("Player died!")
	# Death logic: restarts the current scene
	get_tree().reload_current_scene()

func _on_timer_timeout() -> void:
	pass # Replace with function body.
	
