extends Node2D

## Boss Spawner - Spawns ONE boss at a time with cooldown
## WORKAROUND: Preload scenes directly to avoid Array[PackedScene] issues

# Preload the boss scenes directly
const BOSS_EVIL_WIZARD = preload("res://scenes/boss/Boss_EvilWizard.tscn")
const BOSS_HUNTRESS = preload("res://scenes/boss/Boss_Huntress.tscn")
const BOSS_KNIGHT = preload("res://scenes/boss/Boss_Knight.tscn")

@export var trigger_x: float = 1800.0 # X coordinate that triggers the boss spawn
@export var spawn_interval: float = 20.0
@export var max_bosses: int = 1  # Only 1 boss alive at a time

var timer: Timer
var current_boss: Node = null
var boss_scenes_list: Array[PackedScene] = []
var player: Node2D = null
var triggered: bool = false

func _ready() -> void:
	# WORKAROUND: Build the array manually using preloaded constants
	boss_scenes_list = [BOSS_EVIL_WIZARD, BOSS_HUNTRESS, BOSS_KNIGHT]
	
	print("🎯 BossSpawner initialized (TRIGGER VERSION)")
	
	# Create the timer but don't start autostart
	timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = false
	timer.one_shot = false
	timer.timeout.connect(_try_spawn_boss)
	add_child(timer)
	
	# Find the player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if triggered:
		return
		
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if Engine.get_process_frames() % 60 == 0:
			print("🔍 BossSpawner: Buscando al jugador...")
		return
		
	# DEBUG: Imprimir distancia cada segundo
	if Engine.get_process_frames() % 60 == 0:
		var dist = trigger_x - player.global_position.x
		if dist > 0:
			print("📏 Distancia al Jefe: ", int(dist), " px")

	if player.global_position.x >= trigger_x:
		triggered = true
		print("🚩 ¡ACTIVADO! Jugador en X:", player.global_position.x, " >= ", trigger_x)
		_try_spawn_boss()
		timer.start()

func _try_spawn_boss() -> void:
	print("\n🚀 Intentando invocar jefe...")
	
	# Check for any bosses in scene
	var bosses = get_tree().get_nodes_in_group("bosses")
	if bosses.size() >= max_bosses:
		print("  ❌ Ya hay un jefe vivo (", bosses.size(), "), cancelando.")
		return
	
	# Select random boss from preloaded list
	if boss_scenes_list.is_empty():
		print("  ❌ ERROR: boss_scenes_list is empty!")
		return
	
	var selected_scene = boss_scenes_list.pick_random()
	print("  - Selected boss scene: ", selected_scene.resource_path)
	
	var boss = selected_scene.instantiate()
	print("  - Boss instantiated: ", boss)
	boss.global_position = global_position
	print("  - Spawn position: ", global_position)
	
	# Track this boss
	current_boss = boss
	
	# Add to scene
	get_parent().call_deferred("add_child", boss)
	
	print("✨ BOSS SPAWNED: ", boss.get("boss_name"), " at ", global_position)
