extends CharacterBody2D

const SPEED = 100.0
const ROLL_SPEED = 130.0
const JUMP_VELOCITY = -280.0

# Action & state variables
var is_attacking: bool = false
var is_rolling: bool = false
var is_taking_hit: bool = false
var is_invincible: bool = false
var facing_direction: float = 1.0

# Heart / Health variables
@export var max_health: int = 4
var current_health: int = max_health

# Physics
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Node references
@onready var animated_sprite = $AnimatedSprite2D
@onready var hearts_container = $HeartsContainer 
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea


func _ready() -> void:
	update_hearts()
	animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)


func _physics_process(delta: float) -> void:
	# 0. Complete Movement & Action Lockout During Hit
	if is_taking_hit:
		velocity.x = 0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	# 1. Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Handle direction input & sprite flipping
	var direction := Input.get_axis("move_left", "move_right")
	
	if direction > 0:
		animated_sprite.flip_h = false
		attack_area.scale.x = 1
		facing_direction = 1.0
	elif direction < 0:
		animated_sprite.flip_h = true
		attack_area.scale.x = -1
		facing_direction = -1.0

	# 4. Handle attack & roll inputs
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling:
		attack()
	
	if Input.is_action_just_pressed("roll") and not is_rolling and not is_attacking:
		roll()

	# 5. Play movement animations
	if not is_attacking and not is_rolling:
		if is_on_floor():
			if direction == 0:
				animated_sprite.play("idle")
			else:
				animated_sprite.play("run")
		else:
			animated_sprite.play("jump")

	# 6. Apply horizontal movement
	if is_rolling:
		var roll_dir = direction if direction != 0 else facing_direction
		if direction != 0:
			animated_sprite.flip_h = direction < 0
			attack_area.scale.x = direction
			facing_direction = direction
		velocity.x = roll_dir * ROLL_SPEED
	elif is_attacking:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	# 7. Apply physics movement
	move_and_slide()


func attack() -> void:
	print("Attack function called!")
	is_attacking = true
	animated_sprite.play("attack")
	
	attack_shape.disabled = false
	await get_tree().create_timer(0.3).timeout
	attack_shape.set_deferred("disabled", true)


func roll() -> void:
	is_rolling = true
	animated_sprite.play("roll")


func _on_animated_sprite_2d_animation_finished() -> void:
	match animated_sprite.animation:
		"attack":
			is_attacking = false
		"roll":
			is_rolling = false
		"hit":
			is_taking_hit = false


func take_damage(amount: int) -> void:
	if is_invincible or is_taking_hit:
		return

	is_attacking = false
	is_rolling = false
	is_taking_hit = true
	velocity.x = 0

	current_health = clamp(current_health - amount, 0, max_health) 
	update_hearts()

	if current_health <= 0:
		die()
	else:
		animated_sprite.play("hit")
		
		is_invincible = true
		await get_tree().create_timer(0.8).timeout
		is_invincible = false


func update_hearts() -> void:
	if not hearts_container:
		return
	
	var hearts = hearts_container.get_children()
	for i in range(hearts.size()):
		if i < current_health:
			hearts[i].show()
		else:
			hearts[i].hide()


func die() -> void:
	print("Player died!")
	get_tree().reload_current_scene()


# Checks if target is mid-attack before applying damage
func _on_attack_area_body_entered(body: Node2D) -> void:
	if body == self:
		return

	# Block hitting an enemy that is currently in its attack state
	if body.has_method("is_mid_attack") and body.is_mid_attack():
		print("Enemy is mid-attack! Attack blocked!")
		return
		
	if body.has_method("take_damage"):
		print("Dealing damage to enemy!")
		body.take_damage(25)
		attack_shape.set_deferred("disabled", true)
