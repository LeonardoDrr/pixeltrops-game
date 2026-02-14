extends Area2D

@export var speed: float = 400.0
@export var damage: int = 2
@export var crit_damage: int = 5
@export var crit_chance: float = 0.1
@export var projectile_gravity: float = 0.0 # 0 para magia, >0 para flechas
@export var lifetime: float = 5.0
@export var max_distance: float = 2000.0 # ~100 tiles de 20px

var velocity: Vector2 = Vector2.ZERO
var shooter: Node
var start_position: Vector2

func _ready() -> void:
	# Asegurar monitoring
	monitoring = true
	monitorable = false 
	
	# Conectar señal de cuerpo entrado INMEDIATAMENTE
	body_entered.connect(_on_body_entered)
	
	print("Proyectil creado. Pos:", global_position, " Rot:", rotation_degrees)
	
	# Destruir después de X segundos por seguridad (esto debe ir al final porque await pausa la funcion)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		print("Proyectil expiró por tiempo")
		queue_free()

func setup(direction: Vector2, _shooter: Node) -> void:
	velocity = direction * speed
	shooter = _shooter
	rotation = direction.angle()
	start_position = global_position

func _physics_process(delta: float) -> void:
	# Aplicar gravedad si existe
	if projectile_gravity > 0:
		velocity.y += projectile_gravity * delta
		rotation = velocity.angle()
	
	position += velocity * delta
	
	# Verificar distancia recorrida (magia se desvanece)
	if start_position != Vector2.ZERO and global_position.distance_to(start_position) > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	print("Proyectil ENTERED: ", body.name, " Layer:", body.get("collision_layer"))
	
	# Ignorar al tirador (el propio player)
	if body == shooter:
		return
		
	# Si es enemigo (tiene metodo take_damage)
	if body.has_method("take_damage"):
		var is_crit = randf() < crit_chance
		var final_damage = crit_damage if is_crit else damage
		
		# Calcular knockback simple
		var knockback_dir = velocity.normalized()
		
		if body.has_method("take_damage_with_knockback"):
			body.take_damage_with_knockback(final_damage, knockback_dir * 100.0, is_crit)
		else:
			body.take_damage(final_damage, is_crit)
		
		# Destruir proyectil al impactar enemigo
		queue_free()
		
	else:
		# Si toca CUALQUIER otra cosa (Pared, Suelo, Objeto) que no sea el tirador
		# Asumimos que es un obstáculo y destruimos el proyectil.
		queue_free()
