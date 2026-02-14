extends Node2D

## Boss Spawner - Spawns ONE boss at a time with cooldown
## WORKAROUND: Preload scenes directly to avoid Array[PackedScene] issues

# Preload the boss scenes directly
const BOSS_EVIL_WIZARD = preload("res://scenes/boss/Boss_EvilWizard.tscn")
const BOSS_HUNTRESS = preload("res://scenes/boss/Boss_Huntress.tscn")
const BOSS_KNIGHT = preload("res://scenes/boss/Boss_Knight.tscn")

@export var spawn_interval: float = 20.0
@export var max_bosses: int = 1  # Only 1 boss alive at a time

var timer: Timer
var current_boss: Node = null
var boss_scenes_list: Array[PackedScene] = []

func _ready() -> void:
	# WORKAROUND: Build the array manually using preloaded constants
	boss_scenes_list = [BOSS_EVIL_WIZARD, BOSS_HUNTRESS, BOSS_KNIGHT]
	
	print("🎯 BossSpawner initialized (PRELOAD VERSION)")
	print("  - Boss scenes (preloaded): ", boss_scenes_list.size())
	print("  - Spawn interval: ", spawn_interval, "s")
	print("  - Max bosses: ", max_bosses)
	
	# Create and start the timer
	timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_try_spawn_boss)
	add_child(timer)
	
	print("  - Timer created and started")
	
	# Spawn first boss after short delay
	await get_tree().create_timer(2.0).timeout
	print("⏰ Initial spawn delay finished, trying first spawn")
	_try_spawn_boss()

func _try_spawn_boss() -> void:
	print("\n🔄 _try_spawn_boss called")
	
	# Check if boss is still alive
	if current_boss and is_instance_valid(current_boss):
		print("  ❌ Current boss still alive, skipping spawn")
		return  # Boss still alive, don't spawn
	
	# Check for any bosses in scene (in case player didn't kill it)
	var bosses = get_tree().get_nodes_in_group("bosses")
	print("  - Bosses in scene: ", bosses.size(), "/", max_bosses)
	if bosses.size() >= max_bosses:
		print("  ❌ Max bosses reached (", bosses.size(), "), skipping spawn")
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
