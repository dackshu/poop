class_name roamingEnemy
extends CharacterBody2D

# --- EXPORTED SETTINGS ---
@export var move_speed: float = 50.0
@export var chase_speed: float = 80.0
@export var roam_distance: float = 100.0
@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 3.0
@export var attack_time: float = 2.0  # Cooldown between attacks
@export var delay: float = 0.3         # Time before hit lands

# Health & Damage Variables
@export var damage: int = 1
@export var maxHealth: int = 100

# Animation Names
@export var idle_animation_name: String = "idle"
@export var run_animation_name: String = "run"
@export var attack_animation_name: String = "attack"
@export var hit_animation_name: String = "hit"

# --- STATE MACHINE ---
enum State { IDLE, ROAM, CHASE, ATTACK, HIT }
var current_state: State = State.IDLE

var home_x: float
var target_x: float
var player_target: Node2D = null

# Flags
var is_player_in_attack_range: bool = false
var can_attack: bool = true
var is_executing_damage_frame: bool = false # Clear flag for mid-attack check

# Node References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_timer: Timer = $IdleTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $attack
@onready var attack_timer: Timer = $AttackTimer
@onready var attack_delay: Timer = $RegularTimer
@onready var healthbar: ProgressBar = $healthUI
@onready var health = maxHealth

func _ready() -> void:
	home_x = global_position.x
	
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_delay.timeout.connect(realattack)
	
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	if healthbar:
		healthbar.max_value = maxHealth
		healthbar.value = health
	
	start_idle()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	match current_state:
		State.HIT:
			velocity.x = 0

		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0, move_speed)

		State.CHASE:
			if is_instance_valid(player_target):
				if is_player_in_attack_range:
					velocity.x = move_toward(velocity.x, 0, move_speed)
					play_animation(idle_animation_name)
				else:
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


# --- ROBUST MID-ATTACK CHECK ---
func is_mid_attack() -> bool:
	return is_executing_damage_frame


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
	if current_state != State.CHASE and current_state != State.ATTACK and current_state != State.HIT:
		current_state = State.ROAM
		target_x = home_x + randf_range(-roam_distance, roam_distance)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		player_target = body
		if current_state != State.ATTACK and current_state != State.HIT:
			current_state = State.CHASE
		idle_timer.stop()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_target:
		start_idle()


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		is_player_in_attack_range = true
		try_attack()

func _on_attack_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "fakeplayer":
		is_player_in_attack_range = false
		attack_delay.stop()


func try_attack() -> void:
	if is_player_in_attack_range and can_attack and current_state != State.HIT:
		can_attack = false
		current_state = State.ATTACK
		is_executing_damage_frame = true # Set flag on attack start
		
		# Turn toward player right as attack begins
		if is_instance_valid(player_target):
			var direction = sign(player_target.global_position.x - global_position.x)
			if direction != 0:
				animated_sprite.flip_h = direction < 0
		
		attack_delay.start(delay)
		play_animation(attack_animation_name)
		attack_timer.start(attack_time)

func realattack() -> void:
	if current_state == State.HIT:
		is_executing_damage_frame = false
		return

	if is_player_in_attack_range and is_instance_valid(player_target):
		if player_target.has_method("take_damage"):
			player_target.take_damage(damage)


func _on_attack_timer_timeout() -> void:
	can_attack = true
	if is_player_in_attack_range and current_state != State.HIT:
		try_attack()


func take_damage(amount: int) -> void:
	if current_state == State.HIT:
		return

	attack_delay.stop()
	is_executing_damage_frame = false # Clear attack flag if hit

	health -= amount
	if healthbar:
		healthbar.value = health
	
	if health <= 0:
		die()
	else:
		current_state = State.HIT
		velocity.x = 0
		play_animation(hit_animation_name)

# Inside roamingEnemy.gd
func die() -> void:
	# 1. Remove from group IMMEDIATELY before freeing the node
	remove_from_group("enemies")
	
	# 2. Count remaining enemies in the group right now
	var remaining_enemies = get_tree().get_nodes_in_group("enemies").size()
	
	# 3. Print the exact amount left to the Output console for debugging
	print("Enemy defeated: ", name, " | Enemies remaining: ", remaining_enemies)
	
	# 4. If none left, trigger the victory screen
	if remaining_enemies == 0:
		print("All enemies defeated! Loading victory screen...")
		show_victory_screen()
		
	# 5. Destroy this enemy node
	queue_free()


func show_victory_screen() -> void:
	# UPDATE THIS PATH to match your actual file path in FileSystem!
	# (e.g., "res://victory_screen.tscn" or "res://dustin/scenes/victory_screen.tscn")
	var victory_path = "res://dustin/scenes/victory_screen.tscn"
	
	if ResourceLoader.exists(victory_path):
		#var victory_scene = load(victory_path)
		#var victory_instance = victory_scene.instantiate()
		#get_tree().current_scene.add_child(victory_instance)
		#
		## Optional: Pause game behind the popup
		#get_tree().paused = true
		get_tree().change_scene_to_file(victory_path)
	else:
		print_rich("[color=red]ERROR: Could not find victory screen at path: ", victory_path, "[/color]")




func _on_animation_finished() -> void:
	if current_state == State.ATTACK or current_state == State.HIT:
		is_executing_damage_frame = false # Reset mid-attack flag when anim ends
		if is_instance_valid(player_target):
			current_state = State.CHASE
		else:
			start_idle()

func play_animation(anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
				animated_sprite.play(anim_name)
