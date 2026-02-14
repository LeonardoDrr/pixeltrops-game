extends "res://scripts/boss_base.gd"

## Evil Wizard Boss - Flying Mage with magic attacks

@export var projectile_scene: PackedScene
@export var fly_speed: float = 80.0
@export var attack_range: float = 250.0
@export var hover_height: float = 100.0  # How high above player to hover

var hover_offset: float = 0.0
var can_attack: bool = true

func _ready() -> void:
	super._ready()
	is_flying = true
	anim_hurt = "take hit"  # Evil Wizard has "take hit" animation
	# Set loot table (can be overridden in scene)
	if loot_table.is_empty():
		loot_table = [
			{"item": "heart", "weight": 30, "amount": 2},
			{"item": "mana", "weight": 50, "amount": 5},
			{"item": "rare_staff", "weight": 20, "amount": 1}
		]

func _process_enemy_movement(delta: float) -> void:
	if is_dead:
		return
		
	if not player:
		return
		
	var player_pos = player.global_position
	var distance = global_position.distance_to(player_pos)
	
	# Hover above player
	var target_pos = player_pos + Vector2(0, -hover_height)
	var direction = (target_pos - global_position).normalized()
	
	# Face player
	anim.flip_h = player_pos.x < global_position.x
	
	# Behavior
	if is_attacking:
		# Stop moving while attacking
		velocity = Vector2.ZERO
	elif distance <= attack_range:
		# Circle around player
		hover_offset += delta * 2.0
		var circle_pos = player_pos + Vector2(cos(hover_offset), sin(hover_offset) - 1.0) * 150.0
		velocity = (circle_pos - global_position).normalized() * fly_speed
		
		if can_attack:
			_start_attack(player_pos)
	else:
		# Move toward player
		velocity = direction * fly_speed
		_play_if_not("move")
	
	# Debug print every 60 frames (~1 second)
	if Engine.get_process_frames() % 60 == 0:
		print("Evil Wizard flying - distance: ", distance, ", attacking: ", is_attacking, ", can_attack: ", can_attack)
	
	# Apply velocity (no gravity for flying)
	move_and_slide()

func _start_attack(target_pos: Vector2) -> void:
	is_attacking = true
	can_attack = false
	_play_if_not("attack")
	
	print("Evil Wizard starting MAGICAL BARRAGE at distance: ", global_position.distance_to(target_pos))
	
	# Shoot 3 fireballs: Center, Left, Right
	get_tree().create_timer(0.4).timeout.connect(func(): _shoot_magic_spread(target_pos))
	
	# Faster Cooldown
	get_tree().create_timer(1.5).timeout.connect(func(): 
		can_attack = true
		print("Evil Wizard can attack again!")
	)

func _shoot_magic_spread(target_pos: Vector2) -> void:
	if is_dead or not projectile_scene:
		return
	
	# Fire 3 projectiles with spread
	var base_direction = (target_pos - global_position).normalized()
	var angles = [0.0, -0.3, 0.3]  # Center, -15 deg, +15 deg approx
	
	for angle in angles:
		var magic = projectile_scene.instantiate()
		get_tree().current_scene.add_child(magic)
		magic.global_position = global_position
		
		# Scale up for boss feel
		magic.scale = Vector2(2.5, 2.5) 
		
		var spread_dir = base_direction.rotated(angle)
		
		if magic.has_method("setup"):
			magic.setup(spread_dir, self)
	
	print("Evil Wizard shot 3 FIREBALLS towards ", target_pos)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		if not is_dead:
			_play_if_not("Idle")
		print("Evil Wizard attack finished, can_attack: ", can_attack)
