class_name roamingEnemy
extends CharacterBody2D

# --- EXPORTED SETTINGS ---
@export var move_speed: float = 50.0
@export var chase_speed: float = 80.0
@export var roam_distance: float = 100.0
@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 3.0
@export var attack_time: float = 5.0  

@export var idle_animation_name: String = "idle"
@export var run_animation_name: String = "run"
@export var attack_animation_name: String = "attack"

# --- STATE MACHINE ---
enum State { IDLE, ROAM, CHASE, ATTACK }
var current_state: State = State.IDLE

var home_x: float
var target_x: float
var player_target: Node2D = null

# Attack Tracking Flags
var is_player_in_attack_range: bool = false
var can_attack: bool = true

# --- NODE REFERENCES ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_timer: Timer = $IdleTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $attack
@onready var attack_timer: Timer = $AttackTimer
 

func _ready() -> void:
	home_x = global_position.x
	
	# Connect Timer and Detection signals
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# Connect Attack Area & Cooldown Timer signals
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)	
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	start_idle()

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Movement State Machine
	match current_state:
		State.CHASE:
			if is_instance_valid(player_target):
				var direction = sign(player_target.global_position.x - global_position.x)
				velocity.x = direction * chase_speed
				
				if direction != 0:
					animated_sprite.flip_h = direction < 0
				
				play_animation(run_animation_name)
			else:
				# Player lost or freed -> return to idle
				start_idle()

		State.ROAM:
			var direction = sign(target_x - global_position.x)
			velocity.x = direction * move_speed

			if direction != 0:
				animated_sprite.flip_h = direction < 0

			play_animation(run_animation_name)

			if abs(global_position.x - target_x) < 5.0 or is_on_wall():
				start_idle()

		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			
		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0, move_speed)

	move_and_slide()

# --- STATE TRANSITIONS ---

func start_idle() -> void:
	current_state = State.IDLE
	player_target = null
	
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(idle_animation_name):
			play_animation(idle_animation_name)
		else:
			animated_sprite.stop()
			animated_sprite.frame = 0

	var wait_time = randf_range(min_idle_time, max_idle_time)
	idle_timer.start(wait_time)

func _on_idle_timer_timeout() -> void:
	# Only enter ROAM if we aren't currently chasing the player
	if current_state != State.CHASE:
		current_state = State.ROAM
		target_x = home_x + randf_range(-roam_distance, roam_distance)

# --- DETECTION & ATTACK SIGNALS ---

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		player_target = body
		current_state = State.CHASE
		idle_timer.stop() # Stop idle timer while chasing

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_target:
		start_idle()

# --- ATTACK REPEATING LOOP ---

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		is_player_in_attack_range = true
		try_attack()

func _on_attack_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		is_player_in_attack_range = false

func try_attack() -> void:
	# Only execute if player is still in range AND cooldown has passed
	if is_player_in_attack_range and can_attack:
		can_attack = false
		current_state = State.ATTACK
		print(name + " attack")
		
		
		play_animation(attack_animation_name)
		
		# Start cooldown timer using exported attack_time
		attack_timer.start(attack_time)

func _on_attack_timer_timeout() -> void:
	can_attack = true
	# If player is still standing inside the attack zone, attack again!
	if is_player_in_attack_range:
		try_attack()

# --- ANIMATION HELPER ---

func play_animation(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
				animated_sprite.play(anim_name)


func _on_animation_finished() -> void:
	if current_state == State.ATTACK:
		current_state == State.CHASE
	else:
		start_idle()
