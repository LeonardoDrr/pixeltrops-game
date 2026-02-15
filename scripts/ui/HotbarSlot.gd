extends TextureRect

@onready var icon: TextureRect = $Icon
@onready var highlight: ColorRect = $Highlight

func setup(weapon_type: String, weapon_icon: Texture2D) -> void:
	# Set Background based on type
	match weapon_type:
		"melee":
			texture = preload("res://assets/Items/box melee.png")
		"range":
			texture = preload("res://assets/Items/box range.png")
		"mage":
			texture = preload("res://assets/Items/box mage.png")
		_:
			texture = preload("res://assets/Items/box melee.png") # Default
	
	# Set Icon
	if weapon_icon:
		icon.texture = weapon_icon
	else:
		print("Warning: No icon for weapon type: ", weapon_type)
	
func set_selected(selected: bool) -> void:
	highlight.visible = selected
