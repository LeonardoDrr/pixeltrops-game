extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var mana_bar: ProgressBar = $Control/ManaBar
@onready var arrow_label: Label = $Control/ArrowCounter/Label
@onready var health_label: Label = $Control/HealthBar/Label
@onready var mana_label: Label = $Control/ManaBar/Label
@onready var hotbar_container: HBoxContainer = $Control/Hotbar

const SlotScene = preload("res://scenes/UI/HotbarSlot.tscn")
var slots: Array = []

func initialize_hotbar(weapons_data: Array) -> void:
	# Clear existing
	for child in hotbar_container.get_children():
		child.queue_free()
	slots.clear()
	
	for data in weapons_data:
		var slot = SlotScene.instantiate()
		hotbar_container.add_child(slot)
		slot.setup(data["type"], data["icon"])
		slots.append(slot)

func select_slot(index: int) -> void:
	for i in range(slots.size()):
		slots[i].set_selected(i == index)

func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current
	health_label.text = str(current) + " / " + str(max_hp)

func update_mana(current: int, max_mana: int) -> void:
	mana_bar.max_value = max_mana
	mana_bar.value = current
	mana_label.text = str(current) + " / " + str(max_mana)

func update_arrows(count: int) -> void:
	arrow_label.text = str(count)
