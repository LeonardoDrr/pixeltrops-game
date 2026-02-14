extends "res://scripts/boss_base.gd"

## Knight Boss - Melee warrior with shield, roll, and charge attacks
## Refactored with State Machine and Phases for professional feel

enum KnightState {
	IDLE,
	CHASE,
	ATTACK_PREPARE,
	ATTACKING,
	CHARGE_PREPARE,
	CHARGING,
	JUMP_SMASH_PREPARE,
	JUMP_SMASH_AIR,
	JUMP_SMASH_LAND,
	DEFENDING,
	STUNNED,
	ROLLING
}

@export var charge_speed: float = 300.0
@export var roll_speed: float = 200.0
@export var shield_damage_reduction: float = 0.5
@export var charge_cooldown: float = 6.0
@export var jump_smash_cooldown: float = 8.0

var current_state: KnightState = KnightState.IDLE
var current_phase: int = 1
var is_enraged: bool = false

# Timers/Counters
var state_timer: float = 0.0
var charge_timer: float = 0.0
var jump_smash_timer: float = 0.0
var last_attack_frame: int = -1

var accumulated_damage: int = 0

func _ready() -> void:
	super._ready()
	is_flying = false
	anim_hurt = "" # Knight is tough, maybe no hurt anim or very short
	
	anim.frame_changed.connect(_on_frame_changed)
	
	if loot_table.is_empty():
		loot_table = [
			{"item": "heart", "weight": 35, "amount": 2},
			{"item": "coin", "weight": 45, "amount": 20},
			{"item": "rare_sword", "weight": 20, "amount": 1}
		]
	
	# Adjust HP bar height/scale
	if hp_bar_bg:
		hp_container.scale = Vector2(1.5, 1.5)
		# Update position relative to container
		hp_bar_bg.position = Vector2(-30, -45) # Lowered to be closer to head
		hp_bar_fill.position = Vector2(-30, -45)

	_change_knight_state(KnightState.CHASE)

var contact_damage_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if is_dead: return
	
	# IMPORTANT: Update Health Bar Position manually since we don't call super._physics_process
	if hp_container:
		hp_container.global_position = global_position
		
	if not player: return

	# Updates Cooldowns
	charge_timer = max(0, charge_timer - delta)
	jump_smash_timer = max(0, jump_smash_timer - delta)
	contact_damage_timer = max(0, contact_damage_timer - delta)
	
	# --- CONTACT DAMAGE (Run Through) ---
	# If close and moving fast (Chase/Charge), deal damage
	if contact_damage_timer <= 0:
		var dist_to_player = global_position.distance_to(player.global_position)
		if dist_to_player < 40:
			# Check if visible/alive
			if not is_dead and accumulated_damage < 10: # Don't hit if being comboed hard? (Optional)
				print("Knight touched player! dealing 8 damage.")
				player.take_damage(8)
				contact_damage_timer = 1.0 # 1 second cooldown
	
	# Decay accumulated damage over time
	if accumulated_damage > 0:
		accumulated_damage = max(0, accumulated_damage - (10 * delta)) # Decay 10 dmg per second
	
	# Gravity
	if not is_on_floor() and current_state != KnightState.JUMP_SMASH_AIR:
		velocity += get_gravity() * delta

	# Check Phase Transition
	if current_phase == 1 and hp <= boss_hp * 0.5:
		_enter_phase_2()

	# State Logic
	match current_state:
		KnightState.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * delta)
			_play_if_not("idle")
			
			if state_timer <= 0:
				_decide_next_action()
			else:
				state_timer -= delta
				
		KnightState.CHASE:
			var direction = (player.global_position - global_position).normalized()
			var dist = global_position.distance_to(player.global_position)
			var y_diff = player.global_position.y - global_position.y
			
			# Face player
			anim.flip_h = direction.x < 0
			
			if dist < 60 and abs(y_diff) < 50: # Attack Range (and roughly same height)
				velocity.x = 0
				_change_knight_state(KnightState.ATTACK_PREPARE)
			else:
				var move_speed = speed * (1.3 if is_enraged else 1.0)
				velocity.x = direction.x * move_speed
				_play_if_not("run")
				
				# JUMP ATTACK / PLATFORMING
				# If player is significantly above (> 40px) and we are on floor
				if y_diff < -40 and is_on_floor():
					velocity.y = -600 # Jump up
					# Add some forward momentum
					velocity.x = direction.x * move_speed * 1.5
				
				# WALL JUMP
				elif is_on_wall() and is_on_floor():
					velocity.y = -550
					
				# Random Special Moves
				if dist > 150 and charge_timer <= 0:
					_change_knight_state(KnightState.CHARGE_PREPARE)
				elif dist > 100 and jump_smash_timer <= 0 and is_enraged:
					_change_knight_state(KnightState.JUMP_SMASH_PREPARE)
		
		KnightState.ATTACK_PREPARE:
			velocity.x = 0
			_play_if_not("idle")
			# TELEGRAPH: Flash Red
			modulate = Color(3.0, 0.5, 0.5) if Engine.get_process_frames() % 4 < 2 else Color.WHITE
			
			state_timer -= delta
			if state_timer <= 0:
				modulate = Color.WHITE
				if is_enraged: modulate = Color(1, 0.5, 0.5)
				_change_knight_state(KnightState.ATTACKING)

		KnightState.ATTACKING:
			velocity.x = 0
			# Animation handled by _play_if_not called in _enter_state
			# Exit handled by _on_animation_finished
			
		KnightState.CHARGE_PREPARE:
			velocity.x = 0
			_play_if_not("idle")
			# TELEGRAPH: Flash Orange
			modulate = Color(1.0, 0.5, 0.0) if Engine.get_process_frames() % 8 < 4 else Color.WHITE
			
			state_timer -= delta
			if state_timer <= 0:
				modulate = Color.WHITE
				if is_enraged: modulate = Color(1, 0.5, 0.5)
				_change_knight_state(KnightState.CHARGING)
				
		KnightState.CHARGING:
			if is_on_wall():
				_change_knight_state(KnightState.STUNNED)
			
			state_timer -= delta
			if state_timer <= 0:
				_change_knight_state(KnightState.IDLE)

		KnightState.JUMP_SMASH_PREPARE:
			velocity.x = 0
			_play_if_not("jump")
			modulate = Color(1.0, 0.0, 1.0) # Purple
			state_timer -= delta
			if state_timer <= 0:
				modulate = Color(1, 0.5, 0.5)
				_change_knight_state(KnightState.JUMP_SMASH_AIR)

		KnightState.JUMP_SMASH_AIR:
			# Move towards player rapidly
			var direction = (player.global_position - global_position).normalized()
			velocity.x = direction.x * speed * 1.5
			velocity.y += get_gravity().y * 2.0 * delta
			
			if is_on_floor():
				_change_knight_state(KnightState.JUMP_SMASH_LAND)

		KnightState.JUMP_SMASH_LAND:
			velocity.x = 0
			state_timer -= delta
			if state_timer <= 0:
				_change_knight_state(KnightState.IDLE)

		KnightState.STUNNED:
			velocity.x = 0
			_play_if_not("idle")
			modulate = Color(0.5, 0.5, 1.0) # Blue
			state_timer -= delta
			if state_timer <= 0:
				modulate = Color.WHITE
				if is_enraged: modulate = Color(1, 0.5, 0.5)
				_accumulated_damage_reset()
				_change_knight_state(KnightState.DEFENDING)

		KnightState.DEFENDING:
			velocity.x = 0
			_play_if_not("shield")
			state_timer -= delta
			if state_timer <= 0:
				_change_knight_state(KnightState.IDLE)
				
		KnightState.ROLLING:
			# Only roll for short duration
			state_timer -= delta
			if state_timer <= 0:
				_change_knight_state(KnightState.IDLE)

	move_and_slide()

func _accumulated_damage_reset() -> void:
	accumulated_damage = 0

func _change_knight_state(new_state: KnightState) -> void:
	current_state = new_state
	is_invulnerable = false
	
	match new_state:
		KnightState.IDLE:
			state_timer = 0.3 if is_enraged else 0.5 # FASTER decisions
			_play_if_not("idle")
			
		KnightState.CHASE:
			_play_if_not("run")
			
		KnightState.ATTACK_PREPARE:
			state_timer = 0.3 # Faster attack
			
		KnightState.ATTACKING:
			last_attack_frame = -1
			_play_if_not("attack")
			
		KnightState.CHARGE_PREPARE:
			state_timer = 0.8
			
		KnightState.CHARGING:
			charge_timer = charge_cooldown
			var dir = -1 if anim.flip_h else 1
			velocity.x = dir * charge_speed * (1.5 if is_enraged else 1.0)
			state_timer = 1.5
			_play_if_not("run")
			
		KnightState.JUMP_SMASH_PREPARE:
			jump_smash_timer = jump_smash_cooldown
			state_timer = 0.5
			
		KnightState.JUMP_SMASH_AIR:
			velocity.y = -700
			if player:
				var dir = (player.global_position.x - global_position.x)
				velocity.x = sign(dir) * speed * 2.5
			_play_if_not("jump")
			
		KnightState.JUMP_SMASH_LAND:
			_play_if_not("attack")
			# Impact Damage
			if player and global_position.distance_to(player.global_position) < 150:
				player.take_damage(15)
			state_timer = 0.8
			
		KnightState.STUNNED:
			state_timer = 2.0
			
		KnightState.DEFENDING:
			state_timer = 1.5
			is_invulnerable = false 
			
		KnightState.ROLLING:
			is_invulnerable = true
			state_timer = 0.5
			_play_if_not("roll")
			var dir = 1 if anim.flip_h else -1 # Roll BACKWARDS from facing
			velocity.x = dir * roll_speed * 1.5

func _decide_next_action() -> void:
	if not player: return
	var dist = global_position.distance_to(player.global_position)
	
	if dist < 80:
		_change_knight_state(KnightState.ATTACK_PREPARE)
	else:
		_change_knight_state(KnightState.CHASE)

func _enter_phase_2() -> void:
	if current_phase == 2: return
	current_phase = 2
	is_enraged = true
	print("!!! KNIGHT ENRAGED !!!")
	hp += 20
	_update_health_bar()
	modulate = Color(1.0, 0.4, 0.4)
	scale *= 1.1
	_change_knight_state(KnightState.IDLE)

# --- Events ---

func _on_frame_changed() -> void:
	if current_state == KnightState.ATTACKING and anim.animation == "attack":
		var frame = anim.frame
		if frame == 4 or frame == 9 or frame == 14:
			if frame != last_attack_frame:
				_check_melee_hit()
				last_attack_frame = frame

func _check_melee_hit() -> void:
	if not player: return
	var dist = global_position.distance_to(player.global_position)
	if dist < 90:
		player.take_damage(damage)

func _on_animation_finished() -> void:
	if current_state == KnightState.ATTACKING:
		# After combo, chance to defend or keep pressure
		if randf() < 0.3:
			_change_knight_state(KnightState.DEFENDING)
		else:
			_change_knight_state(KnightState.IDLE)
	elif current_state == KnightState.ROLLING:
		_change_knight_state(KnightState.IDLE)
	elif anim.animation == "death":
		# Handled in Base
		pass

# --- Overrides ---

func take_damage_with_knockback(amount: int, force: Vector2, is_crit: bool = false) -> void:
	# Accumulate damage for reactive defense
	accumulated_damage += amount
	
	# REACTIVE DEFENSE: If took > 8 damage recently (e.g. 2-3 hits)
	if accumulated_damage > 8 and current_state != KnightState.STUNNED and current_state != KnightState.JUMP_SMASH_AIR:
		print("Knight Reaction: Too much damage! Rolling away.")
		accumulated_damage = 0
		_change_knight_state(KnightState.ROLLING)
		return

	if current_state == KnightState.DEFENDING:
		amount = int(amount * (1.0 - shield_damage_reduction))
		print("Knight blocked! Damage reduced.")
		# Counter attack highly likely if blocked
		if randf() < 0.7:
			_change_knight_state(KnightState.ATTACK_PREPARE)
	
	if current_state == KnightState.STUNNED:
		amount *= 2
		print("CRITICAL HIT on Stunned Knight!")
		
	super.take_damage_with_knockback(amount, force, is_crit)
