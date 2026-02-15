extends Node2D

enum SpawnerType { WALKER, FLYER }

@export var spawner_type: SpawnerType = SpawnerType.WALKER
@export var walker_scenes: Array[PackedScene] = []
@export var flyer_scenes: Array[PackedScene] = []
@export var spawn_interval: float = 10.0

var timer: Timer

func _ready() -> void:
	# Create and start the timer
	timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_spawn_enemy)
	add_child(timer)
	
	_spawn_enemy()

func _spawn_enemy() -> void:
	# --- Limit check ---
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() >= 30:
		return
		
	# --- Flyer Limit Check ---
	if spawner_type == SpawnerType.FLYER:
		var flyers = get_tree().get_nodes_in_group("flyers")
		if flyers.size() >= 2:
			return

	# --- Select Scene based on Type ---
	var selected_scene: PackedScene = null
	
	if spawner_type == SpawnerType.WALKER:
		if walker_scenes.size() > 0:
			selected_scene = walker_scenes.pick_random()
	elif spawner_type == SpawnerType.FLYER:
		if flyer_scenes.size() > 0:
			selected_scene = flyer_scenes.pick_random()
	
	if selected_scene == null:
#		print("Spawner: No scenes assigned for type ", spawner_type)
		return

	var enemy = selected_scene.instantiate()
	enemy.global_position = global_position
	
	get_parent().call_deferred("add_child", enemy)
