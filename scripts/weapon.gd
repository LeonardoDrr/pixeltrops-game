extends Node2D
class_name Weapon

@export var weapon_id: int = 0 # 1-20 Espadas, 21-40 Arcos, 41-60 Bastones
@export var rotate_to_mouse: bool = true # True for Bows/Staffs, False for Swords
@export var damage: int = 3
@export var crit_damage: int = 10
@export var crit_chance: float = 0.15
@export var attack_cooldown: float = 0.5

@export var mana_cost: int = 0
@export var uses_arrows: bool = false
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 100.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
# Hitbox se asignará en _ready si existe, o busca hijos
var hitbox: Area2D
var hit_enemies: Array = []
var can_attack: bool = true

func _ready() -> void:
	# Buscar Hitbox
	if has_node("Hitbox"):
		hitbox = $Hitbox
		hitbox.monitoring = false # Desactivado por defecto
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	play_animation("Idle")
	anim.animation_finished.connect(_on_animation_finished)

func play_animation(anim_name: String) -> void:
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)

func attack() -> void:
	if not can_attack:
		return
	
	# Check for resources (Mana / Arrows)
	var player = owner as CharacterBody2D # Assuming owner is player
	if not player:
		# Fallback if owner isn't set properly (e.g. testing)
		player = get_parent().get_parent() as CharacterBody2D
		
	if player and player.has_method("change_mana"):
		# Mana Check
		if mana_cost > 0:
			# Try to consume mana (pass negative amount)
			if not player.change_mana(-float(mana_cost)):
				# Not enough mana
				return

		# Arrow Check
		if uses_arrows:
			# Try to consume arrow
			if not player.change_arrows(-1):
				# Not enough arrows
				return

	can_attack = false
	# Timer to reset attack
	get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)

	# Lógica de Proyectil
	if projectile_scene:
		_shoot_projectile()
		play_animation("attack")
		return

	# Lógica Melee
	# Limpiar ista de enemigos golpeados en este ataque
	hit_enemies.clear()
	
	# Activar hitbox
	if hitbox:
		hitbox.monitoring = true
		
	play_animation("attack")

func _shoot_projectile() -> void:
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	# Calculate direction to mouse (always aim at cursor, even if weapon is static)
	var direction = (get_global_mouse_position() - global_position).normalized()
		
	projectile.global_position = global_position
	# Offset projectile slightly forward
	projectile.global_position += direction * 10.0
	
	if projectile.has_method("setup"):
		projectile.setup(direction, owner)

func _on_animation_finished() -> void:
	if anim.animation == "attack":
		# Desactivar hitbox al terminar
		if hitbox:
			hitbox.set_deferred("monitoring", false)
		play_animation("Idle")

func _on_hitbox_body_entered(body: Node) -> void:
	# Evitar golpear al mismo enemigo dos veces en el mismo ataque
	if body in hit_enemies:
		return
		
	# Verificar si es enemigo (tiene metodo take_damage) y NO es el dueño del arma (asumiendo player)
	if body.has_method("take_damage") and body != owner and body != get_parent().get_parent(): # Weapon -> WeaponHolder -> Player
		hit_enemies.append(body)
		
		# Calcular crítico
		var is_crit = randf() < crit_chance
		var final_damage = crit_damage if is_crit else damage
		
		# Calcular dirección de empuje (desde el arma hacia el enemigo)
		var knockback_dir = (body.global_position - global_position).normalized()
		# Ajuste: empujar un poco hacia arriba también para evitar fricción de suelo inmediata
		knockback_dir.y -= 0.5 
		knockback_dir = knockback_dir.normalized()
		
		# Llamar a take_damage con knockback (si el enemigo lo soporta, modifcaremos enemy.gd)
		if body.has_method("take_damage_with_knockback"):
			body.take_damage_with_knockback(final_damage, knockback_dir * 250.0, is_crit)
		else:
			# Fallback anterior
			body.take_damage(final_damage, is_crit)

func update_orientation(is_facing_left: bool) -> void:
	if is_facing_left:
		scale.x = -1
	else:
		scale.x = 1

func get_idle_texture() -> Texture2D:
	var sprite = anim
	if not sprite:
		if has_node("AnimatedSprite2D"):
			sprite = get_node("AnimatedSprite2D")
	
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("Idle"):
		return sprite.sprite_frames.get_frame_texture("Idle", 0)
	return null

func get_weapon_type() -> String:
	# 1-20 swords, 21-40 bows, 41-60 staffs
	if weapon_id >= 1 and weapon_id <= 20:
		return "melee"
	elif weapon_id >= 21 and weapon_id <= 40:
		return "range"
	elif weapon_id >= 41 and weapon_id <= 60:
		return "mage"
	return "melee"
