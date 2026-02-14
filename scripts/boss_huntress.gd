extends "res://scripts/boss_base.gd"

## Huntress Boss - Archer with tactical positioning

@export var projectile_scene: PackedScene
@export var attack_range: float = 300.0
@export var flee_range: float = 80.0  # Keep distance from player

var can_attack: bool = true

func _ready() -> void:
	super._ready()
	is_flying = false
	anim_hurt = "get hit"  # Huntress has "get hit" animation
	# Set loot table
	if loot_table.is_empty():
		loot_table = [
			{"item": "heart", "weight": 25, "amount": 1},
			{"item": "arrow", "weight": 60, "amount": 10},
			{"item": "rare_bow", "weight": 15, "amount": 1}
		]

func _process_enemy_movement(delta: float) -> void:
	if is_dead:
		return
	
	if not player:
		return
	
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var player_pos = player.global_position
	var distance = global_position.distance_to(player_pos)
	var dir_to_player = (player_pos - global_position).normalized()
	
	# Face player
	anim.flip_h = dir_to_player.x < 0
	
	# Behavior
	if is_attacking:
		velocity.x = 0
	elif distance <= flee_range:
		# Too close - retreat FAST
		velocity.x = -dir_to_player.x * speed * 2.0  # Faster retreat
		_play_if_not("run")
	elif distance <= attack_range:
		# Optimal range - stop and shoot
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		if can_attack:
			_start_attack(player_pos)
	else:
		# Chase to get in range
		velocity.x = dir_to_player.x * speed
		_play_if_not("run")
	
	# Jump over obstacles
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	move_and_slide()
	
	# Jump/Fall animation states
	if not is_on_floor() and not is_attacking:
		if velocity.y < 0:  # Going up
			_play_if_not("jump")
		elif velocity.y > 0:  # Falling
			_play_if_not("fall")

func _start_attack(target_pos: Vector2) -> void:
	is_attacking = true
	can_attack = false
	_play_if_not("attack")
	
	print("Huntress starting BURST attack at distance: ", global_position.distance_to(target_pos))
	
	# Burst fire: 3 arrows
	for i in range(3):
		get_tree().create_timer(i * 0.2).timeout.connect(func(): 
			if not is_dead and player:
				_shoot_arrow(player.global_position) # Re-aim each shot
		)
	
	# Cooldown (longer since it's a burst)
	get_tree().create_timer(2.0).timeout.connect(func(): 
		can_attack = true
		print("Huntress can attack again!")
	)

func _shoot_arrow(target_pos: Vector2) -> void:
	if is_dead or not projectile_scene:
		print("Huntress can't shoot - dead: ", is_dead, ", no projectile: ", projectile_scene == null)
		return
	
	var arrow = projectile_scene.instantiate()
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = global_position + Vector2(0, -10)
	
	var direction = (target_pos - arrow.global_position).normalized()
	
	if arrow.has_method("setup"):
		arrow.setup(direction, self)
	
	print("Huntress shot arrow towards ", target_pos)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		# Return to idle when attack finishes
		if not is_dead:
			_play_if_not("idle")
		print("Huntress attack finished, can_attack: ", can_attack)
