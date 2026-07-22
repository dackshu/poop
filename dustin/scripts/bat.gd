extends CharacterBody2D

@export var move_speed: float = 50.0
@export var roam_distance: float = 100.0  # Max distance to walk left/right from home
@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 3.0

enum State { IDLE, ROAM }
var current_state: State = State.IDLE

var home_x: float
var target_x: float

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_timer: Timer = $IdleTimer

func _ready() -> void:
	# Save starting horizontal position as the home base anchor
	home_x = global_position.x
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	start_idle()

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Movement Logic
	if current_state == State.ROAM:
		var direction = sign(target_x - global_position.x)
		
		velocity.x = direction * move_speed

		# Flip sprite based on direction
		if direction != 0:
			animated_sprite.flip_h = direction < 0

		# Check if reached target X coordinate OR bumped into a wall
		if abs(global_position.x - target_x) < 5.0 or is_on_wall():
			start_idle()
	else:
		# Decelerate horizontal speed to 0 when idling
		velocity.x = move_toward(velocity.x, 0, move_speed)

	move_and_slide()

func start_idle() -> void:
	current_state = State.IDLE
	var wait_time = randf_range(min_idle_time, max_idle_time)
	idle_timer.start(wait_time)

func _on_idle_timer_timeout() -> void:
	current_state = State.ROAM
	target_x = home_x + randf_range(-roam_distance, roam_distance)
