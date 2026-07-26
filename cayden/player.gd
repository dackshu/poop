extends CharacterBody2D


const SPEED = 120.0
const JUMP_VELOCITY = -330.0

#attack & roll variables
var is_attacking: bool = false
var is_rolling: bool = false
var is_invincible: bool = false

# Heart Variables
@export var max_health: int = 4 # Represents your total number of hearts
var current_health: int = max_health

# Get the gravity from the ProjectSettings to be synced with the RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $AnimatedSprite2D
# Hearts Container ref
@onready var hearts_container = $HeartsContainer 
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea



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
	
	if direction > 0:
		# Facing Right
		animated_sprite.flip_h = false
		
		# --- ADD THIS LINE ---
		attack_area.scale.x = 1 
		# ----------------------
		
	elif direction < 0:
		# Facing Left
		animated_sprite.flip_h = true
		
		# --- ADD THIS LINE ---
		attack_area.scale.x = -1 
		# ----------------------
	
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
	print("Attack function called!")
	is_attacking = true
	animated_sprite.play("attack")
	

	attack_shape.disabled = false
	
	# 2. Wait slightly longer (0.3s) so physics updates
	await get_tree().create_timer(0.3).timeout
	
	# 3. Turn off
	attack_shape.set_deferred("disabled", true)

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
	if is_invincible:
		return

	current_health -= amount
	current_health = clamp(current_health, 0, max_health) 
	update_hearts()

	if current_health <= 0:
		die()
	else:
		# Give player 1 second of invincibility
		is_invincible = true
		await get_tree().create_timer(1.0).timeout
		is_invincible = false

# Function to visually update the hearts
func update_hearts() -> void:
	if not hearts_container:
		return
	print(current_health)
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
	


func _on_attack_area_body_entered(body: Node2D) -> void:
	# Debug print to verify if ANY collision is firing
	print("Hit body: ", body.name)
	
	if body == self:
		return # Ignore player self-hit
		
	if body.has_method("take_damage"):
		print("Dealing damage to enemy!")
		body.take_damage(25)
		# Instantly disable shape so it only hits ONCE per swing
		attack_shape.set_deferred("disabled", true)


@warning_ignore("unused_parameter")
func _on_attack_area_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	pass # Replace with function body.
