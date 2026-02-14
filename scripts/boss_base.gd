extends "res://scripts/enemy_base.gd"
class_name BossBase

## Base class for Bosses with high HP, loot tables, and special behaviors

@export_group("Boss Stats")
@export var boss_name: String = "Boss"
@export var boss_hp: int = 100
@export var is_flying: bool = false

@export_group("Animations")
@export var anim_hurt: String = ""  # "Take Hit", "Get Hit", etc. Empty = no hurt anim

@export_group("Loot System")
## Array of dictionaries: [{"item": "heart", "weight": 50, "amount": 1}, {"item": "coin", "weight": 30, "amount": 5}]
@export var loot_table: Array[Dictionary] = []
@export var max_drops: int = 2  # Boss drops up to 2 items

var is_invulnerable: bool = false  # For Roll, Shield, etc.

func _ready() -> void:
	super._ready()
	hp = boss_hp  # Set HP to boss value
	
	# Enhance health bar for boss (larger, different color)
	if hp_bar_bg:
		hp_bar_bg.size = Vector2(60, 6)  # Bigger HP bar
		hp_bar_bg.position = Vector2(-30, -25)
		hp_bar_fill.size = Vector2(60, 6)
		hp_bar_fill.position = Vector2(-30, -25)
		_update_health_bar() # Call to initialize boss health bar appearance

func _update_health_bar() -> void:
	var ratio = float(hp) / boss_hp
	hp_bar_fill.size.x = 60.0 * ratio  # Boss bar is 60px wide
	# Keep boss red color
	if ratio > 0.5:
		hp_bar_fill.color = Color(0.9, 0.1, 0.1, 1.0)
	elif ratio > 0.25:
		hp_bar_fill.color = Color(0.7, 0.0, 0.0, 1.0)
	else:
		hp_bar_fill.color = Color(0.4, 0.0, 0.0, 1.0)  # Boss red

func take_damage_with_knockback(amount: int, force: Vector2, is_crit: bool = false) -> void:
	# Ignore damage if invulnerable
	if is_invulnerable or is_dead:
		print(boss_name, " is invulnerable!")
		return
	
	# Apply knockback
	knockback = force
	
	# Play hurt animation if available
	if not anim_hurt.is_empty() and not is_attacking:
		_play_hurt_animation()
	
	# Apply damage
	take_damage(amount, is_crit)

func _play_hurt_animation() -> void:
	if anim_hurt.is_empty():
		return
	_play_if_not(anim_hurt)
	# Brief pause, then return to previous state
	get_tree().create_timer(0.3).timeout.connect(func():
		if not is_dead and not is_attacking:
			_play_if_not(anim_idle)
	)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# STOP EVERYTHING immediately
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)  # Stop _process too
	
	# Disable collision so player can't hit corpse
	collision_layer = 0
	collision_mask = 0
	if attack_area:
		attack_area.set_deferred("monitoring", false)
		attack_area.set_deferred("monitorable", false)
	
	# Play death animation if it exists (one-shot)
	if anim.sprite_frames.has_animation("death"):
		anim.stop()  # Stop current animation
		anim.play("death")
		
		# Ensure we listen for finish
		if not anim.animation_finished.is_connected(_on_death_animation_finished):
			anim.animation_finished.connect(_on_death_animation_finished)
			
		# BACKUP: Start a timer to force cleanup if animation loops or signal fails
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(self) and is_dead:
				print("Force cleaning up boss after death timeout")
				_cleanup_boss()
		)
	else:
		# No death animation, clean up immediately
		_cleanup_boss()

func _on_death_animation_finished() -> void:
	if anim.animation == "death":
		_cleanup_boss()

func _cleanup_boss() -> void:
	# Drop loot
	_drop_loot()
	
	# Hide and remove
	visible = false
	if hp_container:
		hp_container.visible = false
	queue_free()


func _drop_loot() -> void:
	if loot_table.is_empty():
		return
		
	# Calculate total weight
	var total_weight = 0
	for entry in loot_table:
		total_weight += entry.get("weight", 0)
	
	if total_weight <= 0:
		return
	
	# Roll for items
	for i in range(max_drops):
		var roll = randf() * total_weight
		var cumulative = 0
		
		for entry in loot_table:
			cumulative += entry.get("weight", 0)
			if roll <= cumulative:
				_spawn_drop(entry.get("item", ""), entry.get("amount", 1))
				break

func _spawn_drop(item_type: String, amount: int) -> void:
	# This will be implemented when we create the Drop system
	# For now, just print
	print("Boss ", boss_name, " would drop: ", item_type, " x", amount)
	# TODO: Instantiate Drop scene when ready
