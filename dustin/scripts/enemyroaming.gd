class_name roamingEnemy
extends CharacterBody2D

# --- EXPORTED SETTINGS ---
@export var move_speed: float = 50.0
@export var chase_speed: float = 80.0
@export var roam_distance: float = 100.0
@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 3.0
@export var attack_time: float = 2.0  # Attack cooldown duration
@export var delay: float = 1.0
#health and damage variables
@export var damage: int = 50
@export var maxHealth: int = 100

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
@onready var attack_delay: Timer = $RegularTimer
@onready var health = maxHealth #sets health equal to maxhealth each time

func _ready() -> void:
	home_x = global_position.x
	
	# Connect Signals
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_delay.timeout.connect(realattack)
	
	
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Connect sprite animation finished signal
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	start_idle()

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Movement State Machine
	match current_state:
		State.ATTACK:
			# Freeze horizontal movement during active attack frame
			velocity.x = move_toward(velocity.x, 0, move_speed)

		State.CHASE:
			if is_instance_valid(player_target):
				# If waiting inside attack range during cooldown, stand still and play IDLE
				if is_player_in_attack_range:
					velocity.x = move_toward(velocity.x, 0, move_speed)
					play_animation(idle_animation_name)
				else:
					# Otherwise, run toward the player
					var direction = sign(player_target.global_position.x - global_position.x)
					velocity.x = direction * chase_speed
					
					if direction != 0:
						animated_sprite.flip_h = direction < 0
					
					play_animation(run_animation_name)
			else:
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
	if current_state != State.CHASE and current_state != State.ATTACK:
		current_state = State.ROAM
		target_x = home_x + randf_range(-roam_distance, roam_distance)

# --- DETECTION SIGNALS ---

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		player_target = body
		if current_state != State.ATTACK:
			current_state = State.CHASE
		idle_timer.stop()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_target:
		start_idle()

# --- ATTACK SIGNALS & LOGIC ---

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		is_player_in_attack_range = true
		try_attack()

func _on_attack_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		is_player_in_attack_range = false

func try_attack() -> void:
	if is_player_in_attack_range and can_attack:
		can_attack = false
		current_state = State.ATTACK
		
		# Face the player when initiating the attack
		if is_instance_valid(player_target):
			var direction = sign(player_target.global_position.x - global_position.x)
			if direction != 0:
				animated_sprite.flip_h = direction < 0
		
		# Print name and trigger animation simultaneously
		attack_delay.start(delay)
		
		play_animation(attack_animation_name)
		
		# Start cooldown timer
		attack_timer.start(attack_time)

func realattack() -> void:
	if is_player_in_attack_range and is_instance_valid(player_target):
		if player_target.has_variable(take_damage):
			player_target.take_damage(damage)
		


func _on_attack_timer_timeout() -> void:
	can_attack = true
	if is_player_in_attack_range:
		try_attack()

#---- HEALTH AND DAMAGE ----

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
	

# --- ANIMATION HANDLING ---

func _on_animation_finished() -> void:
	if current_state == State.ATTACK:
		if is_instance_valid(player_target):
			current_state = State.CHASE
		else:
			start_idle()

func play_animation(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
				animated_sprite.play(anim_name)
