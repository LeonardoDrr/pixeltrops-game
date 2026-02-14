extends "res://scripts/enemy_base.gd"
class_name EnemyGround

func _process_enemy_movement(delta: float) -> void:
	# --- Gravity ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- No player or player dead, just idle ---
	if player == null or not is_instance_valid(player) or player.get("is_dead") == true:
		velocity.x = move_toward(velocity.x, 0, speed)
		move_and_slide()
		is_attacking = false
		_play_if_not(anim_idle)
		return

	# --- Calculate distance to player ---
	var dir_to_player = player.global_position.x - global_position.x
	var distance = abs(dir_to_player)
	var face_dir = sign(dir_to_player)

	# --- Flip sprite to face player ---
	anim.flip_h = face_dir < 0

	# --- If in attack animation, try dealing damage ---
	if is_attacking:
		if not has_dealt_damage:
			_try_deal_damage()
		velocity.x = 0
		move_and_slide()
		return

	if distance <= ATTACK_RANGE:
		_change_state(State.ATTACK)
		velocity.x = 0
		is_attacking = true
		has_dealt_damage = false
		anim.play(anim_attack)
	elif distance <= WALKATK_RANGE:
		_change_state(State.WALKATK)
		velocity.x = face_dir * speed * 0.6
		_play_if_not("atk2") # Keep hardcoded or add export
	else:
		_change_state(State.CHASE)
		velocity.x = face_dir * speed
		_play_if_not(anim_walk)

	# --- Jump over obstacles ---
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	# --- Jump animation override ---
	if not is_on_floor() and not is_attacking:
		_play_if_not("Jump")
