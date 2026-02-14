extends CharacterBody2D

## Enemy AI — walks toward the player, attacks when close, has HP

const JUMP_VELOCITY = -220.0
const ATTACK_RANGE = 10.0  # pixels — stop and attack (muy cerca)
const WALKATK_RANGE = 22.0 # pixels — walk + attack anim
const MAX_HP = 10
const CRIT_CHANCE = 0.15  # 15% chance for critical hit (3 dmg)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $"golpear"

enum State { IDLE, CHASE, WALKATK, ATTACK }
var state: State = State.IDLE
var player: CharacterBody2D = null
var is_attacking: bool = false

@export_group("Enemy Stats")
@export var enemy_id: int = 100 # 100-120 Walkers, 121-140 Flyers
@export var hp: int = 10
@export var damage: int = 2
@export var speed: float = 90.0

@export_group("Animations")
@export var anim_idle: String = "Idle"
@export var anim_walk: String = "Walk"
@export var anim_attack: String = "atk"

var is_dead: bool = false
var has_dealt_damage: bool = false
var knockback: Vector2 = Vector2.ZERO

func take_damage_with_knockback(amount: int, force: Vector2, is_crit: bool = false) -> void:
	knockback = force
	take_damage(amount, is_crit)


var hp_container: Node2D
var hp_bar_bg: ColorRect
var hp_bar_fill: ColorRect

func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	_create_health_bar()
	# Find the player node
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		var root = get_tree().current_scene
		player = root.get_node_or_null("player")
		if player == null:
			player = root.find_child("player", true, false)
			if player == null:
				player = root.find_child("Player", true, false)

func _create_health_bar() -> void:
	hp_container = Node2D.new()
	hp_container.top_level = true
	add_child(hp_container)

	# Background bar (dark)
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.85)
	hp_bar_bg.size = Vector2(30, 4)
	hp_bar_bg.position = Vector2(-15, -20)
	hp_container.add_child(hp_bar_bg)

	# Fill bar (red for enemy)
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.85, 0.15, 0.15, 1.0)
	hp_bar_fill.size = Vector2(30, 4)
	hp_bar_fill.position = Vector2(-15, -20)
	hp_container.add_child(hp_bar_fill)

func _update_health_bar() -> void:
	var ratio = float(hp) / MAX_HP
	hp_bar_fill.size.x = 30.0 * ratio
	# Darker red as HP drops
	if ratio > 0.5:
		hp_bar_fill.color = Color(0.85, 0.15, 0.15, 1.0)
	elif ratio > 0.25:
		hp_bar_fill.color = Color(0.9, 0.5, 0.0, 1.0)
	else:
		hp_bar_fill.color = Color(0.5, 0.0, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# --- Optimization: Despawn if too far ---
	if player and is_instance_valid(player):
		if global_position.distance_to(player.global_position) > 1500:
			queue_free()
			return

	# --- Keep health bar following the character ---
	hp_container.global_position = global_position
	
	# --- Knockback handling (Common) ---
	if knockback.length() > 10:
		knockback = knockback.move_toward(Vector2.ZERO, 800 * delta)
		velocity = knockback
		move_and_slide()
		return
		
	# --- Virtual: Movement Logic should be implemented by children ---
	_process_enemy_movement(delta)

func _process_enemy_movement(delta: float) -> void:
	# Default: Do nothing or basic idle
	pass


func _try_deal_damage() -> void:
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body != self and body.has_method("take_damage"):
			var is_crit = randf() < CRIT_CHANCE
			var dmg_to_deal = int(damage * 1.5) if is_crit else damage
			body.take_damage(dmg_to_deal, is_crit)
			has_dealt_damage = true
			break

func take_damage(amount: int, is_crit: bool = false) -> void:
	if is_dead:
		return
	hp -= amount
	hp = max(hp, 0)
	_update_health_bar()
	_flash_damage()
	_show_damage_number(amount, is_crit)
	if hp <= 0:
		_die()

func _flash_damage() -> void:
	anim.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color.WHITE, 0.25)

func _show_damage_number(amount: int, is_crit: bool) -> void:
	var container = Node2D.new()
	# Parent to main scene so it survives if enemy dies
	get_tree().current_scene.add_child(container)
	container.global_position = global_position
	
	var label = Label.new()
	if is_crit:
		label.text = "Crit " + str(amount)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1)) # amarillo
	else:
		label.text = str(amount)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color.WHITE)
		
	label.position = Vector2(-10, -35) if is_crit else Vector2(-4, -28)
	container.add_child(label)

	# Animar: sube y se desvanece
	var tw = container.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 25, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0)
	tw.set_parallel(false)
	tw.tween_callback(container.queue_free)

func _die() -> void:
	is_dead = true
	visible = false
	hp_container.visible = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	queue_free()

func _change_state(new_state: State) -> void:
	state = new_state

func _play_if_not(anim_name: String) -> void:
	if anim.sprite_frames.has_animation(anim_name):
		if anim.animation != anim_name:
			anim.play(anim_name)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
