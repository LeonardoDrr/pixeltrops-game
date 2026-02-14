extends "res://scripts/enemy_base.gd"

@export var projectile_scene: PackedScene
@export var attack_range: float = 200.0  # Range to start shooting
@export var flee_range: float = 50.0     # Range to stop/flee

var can_shoot: bool = true

func _process_enemy_movement(delta: float) -> void:
	if is_dead:
		return
		
	if not player:
		return
		
	var player_pos = player.global_position
	var distance = global_position.distance_to(player_pos)
	var dir_to_player = (player_pos - global_position).normalized()
	
	# Face player
	if dir_to_player.x != 0:
		anim.flip_h = dir_to_player.x < 0
	
	# --- Gravity ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Behavior Logic
	if is_attacking:
		# Stop moving while attacking
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		
	elif distance <= attack_range and distance > flee_range:
		# In optimal range: Stop and Shoot
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		if can_shoot:
			print("PinkMonster: In Range (", distance, "). Starting Attack.")
			_start_ranged_attack(player_pos)
			
	elif distance <= flee_range:
		# Too close: For now, stop (could flee in future)
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		if can_shoot:
			print("PinkMonster: Too Close (", distance, "). Panic Attack.")
			_start_ranged_attack(player_pos)
			
	else:
		# Chase: Move towards player
		velocity.x = dir_to_player.x * speed
		_play_if_not(anim_walk)
		
	move_and_slide()

func _start_ranged_attack(target_pos: Vector2) -> void:
	is_attacking = true
	can_shoot = false
	
	# Play attack animation
	_play_if_not(anim_attack)
	
	# Schedule the actual throw (sync with animation frame)
	# Assuming attack animation takes ~0.5s, throw at 0.3s
	get_tree().create_timer(0.3).timeout.connect(func(): _throw_rock(target_pos))
	
	# Attack Cooldown
	get_tree().create_timer(2.0).timeout.connect(func(): can_shoot = true)

func _throw_rock(target_pos: Vector2) -> void:
	if is_dead: return
		
	if projectile_scene:
		print("PinkMonster: Spawning Rock!")
		var rock = projectile_scene.instantiate()
		get_tree().current_scene.add_child(rock)
		rock.global_position = global_position
		# Offset slightly up
		rock.global_position.y -= 10
		
		# Calculate direction
		# Add slight upward arc for rock
		var direction = (target_pos - rock.global_position).normalized()
		direction.y -= 0.2 # Arc up
		direction = direction.normalized()
		
		if rock.has_method("setup"):
			# Pass self as shooter
			rock.setup(direction, self)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		_play_if_not(anim_idle) # Return to idle
