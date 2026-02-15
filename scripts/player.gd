extends CharacterBody2D

const WALK_SPEED = 150.0
const RUN_SPEED = 280.0
const JUMP_VELOCITY = -220.0
const MAX_HP = 100
const CRIT_CHANCE = 0.15  # 15% chance for critical hit (3 dmg)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

# @onready var attack_area: Area2D = $"dañar" # Deprecated

var is_attacking: bool = false
var is_running: bool = false
var hp: int = MAX_HP
var is_dead: bool = false
var has_dealt_damage: bool = false # Still used internally? Maybe not, but keep safe
var spawn_position: Vector2

# --- Resources ---
var mana: float = 100.0
var max_mana: float = 100.0
var mana_regen_rate: float = 0.5 # Mana per second (Slow regen)
var arrows: int = 30

# --- UI ---
const HUD_SCENE = preload("res://scenes/UI/HUD.tscn")
var hud: CanvasLayer

func _input(event: InputEvent) -> void:
	# Attack input moved to _physics_process for auto-attack

	# --- Weapon Switching (Scroll Wheel) ---
	if event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_switch_to_weapon(0)
		elif event.keycode == KEY_2:
			_switch_to_weapon(1)
		elif event.keycode == KEY_3:
			_switch_to_weapon(2)

var weapon_scenes = [
	preload("res://scenes/Weapons/Swords/Sword_Wood.tscn"),
	preload("res://scenes/Weapons/Bows/Bow_Wood.tscn"),
	preload("res://scenes/Weapons/Staffs/Staff_Fire.tscn")
]
var current_weapon_index: int = 0

func _ready() -> void:
	spawn_position = global_position
	anim.animation_finished.connect(_on_animation_finished)
	
	# Instantiate HUD
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	
	# Initialize Hotbar
	var weapons_data = []
	for scene in weapon_scenes:
		var w = scene.instantiate()
		weapons_data.append({
			"type": w.get_weapon_type(),
			"icon": w.get_idle_texture()
		})
		w.queue_free()
	
	hud.initialize_hotbar(weapons_data)
	
	_update_ui()
	
	# Ensure weapon renders in front of player
	if has_node("WeaponHolder"):
		$WeaponHolder.z_index = 1
	
	# Instantiate Default Weapon
	_switch_to_weapon(0)

func _cycle_weapon(direction: int) -> void:
	current_weapon_index += direction
	
	if current_weapon_index >= weapon_scenes.size():
		current_weapon_index = 0
	elif current_weapon_index < 0:
		current_weapon_index = weapon_scenes.size() - 1
		
	_switch_to_weapon(current_weapon_index) # Use common function

func _switch_to_weapon(index: int) -> void:
	if index >= 0 and index < weapon_scenes.size():
		current_weapon_index = index
		equip_weapon(weapon_scenes[index])
		if hud:
			hud.select_slot(index)

func equip_weapon(weapon_packed: PackedScene) -> void:
	# Eliminar arma actual si existe
	for child in $WeaponHolder.get_children():
		child.queue_free()
	
	# Instanciar nueva
	var new_weapon = weapon_packed.instantiate()
	$WeaponHolder.call_deferred("add_child", new_weapon)



func _process(delta: float) -> void:
	if is_dead: return
	
	# Passive Mana Regen
	if mana < max_mana:
		mana += mana_regen_rate * delta
		mana = min(mana, max_mana)
		hud.update_mana(int(mana), int(max_mana))

func _update_ui() -> void:
	if hud:
		hud.update_health(hp, MAX_HP)
		hud.update_mana(int(mana), int(max_mana))
		hud.update_arrows(arrows)

func change_mana(amount: float) -> bool:
	if mana + amount >= 0:
		mana += amount
		mana = clamp(mana, 0, max_mana)
		hud.update_mana(int(mana), int(max_mana))
		return true
	return false

func change_arrows(amount: int) -> bool:
	if arrows + amount >= 0:
		arrows += amount
		hud.update_arrows(arrows)
		return true
	return false

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# --- Gravity ---

	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- Jump ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- Run detection (Shift held) ---
	is_running = Input.is_action_pressed("run")

	# --- Camera Zoom ---
	var zoom_speed = 2.0 * delta
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS): # Zoom In
		camera.zoom += Vector2(zoom_speed, zoom_speed)
	elif Input.is_key_pressed(KEY_MINUS): # Zoom Out
		camera.zoom -= Vector2(zoom_speed, zoom_speed)
	
	# Clamp zoom (Limits: 1.0 to 5.0)
	camera.zoom = camera.zoom.clamp(Vector2(1.0, 1.0), Vector2(5.0, 5.0))

	# --- Mouse Aiming & Face Direction (Terraria Style) ---
	var mouse_pos = get_global_mouse_position()
	
	# Flip sprite based on mouse position
	anim.flip_h = mouse_pos.x < global_position.x

	# Rotate and Position Weapon Holder
	if has_node("WeaponHolder") and $WeaponHolder.get_child_count() > 0:
		var weapon_holder = $WeaponHolder
		var weapon = weapon_holder.get_child(0)
		var rotate_enabled = true
		
		# --- Flip Position logic (Keep weapon in 'front' hand) ---
		# If aiming left, move holder to left side. If right, move to right.
		if mouse_pos.x < global_position.x:
			weapon_holder.position.x = -abs(weapon_holder.position.x)
		else:
			weapon_holder.position.x = abs(weapon_holder.position.x)
		
		if "rotate_to_mouse" in weapon:
			rotate_enabled = weapon.rotate_to_mouse
			
		if rotate_enabled:
			# Free rotation (Bows, Staffs)
			weapon_holder.look_at(mouse_pos)
			weapon_holder.scale.x = 1 # Force reset X scale (fix transition from Sword)
			if mouse_pos.x < global_position.x:
				weapon_holder.scale.y = -1
			else:
				weapon_holder.scale.y = 1
		else:
			# Static rotation (Swords) - Flip only
			weapon_holder.rotation = 0
			weapon_holder.scale.y = 1
			
			if mouse_pos.x < global_position.x:
				weapon_holder.scale.x = -1
			else:
				weapon_holder.scale.x = 1

	# --- Horizontal movement ---
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		var speed = RUN_SPEED if is_running else WALK_SPEED
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)

	move_and_slide()

	# --- Keep health bar following the character (in global coords) ---
	# HUD is a CanvasLayer, so no manual positioning needed

	# --- Auto-Attack (Hold button) ---
	if Input.is_action_pressed("attack"):
		if has_node("WeaponHolder") and $WeaponHolder.get_child_count() > 0:
			var weapon = $WeaponHolder.get_child(0)
			if weapon.has_method("attack"):
				weapon.attack()

	# --- Sprite flip ---
	if direction != 0:
		anim.flip_h = direction < 0

	# --- Animation state machine ---
	if not is_on_floor():
		_play_if_not("Jump")
	elif direction != 0:
		if is_running:
			_play_if_not("Run ")
		else:
			_play_if_not("Walk")
	else:
		_play_if_not("Idle")
	




func take_damage(amount: int, is_crit: bool = false) -> void:
	if is_dead:
		return
	hp -= amount
	hp = max(hp, 0)
	if hud:
		hud.update_health(hp, MAX_HP)
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
	container.top_level = true
	container.global_position = global_position
	add_child(container)

	var label = Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 12 if is_crit else 8)
	if is_crit:
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))  # amarillo
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-4, -28)
	container.add_child(label)

	# Animar: sube y se desvanece
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 15, 0.6)
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	tw.set_parallel(false)
	tw.tween_callback(container.queue_free)

func _die() -> void:
	is_dead = true
	visible = false
	if hud: hud.visible = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	# Respawn after 5 seconds
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_respawn)

func _respawn() -> void:
	hp = MAX_HP
	mana = max_mana
	global_position = spawn_position
	is_dead = false
	is_attacking = false
	visible = true
	if hud: 
		hud.visible = true
		_update_ui()
	set_physics_process(true)
	anim.play("Idle")

func _play_if_not(anim_name: String) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
